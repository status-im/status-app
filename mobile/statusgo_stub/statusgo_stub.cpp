#include <jni.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <mutex>
#include <string>
#include <android/log.h>

#include "args_json.h"
// Tiny UI-process stub for status-go's exported C API.
// Instead of linking libstatus (real status-go) into the UI process, we export
// the same symbols and forward them to a separate Android service process via Java.
//
// Note: For now, the Java side can be a placeholder. This file focuses on:
// - providing the symbols required by the Nim glue (src/status_go wrappers)
// - returning heap-allocated cstrings compatible with status-go's Free()
//
// The service-side implementation will be added next (Binder + separate process).
namespace {
static JavaVM* g_vm = nullptr;
static jclass g_bridgeClass = nullptr;
static jmethodID g_callMethod = nullptr; // static IpcPayload call(String method, ByteBuffer argsUtf8)
static jclass g_payloadClass = nullptr;
static jmethodID g_payloadNativeView = nullptr; // Object nativeView(): byte[] or direct ByteBuffer
static jmethodID g_payloadLength = nullptr;
static jmethodID g_payloadClose = nullptr;
static jclass g_byteBufferClass = nullptr;
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
static char* dupToMalloc(const char* s, size_t n) {
  char* out = static_cast<char*>(malloc(n + 1));
  if (!out) return nullptr;
  if (n) memcpy(out, s, n);
  out[n] = '\0';
  return out;
}
static char* dupToMalloc(const char* s) {
  if (!s) s = "";
  return dupToMalloc(s, strlen(s));
}
static bool clearException(JNIEnv* env) {
  if (!env->ExceptionCheck()) return false;
  env->ExceptionClear();
  return true;
}

// Copies an IpcPayload into a malloc'd C string (released by Free) and closes it.
static char* takePayload(JNIEnv* env, jobject payload) {
  char* out = nullptr;
  jobject view = env->CallObjectMethod(payload, g_payloadNativeView);
  const jint length = clearException(env) ? -1 : env->CallIntMethod(payload, g_payloadLength);
  if (!clearException(env) && view && length >= 0) {
    if (env->IsInstanceOf(view, g_byteBufferClass)) {
      const char* direct = static_cast<const char*>(env->GetDirectBufferAddress(view));
      if (direct && length <= env->GetDirectBufferCapacity(view)) {
        out = dupToMalloc(direct, static_cast<size_t>(length));
      }
    } else {
      jbyteArray bytes = static_cast<jbyteArray>(view);
      if (length <= env->GetArrayLength(bytes)) {
        out = static_cast<char*>(malloc(static_cast<size_t>(length) + 1));
        if (out) {
          env->GetByteArrayRegion(bytes, 0, length, reinterpret_cast<jbyte*>(out));
          out[length] = '\0';
        }
      }
    }
  }
  if (view) env->DeleteLocalRef(view);
  env->CallVoidMethod(payload, g_payloadClose);
  clearException(env);
  return out ? out : dupToMalloc("{\"error\":\"unreadable status-go response\"}");
}

static char* callJava(const char* method, const std::string& argsJson) {
  JNIEnv* env = getEnv();
  if (!env) {
    return dupToMalloc("{\"error\":\"status-go stub not initialized\"}");
  }

  // Keep lock scope minimal: copy references, then perform Binder call unlocked.
  jclass bridgeClass = nullptr;
  jmethodID callMethod = nullptr;
  {
    std::lock_guard<std::mutex> guard(g_lock);
    if (!g_bridgeClass || !g_callMethod || !g_payloadClass) {
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
  // Valid for the duration of the call only; Java copies it into the request payload.
  jobject jArgs = env->NewDirectByteBuffer(const_cast<char*>(argsJson.data()), static_cast<jlong>(argsJson.size()));
  jobject jRet = jArgs ? env->CallStaticObjectMethod(bridgeClass, callMethod, jMethod, jArgs) : nullptr;
  env->DeleteLocalRef(jMethod);
  if (jArgs) env->DeleteLocalRef(jArgs);
  env->DeleteLocalRef(bridgeClass);
  if (clearException(env) || !jArgs) {
    if (jRet) env->DeleteLocalRef(jRet);
    return dupToMalloc("{\"error\":\"java exception in status-go stub\"}");
  }
  if (!jRet) return dupToMalloc("");
  char* out = takePayload(env, jRet);
  env->DeleteLocalRef(jRet);
  return out;
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
  if (g_payloadClass) {
    env->DeleteGlobalRef(g_payloadClass);
    g_payloadClass = nullptr;
  }
  if (!g_byteBufferClass) {
    jclass byteBufferClass = env->FindClass("java/nio/ByteBuffer");
    if (byteBufferClass) {
      g_byteBufferClass = (jclass)env->NewGlobalRef(byteBufferClass);
      env->DeleteLocalRef(byteBufferClass);
    }
  }
  g_bridgeClass = (jclass)env->NewGlobalRef(bridgeClass);
  g_callMethod = env->GetStaticMethodID(g_bridgeClass, "call",
                                        "(Ljava/lang/String;Ljava/nio/ByteBuffer;)Lapp/status/mobile/ipc/IpcPayload;");
  if (!g_callMethod) {
    clearException(env);
    loge("Failed to find StatusGoStub.call(String,ByteBuffer)");
  }
  // Resolved here, on a Java thread: FindClass on attached native threads uses the system loader.
  jclass payloadClass = env->FindClass("app/status/mobile/ipc/IpcPayload");
  if (payloadClass) {
    g_payloadNativeView = env->GetMethodID(payloadClass, "nativeView", "()Ljava/lang/Object;");
    g_payloadLength = env->GetMethodID(payloadClass, "length", "()I");
    g_payloadClose = env->GetMethodID(payloadClass, "close", "()V");
    if (g_payloadNativeView && g_payloadLength && g_payloadClose && g_byteBufferClass) {
      g_payloadClass = (jclass)env->NewGlobalRef(payloadClass);
    }
    env->DeleteLocalRef(payloadClass);
  }
  if (!g_payloadClass) {
    clearException(env);
    loge("Failed to resolve IpcPayload methods");
  }
}

// Called from Java (Binder listener) to deliver signals into the stored C callback.
JNIEXPORT void JNICALL
Java_app_status_mobile_StatusGoStub_nativeDeliverSignal(JNIEnv* env, jclass, jbyteArray utf8) {
  if (!utf8 || !g_signalCb) return;
  const jsize len = env->GetArrayLength(utf8);
  std::string signal(static_cast<size_t>(len), '\0');
  env->GetByteArrayRegion(utf8, 0, len, reinterpret_cast<jbyte*>(&signal[0]));
  g_signalCb(signal.c_str());
}

// Shared regions carry a NUL after the payload (IpcPayload), so the mapping is passed as is.
JNIEXPORT void JNICALL
Java_app_status_mobile_StatusGoStub_nativeDeliverSignalDirect(JNIEnv* env, jclass, jobject utf8, jint length) {
  if (!utf8 || !g_signalCb || length < 0) return;
  const char* data = static_cast<const char*>(env->GetDirectBufferAddress(utf8));
  const jlong capacity = env->GetDirectBufferCapacity(utf8);
  if (!data || length > capacity) return;
  if (length < capacity && data[length] == '\0') {
    g_signalCb(data);
    return;
  }
  const std::string signal(data, static_cast<size_t>(length));
  g_signalCb(signal.c_str());
}

void Free(void* p) { free(p); }

void SetSignalEventCallback(SignalCallback cb) { g_signalCb = cb; }

// Called by generated exports.
// - All arguments are passed as strings (even ints/bools) to simplify IPC.
// - The service side will interpret them based on the called method.
char* statusgo_stub_callv(const char* method, const char** argv, size_t argc) {
  return callJava(method, statusgo_ipc::buildArgsJson(argv, argc));
}

} // extern "C"

