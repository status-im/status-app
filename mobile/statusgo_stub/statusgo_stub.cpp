#include <jni.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <mutex>
#include <string>
#include <android/log.h>
// Tiny UI-process stub for status-go's exported C API.
// Instead of linking libstatus (real status-go) into the UI process, we export
// the same symbols and forward them to a separate Android service process via Java.
//
// Note: For now, the Java side can be a placeholder. This file focuses on:
// - providing the symbols required by the Nim glue (nim-status-go wrappers)
// - returning heap-allocated cstrings compatible with status-go's Free()
//
// The service-side implementation will be added next (Binder + separate process).
namespace {
static JavaVM* g_vm = nullptr;
static jclass g_bridgeClass = nullptr;
static jmethodID g_callMethod = nullptr; // static String call(String method, String argsJson)
static std::mutex g_lock;
using SignalCallback = void (*)(const char* signalJson);
static SignalCallback g_signalCb = nullptr;
static void loge(const char* msg) {
  __android_log_write(ANDROID_LOG_ERROR, "statusgo-stub", msg);
}
static JNIEnv* getEnv() {
  if (!g_vm) return nullptr;
  JNIEnv* env = nullptr;
  if (g_vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
    if (g_vm->AttachCurrentThread(&env, nullptr) != JNI_OK) return nullptr;
  }
  return env;
}
static char* dupToMalloc(const char* s) {
  if (!s) s = "";
  const size_t n = strlen(s);
  char* out = static_cast<char*>(malloc(n + 1));
  if (!out) return nullptr;
  memcpy(out, s, n);
  out[n] = '\0';
  return out;
}

static void appendJsonEscaped(std::string& out, const char* s) {
  if (!s) return;
  for (const unsigned char* p = (const unsigned char*)s; *p; ++p) {
    const unsigned char c = *p;
    switch (c) {
      case '\\': out += "\\\\"; break;
      case '"': out += "\\\""; break;
      case '\b': out += "\\b"; break;
      case '\f': out += "\\f"; break;
      case '\n': out += "\\n"; break;
      case '\r': out += "\\r"; break;
      case '\t': out += "\\t"; break;
      default:
        if (c < 0x20) {
          char buf[7];
          snprintf(buf, sizeof(buf), "\\u%04x", (unsigned)c);
          out += buf;
        } else {
          out.push_back((char)c);
        }
        break;
    }
  }
}
static char* callJava(const char* method, const char* argsJson) {
  JNIEnv* env = getEnv();
  if (!env) {
    return dupToMalloc("{\"error\":\"status-go stub not initialized\"}");
  }

  // Keep lock scope minimal: copy references, then perform Binder call unlocked.
  jclass bridgeClass = nullptr;
  jmethodID callMethod = nullptr;
  {
    std::lock_guard<std::mutex> guard(g_lock);
    if (!g_bridgeClass || !g_callMethod) {
      return dupToMalloc("{\"error\":\"status-go stub not initialized\"}");
    }
    bridgeClass = (jclass)env->NewLocalRef(g_bridgeClass);
    callMethod = g_callMethod;
  }
  if (!bridgeClass || !callMethod) {
    if (bridgeClass) env->DeleteLocalRef(bridgeClass);
    return dupToMalloc("{\"error\":\"status-go stub not initialized\"}");
  }

  jstring jMethod = env->NewStringUTF(method ? method : "");
  jstring jArgs = env->NewStringUTF(argsJson ? argsJson : "null");
  jstring jRet = (jstring)env->CallStaticObjectMethod(bridgeClass, callMethod, jMethod, jArgs);
  env->DeleteLocalRef(jMethod);
  env->DeleteLocalRef(jArgs);
  env->DeleteLocalRef(bridgeClass);
  if (env->ExceptionCheck()) {
    env->ExceptionClear();
    return dupToMalloc("{\"error\":\"java exception in status-go stub\"}");
  }
  if (!jRet) return dupToMalloc("");
  const char* cRet = env->GetStringUTFChars(jRet, nullptr);
  char* out = dupToMalloc(cRet);
  env->ReleaseStringUTFChars(jRet, cRet);
  env->DeleteLocalRef(jRet);
  return out;
}
static char* buildArgsJson(const char** argv, size_t argc) {
  std::string out;
  out.reserve(64);
  out.push_back('[');
  for (size_t i = 0; i < argc; i++) {
    if (i) out.push_back(',');
    out.push_back('"');
    appendJsonEscaped(out, argv[i] ? argv[i] : "");
    out.push_back('"');
  }
  out.push_back(']');
  return dupToMalloc(out.c_str());
}
} // namespace

extern "C" {

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  g_vm = vm;
  return JNI_VERSION_1_6;
}

// Called from Java to provide the bridge class/method.
JNIEXPORT void JNICALL
Java_app_status_mobile_StatusGoStub_nativeInit(JNIEnv* env, jclass, jclass bridgeClass) {
  std::lock_guard<std::mutex> guard(g_lock);
  if (g_bridgeClass) {
    env->DeleteGlobalRef(g_bridgeClass);
    g_bridgeClass = nullptr;
    g_callMethod = nullptr;
  }
  g_bridgeClass = (jclass)env->NewGlobalRef(bridgeClass);
  g_callMethod = env->GetStaticMethodID(g_bridgeClass, "call", "(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;");
  if (!g_callMethod) {
    loge("Failed to find StatusGoStub.call(String,String)");
  }
}

// Called from Java (Binder listener) to deliver signals into the stored C callback.
JNIEXPORT void JNICALL
Java_app_status_mobile_StatusGoStub_nativeDeliverSignal(JNIEnv* env, jclass, jstring jsonSignal) {
  (void)env;
  if (!jsonSignal) return;
  if (!g_signalCb) return;
  const char* c = env->GetStringUTFChars(jsonSignal, nullptr);
  g_signalCb(c);
  env->ReleaseStringUTFChars(jsonSignal, c);
}

void Free(void* p) { free(p); }

void SetSignalEventCallback(SignalCallback cb) { g_signalCb = cb; }

// Called by generated exports.
// - All arguments are passed as strings (even ints/bools) to simplify IPC.
// - The service side will interpret them based on the called method.
char* statusgo_stub_callv(const char* method, const char** argv, size_t argc) {
  char* argsJson = buildArgsJson(argv, argc);
  if (!argsJson) return dupToMalloc("{\"error\":\"oom\"}");
  char* out = callJava(method, argsJson);
  free(argsJson);
  return out;
}

} // extern "C"

