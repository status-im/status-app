#include <jni.h>
#include <android/log.h>
#include <string>
#include <vector>
#include <mutex>
#include <cstring>

// Real status-go exports (from libstatus.so)
extern "C" {
  typedef void (*SignalCallback)(const char* signalJson);
  void SetSignalEventCallback(SignalCallback cb);
  void Free(void* p);
}

// Generated dispatcher (links against libstatus.so and calls real exports)
extern "C" char* statusgo_service_dispatch(const char* method, const char** argv, size_t argc);

namespace {
static JavaVM* g_vm = nullptr;
static jobject g_serviceObj = nullptr; // Global ref
static jmethodID g_onSignal = nullptr;
static std::mutex g_lock;

static void loge(const char* msg) { __android_log_write(ANDROID_LOG_ERROR, "statusgo-service", msg); }

static JNIEnv* getEnv() {
  if (!g_vm) return nullptr;
  JNIEnv* env = nullptr;
  if (g_vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
    if (g_vm->AttachCurrentThread(&env, nullptr) != JNI_OK) return nullptr;
  }
  return env;
}

static void signalCb(const char* signalJson) {
  std::lock_guard<std::mutex> guard(g_lock);
  if (!g_serviceObj || !g_onSignal) return;
  JNIEnv* env = getEnv();
  if (!env) return;
  jstring jSig = env->NewStringUTF(signalJson ? signalJson : "");
  env->CallVoidMethod(g_serviceObj, g_onSignal, jSig);
  env->DeleteLocalRef(jSig);
  if (env->ExceptionCheck()) {
    env->ExceptionClear();
  }
}

// Minimal JSON array-of-strings parser:
// Accepts the exact format produced by the UI stub runtime:
//   ["str1","str2",...]
// with standard JSON escaping.
static bool parseJsonString(const char*& p, std::string& out) {
  if (*p != '"') return false;
  ++p;
  while (*p) {
    char c = *p++;
    if (c == '"') return true;
    if (c == '\\') {
      char e = *p++;
      switch (e) {
        case '"': out.push_back('"'); break;
        case '\\': out.push_back('\\'); break;
        case '/': out.push_back('/'); break;
        case 'b': out.push_back('\b'); break;
        case 'f': out.push_back('\f'); break;
        case 'n': out.push_back('\n'); break;
        case 'r': out.push_back('\r'); break;
        case 't': out.push_back('\t'); break;
        case 'u': {
          // Skip \uXXXX (best-effort; keep ASCII only for now)
          for (int i = 0; i < 4 && *p; i++) ++p;
          // Replace with '?'
          out.push_back('?');
          break;
        }
        default:
          out.push_back(e);
          break;
      }
    } else {
      out.push_back(c);
    }
  }
  return false;
}

static std::vector<std::string> parseArgsJson(const char* argsJson) {
  std::vector<std::string> out;
  if (!argsJson) return out;
  const char* p = argsJson;
  while (*p && (*p == ' ' || *p == '\n' || *p == '\t' || *p == '\r')) ++p;
  if (*p != '[') return out;
  ++p;
  while (*p) {
    while (*p && (*p == ' ' || *p == '\n' || *p == '\t' || *p == '\r')) ++p;
    if (*p == ']') break;
    std::string s;
    if (!parseJsonString(p, s)) break;
    out.push_back(std::move(s));
    while (*p && (*p == ' ' || *p == '\n' || *p == '\t' || *p == '\r')) ++p;
    if (*p == ',') { ++p; continue; }
    if (*p == ']') break;
  }
  return out;
}
} // namespace

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  g_vm = vm;
  return JNI_VERSION_1_6;
}

extern "C" JNIEXPORT void JNICALL
Java_app_status_mobile_ipc_StatusGoService_nativeInit(JNIEnv* env, jclass, jobject serviceObj) {
  std::lock_guard<std::mutex> guard(g_lock);
  if (g_serviceObj) {
    env->DeleteGlobalRef(g_serviceObj);
    g_serviceObj = nullptr;
    g_onSignal = nullptr;
  }
  g_serviceObj = env->NewGlobalRef(serviceObj);
  jclass cls = env->GetObjectClass(serviceObj);
  g_onSignal = env->GetMethodID(cls, "onNativeSignal", "(Ljava/lang/String;)V");
  if (!g_onSignal) {
    loge("Failed to find StatusGoService.onNativeSignal(String)");
  }
  env->DeleteLocalRef(cls);

  // Register callback into status-go.
  SetSignalEventCallback(signalCb);
}

extern "C" JNIEXPORT jstring JNICALL
Java_app_status_mobile_ipc_StatusGoService_nativeCall(JNIEnv* env, jclass, jstring jMethod, jstring jArgsJson) {
  const char* method = jMethod ? env->GetStringUTFChars(jMethod, nullptr) : nullptr;
  const char* argsJson = jArgsJson ? env->GetStringUTFChars(jArgsJson, nullptr) : nullptr;

  std::vector<std::string> args = parseArgsJson(argsJson);
  std::vector<const char*> argv;
  argv.reserve(args.size());
  for (auto& s : args) argv.push_back(s.c_str());

  char* out = statusgo_service_dispatch(method ? method : "", argv.empty() ? nullptr : argv.data(), argv.size());
  const bool shouldFree = (out != nullptr);
  if (!out) out = (char*)"{\"error\":\"null return from dispatch\"}";

  jstring jOut = env->NewStringUTF(out);

  if (shouldFree) Free(out);

  if (jMethod) env->ReleaseStringUTFChars(jMethod, method);
  if (jArgsJson) env->ReleaseStringUTFChars(jArgsJson, argsJson);

  return jOut;
}

