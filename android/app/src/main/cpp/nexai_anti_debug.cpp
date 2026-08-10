#include <jni.h>
#include <algorithm>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/ptrace.h>
#include <pthread.h>
#include <fstream>
#include <string>
#include <cstring>
#include <cctype>
#include <atomic>
#include <cstdlib>

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static bool readFileAsString(const char* path, std::string& out) {
    std::ifstream f(path);
    if (!f.is_open()) return false;
    out.assign((std::istreambuf_iterator<char>(f)),
               std::istreambuf_iterator<char>());
    return true;
}

// Case-insensitive substring search
static bool ciContains(const std::string& haystack, const std::string& needle) {
    if (needle.empty()) return false;
    auto it = std::search(haystack.begin(), haystack.end(),
                          needle.begin(), needle.end(),
                          [](char a, char b) {
                              return std::tolower(static_cast<unsigned char>(a)) ==
                                     std::tolower(static_cast<unsigned char>(b));
                          });
    return it != haystack.end();
}

// Case-insensitive equality
static bool ciEqual(const std::string& a, const std::string& b) {
    if (a.size() != b.size()) return false;
    for (size_t i = 0; i < a.size(); ++i) {
        if (std::tolower(static_cast<unsigned char>(a[i])) !=
            std::tolower(static_cast<unsigned char>(b[i])))
            return false;
    }
    return true;
}

// Read a single property value from a key=value config file (e.g. build.prop)
// Returns the value string, or empty if not found.  The caller trims/compares.
static bool propEquals(const std::string& content, const std::string& key,
                       const std::string& expected) {
    std::string searchKey = key + "=";
    size_t pos = 0;
    while ((pos = content.find(searchKey, pos)) != std::string::npos) {
        // Must be at start of line
        if (pos > 0 && content[pos - 1] != '\n') {
            pos += searchKey.size();
            continue;
        }
        size_t start = pos + searchKey.size();
        size_t end = content.find('\n', start);
        std::string val = content.substr(start, end - start);
        // Trim trailing whitespace / carriage return
        while (!val.empty() && (val.back() == ' ' || val.back() == '\r' ||
                                val.back() == '\t'))
            val.pop_back();
        if (ciEqual(val, expected)) return true;
        pos += searchKey.size();
    }
    return false;
}

// Check whether a property value contains any of the given tokens (CI).
static bool propContainsAny(const std::string& content, const std::string& key,
                            const std::string tokens[], size_t tokenCount) {
    std::string searchKey = key + "=";
    size_t pos = 0;
    while ((pos = content.find(searchKey, pos)) != std::string::npos) {
        if (pos > 0 && content[pos - 1] != '\n') {
            pos += searchKey.size();
            continue;
        }
        size_t start = pos + searchKey.size();
        size_t end = content.find('\n', start);
        std::string val = content.substr(start, end - start);
        while (!val.empty() && (val.back() == ' ' || val.back() == '\r' ||
                                val.back() == '\t'))
            val.pop_back();
        for (size_t i = 0; i < tokenCount; ++i) {
            if (ciContains(val, tokens[i])) return true;
        }
        pos += searchKey.size();
    }
    return false;
}

// ---------------------------------------------------------------------------
// Individual anti-debug / environment checks
// ---------------------------------------------------------------------------

// Check /proc/self/status for TracerPid > 0
static bool checkTracerPid() {
    std::string content;
    if (!readFileAsString("/proc/self/status", content)) return false;
    const char* prefix = "TracerPid:";
    size_t pos = content.find(prefix);
    if (pos == std::string::npos) return false;
    pos += std::strlen(prefix);
    while (pos < content.size() && (content[pos] == ' ' || content[pos] == '\t'))
        ++pos;
    return pos < content.size() && content[pos] != '0';
}

// Parse and return the integer TracerPid (0 if none / unreadable)
static int getTracerPid() {
    std::string content;
    if (!readFileAsString("/proc/self/status", content)) return 0;
    const char* prefix = "TracerPid:";
    size_t pos = content.find(prefix);
    if (pos == std::string::npos) return 0;
    pos += std::strlen(prefix);
    while (pos < content.size() && (content[pos] == ' ' || content[pos] == '\t'))
        ++pos;
    int val = 0;
    while (pos < content.size() && content[pos] >= '0' && content[pos] <= '9') {
        val = val * 10 + (content[pos] - '0');
        ++pos;
    }
    return val;
}

// Scan /proc/self/maps for known Frida artifacts
static bool checkFridaMaps() {
    std::string content;
    if (!readFileAsString("/proc/self/maps", content)) return false;
    const char* needles[] = {
        "frida-agent", "frida-gadget", "frida-server",
        "re.frida.server", "frida-helper"
    };
    for (const auto& n : needles) {
        if (ciContains(content, n)) return true;
    }
    return false;
}

// Fork-based ptrace probe: child tries PTRACE_TRACEME; if it fails a
// debugger is already attached to the child, implying one is present.
static bool checkPtraceProbe() {
    pid_t pid = fork();
    if (pid == -1) return false;   // cannot determine
    if (pid == 0) {
        // Child
        if (ptrace(PTRACE_TRACEME, 0, 0, 0) == 0) {
            _exit(0);   // no debugger attached
        } else {
            _exit(1);   // debugger present
        }
    }
    // Parent
    int st = 0;
    waitpid(pid, &st, 0);
    // Best-effort detach (may fail if child already exited — safe to ignore)
    ptrace(PTRACE_DETACH, pid, 0, 0);
    return WIFEXITED(st) && WEXITSTATUS(st) == 1;
}

// Emulator detection via build.prop and /proc/cpuinfo
static bool checkEmulator() {
    // Check build.prop
    std::string buildProp;
    if (readFileAsString("/system/build.prop", buildProp)) {
        // ro.hardware == goldfish or ranchu
        if (propEquals(buildProp, "ro.hardware", "goldfish") ||
            propEquals(buildProp, "ro.hardware", "ranchu"))
            return true;
        // ro.product.model or ro.product.brand containing emulator hints
        const char* emuTokens[] = {"sdk", "google_sdk", "emulator", "genymotion"};
        if (propContainsAny(buildProp, "ro.product.model", emuTokens, 4) ||
            propContainsAny(buildProp, "ro.product.brand", emuTokens, 4))
            return true;
    }
    // Fallback: check /proc/cpuinfo
    std::string cpuinfo;
    if (readFileAsString("/proc/cpuinfo", cpuinfo)) {
        if (ciContains(cpuinfo, "goldfish") || ciContains(cpuinfo, "ranchu"))
            return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// Background watchdog thread
// ---------------------------------------------------------------------------

static std::atomic<bool> watchdogRunning(false);
static std::atomic<bool> watchdogStop(false);
static std::atomic<bool> watchdogResult(false);

static void* watchdogThread(void*) {
    while (!watchdogStop.load()) {
        bool detected = checkTracerPid() || checkFridaMaps() || checkPtraceProbe();
        watchdogResult.store(detected);
        // Sleep in 1-second increments so we can react quickly to stop signal
        for (int i = 0; i < 5; ++i) {
            if (watchdogStop.load()) return nullptr;
            sleep(1);
        }
    }
    return nullptr;
}

// ---------------------------------------------------------------------------
// JNI entry points
// ---------------------------------------------------------------------------

extern "C" {

JNIEXPORT jboolean JNICALL
Java_com_chloemlla_nexai_security_HardeningGuard_nativeAntiDebugDetected(
    JNIEnv* env, jobject thiz) {
    bool immediate = checkTracerPid() || checkFridaMaps() || checkPtraceProbe();
    return (immediate || watchdogResult.load()) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jint JNICALL
Java_com_chloemlla_nexai_security_HardeningGuard_nativeTracerPid(
    JNIEnv* env, jobject thiz) {
    return static_cast<jint>(getTracerPid());
}

JNIEXPORT jboolean JNICALL
Java_com_chloemlla_nexai_security_HardeningGuard_nativeEmulatorDetected(
    JNIEnv* env, jobject thiz) {
    return checkEmulator() ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT void JNICALL
Java_com_chloemlla_nexai_security_HardeningGuard_nativeStartWatchdog(
    JNIEnv* env, jobject thiz) {
    bool expected = false;
    if (!watchdogRunning.compare_exchange_strong(expected, true)) {
        return;   // already running, do nothing
    }
    watchdogStop.store(false);
    pthread_t thread;
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    pthread_create(&thread, &attr, watchdogThread, nullptr);
    pthread_attr_destroy(&attr);
}

JNIEXPORT void JNICALL
Java_com_chloemlla_nexai_security_HardeningGuard_nativeStopWatchdog(
    JNIEnv* env, jobject thiz) {
    watchdogStop.store(true);
    watchdogRunning.store(false);
}

}   // extern "C"