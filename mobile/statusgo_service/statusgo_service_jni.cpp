#include <jni.h>
#include <android/log.h>
#include <string>
#include <vector>
#include <mutex>
#include <cstring>

#include "args_json.h"

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
  // Zero-copy view of status-go's buffer, which is freed once this callback returns.
  static char empty[] = "";
  char* data = signalJson ? const_cast<char*>(signalJson) : empty;
  jobject buf = env->NewDirectByteBuffer(data, static_cast<jlong>(strlen(data)));
  if (!buf) {
    env->ExceptionClear();
    return;
  }
  env->CallVoidMethod(g_serviceObj, g_onSignal, buf);
  env->DeleteLocalRef(buf);
  if (env->ExceptionCheck()) {
    env->ExceptionClear();
  }
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
  g_onSignal = env->GetMethodID(cls, "onNativeSignal", "(Ljava/nio/ByteBuffer;)V");
  if (!g_onSignal) {
    env->ExceptionClear();
    loge("Failed to find StatusGoService.onNativeSignal(ByteBuffer)");
  }
  env->DeleteLocalRef(cls);

  // Register callback into status-go.
  SetSignalEventCallback(signalCb);
}

namespace {
// Returns a direct buffer over the status-go result; Java releases it with nativeFree.
jobject dispatch(JNIEnv* env, jstring jMethod, std::vector<std::string> args) {
  const char* method = jMethod ? env->GetStringUTFChars(jMethod, nullptr) : nullptr;
  std::vector<const char*> argv;
  argv.reserve(args.size());
  for (auto& s : args) argv.push_back(s.c_str());

  char* out = statusgo_service_dispatch(method ? method : "", argv.empty() ? nullptr : argv.data(), argv.size());
  if (method) env->ReleaseStringUTFChars(jMethod, method);
  if (!out) return nullptr;

  jobject buf = env->NewDirectByteBuffer(out, static_cast<jlong>(strlen(out)));
  if (!buf) Free(out);
  return buf;
}
} // namespace

extern "C" JNIEXPORT jobject JNICALL
Java_app_status_mobile_ipc_StatusGoService_nativeCall(JNIEnv* env, jclass, jstring jMethod, jbyteArray jArgs) {
  std::vector<std::string> args;
  if (jArgs) {
    const jsize len = env->GetArrayLength(jArgs);
    jbyte* bytes = env->GetByteArrayElements(jArgs, nullptr);
    if (!bytes) return nullptr;
    args = statusgo_ipc::parseArgsJson(reinterpret_cast<const char*>(bytes), static_cast<size_t>(len));
    env->ReleaseByteArrayElements(jArgs, bytes, JNI_ABORT);
  }
  return dispatch(env, jMethod, std::move(args));
}

extern "C" JNIEXPORT jobject JNICALL
Java_app_status_mobile_ipc_StatusGoService_nativeCallDirect(JNIEnv* env, jclass, jstring jMethod, jobject jArgs, jint length) {
  std::vector<std::string> args;
  const char* data = jArgs ? static_cast<const char*>(env->GetDirectBufferAddress(jArgs)) : nullptr;
  const jlong capacity = jArgs ? env->GetDirectBufferCapacity(jArgs) : 0;
  if (data && length >= 0 && length <= capacity) {
    args = statusgo_ipc::parseArgsJson(data, static_cast<size_t>(length));
  } else if (jArgs) {
    loge("nativeCallDirect: unreadable argument buffer");
  }
  return dispatch(env, jMethod, std::move(args));
}

extern "C" JNIEXPORT void JNICALL
Java_app_status_mobile_ipc_StatusGoService_nativeFree(JNIEnv* env, jclass, jobject jResult) {
  if (!jResult) return;
  void* p = env->GetDirectBufferAddress(jResult);
  if (p) Free(p);
}
