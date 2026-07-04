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
