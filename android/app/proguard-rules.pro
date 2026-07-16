# NexAI release hardening for R8.
# Dart code is compiled by Flutter AOT; these rules harden the Android/Kotlin
# host layer, generated plugin registration, and Java/Kotlin dependencies.

-keepattributes *Annotation*,InnerClasses,EnclosingMethod,Signature
-allowaccessmodification
-adaptclassstrings
-overloadaggressively
-repackageclasses com.chloemlla.nexai.o
-printusage build/outputs/mapping/release/usage.txt

# Release diagnostics should not keep logging call sites alive.
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
    public static *** wtf(...);
}
-assumenosideeffects class io.flutter.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
    public static *** wtf(...);
}

# Android framework instantiates manifest components by name. Keep only the
# lifecycle entry points while allowing R8 to optimize their bodies.
-keep,allowoptimization class com.chloemlla.nexai.MainActivity {
    public <init>();
    public <methods>;
    protected <methods>;
}
-keep,allowoptimization class com.chloemlla.nexai.NexAIApplication {
    public <init>();
    public <methods>;
    protected <methods>;
}

# Flutter discovers the generated registrant reflectively and the embedding
# requires stable public plugin APIs. App MethodChannel handlers are direct
# references and remain free to be obfuscated.
-keep class io.flutter.plugins.GeneratedPluginRegistrant {
    public static void registerWith(io.flutter.embedding.engine.FlutterEngine);
}
-keep,allowoptimization class io.flutter.app.** { *; }
-keep,allowoptimization class io.flutter.embedding.** { *; }
-keep,allowoptimization class io.flutter.plugin.** { *; }
-keep,allowoptimization class io.flutter.util.** { *; }
-keep,allowoptimization class io.flutter.view.** { *; }

# JNI relies on exact native method names. Keep classes that expose native
# methods and the native-backed libraries used by the Android host.
-keepclasseswithmembernames class * {
    native <methods>;
}
-keep,allowoptimization class com.tencent.mmkv.** { *; }
-keep,allowoptimization class com.antonkarpenko.ffmpegkit.** { *; }
-keep,allowoptimization class com.arthenica.ffmpegkit.** { *; }

# Android platform and WebView callback entry points invoked by annotation.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Passkey diagnostics compare Credential Manager exception names with backend
# failure hints. Preserve external exception names without pinning app classes.
-keepnames class androidx.credentials.exceptions.**
-keepnames class com.google.android.gms.common.api.ApiException

# Optional or desktop/JVM APIs referenced by transitive libraries but absent on
# Android. These warnings do not imply code is packaged into the APK.
-keep class androidx.compose.** { *; }
-dontwarn androidx.compose.**
-dontwarn androidx.lifecycle.**
-dontwarn androidx.navigation.**
-dontwarn androidx.room.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn java.awt.**
-dontwarn java.lang.invoke.StringConcatFactory
-dontwarn javax.annotation.**
-dontwarn javax.imageio.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.apache.commons.imaging.**

############################################################
# Lumen Crash SDK minify exemption
# Artifact: com.chloemlla.lumen:lumen-crash
# Required when release minify/resource shrink is enabled.
# Prevents white-screen/startup crash from author integrity
# fail-closed checks and missing crash public API symbols.
############################################################

# Keep annotations / signatures used by integrity + public API.
-keepattributes *Annotation*, InnerClasses, EnclosingMethod, Signature
-keepattributes RuntimeVisibleAnnotations, AnnotationDefault
-keepattributes SourceFile, LineNumberTable

# Required: author attribution constants must keep source values/names.
-keep class com.chloemlla.lumen.crash.CrashAuthorAttribution {
    public static final java.lang.String *;
    public static *** payload();
}
-keepclassmembers class com.chloemlla.lumen.crash.CrashAuthorAttribution {
    public static final java.lang.String *;
}

# Required: integrity entry points used on install / report / UI open.
-keep class com.chloemlla.lumen.crash.AuthorIntegrity {
    public static *** verifyOrThrow(...);
    public static *** fingerprintHex();
    public static *** verifiedAuthorBlock();
}
-keep class com.chloemlla.lumen.crash.AuthorBlock { *; }

# Required backup: keep public SDK API used by host integration
-keep class com.chloemlla.lumen.crash.LumenCrash { *; }
-keep class com.chloemlla.lumen.crash.LumenCrashConfig { *; }
-keep class com.chloemlla.lumen.crash.LumenCrashConfigBuilder { *; }
-keep class com.chloemlla.lumen.crash.LumenCrashDefaults { *; }
-keep class com.chloemlla.lumen.crash.LumenCrashFileProvider { *; }
-keep class com.chloemlla.lumen.crash.CrashReport { *; }
-keep class com.chloemlla.lumen.crash.CrashAppInfo { *; }
-keep class com.chloemlla.lumen.crash.CrashReportStore { *; }
-keep class com.chloemlla.lumen.crash.CrashBreadcrumbs { *; }
-keep class com.chloemlla.lumen.crash.CrashReportPasteUploader { *; }
-keep class com.chloemlla.lumen.crash.ui.LumenCrashReportScreenKt { *; }
-keep class com.chloemlla.lumen.crash.ui.LumenCrashGateKt { *; }

# Package-level exemption (safe default for third-party hosts)
-keep class com.chloemlla.lumen.crash.** { *; }
-keepclassmembers class com.chloemlla.lumen.crash.** { *; }
-keepnames class com.chloemlla.lumen.crash.**
-dontwarn com.chloemlla.lumen.crash.**

# Crash gate activity is instantiated from the manifest.
-keep,allowoptimization class com.chloemlla.nexai.CrashGateActivity {
    public <init>();
    public <methods>;
    protected <methods>;
}
