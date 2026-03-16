# Flutter engine & embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep all Flutter plugin registrants (generated code)
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Keep dynamic_color native integration
-keep class com.google.android.material.color.** { *; }

# Keep AndroidX core (used by many plugins)
-keep class androidx.core.** { *; }
-keep class androidx.lifecycle.** { *; }
-keep class androidx.appcompat.** { *; }

# ========== SharedPreferences (API Configuration Storage) ==========
# Keep shared_preferences plugin
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Keep Android SharedPreferences implementation
-keep class android.content.SharedPreferences { *; }
-keep class android.content.SharedPreferences$** { *; }
-keepclassmembers class android.content.SharedPreferences {
    <methods>;
}

# Keep preference data classes
-keep class androidx.preference.** { *; }

# Keep ffmpeg_kit_flutter_new native classes
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keep class com.arthenica.ffmpegkit.** { *; }

# Keep url_launcher plugin
-keep class io.flutter.plugins.urllauncher.** { *; }

# Keep package_info_plus plugin
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }

# Keep dynamic_color plugin
-keep class io.material.** { *; }

# OkHttp / HTTP client (used by google_fonts)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# Prevent R8 from stripping annotations used by plugins
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Flutter Play Store split install (referenced by engine but not used)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Suppress warnings for missing classes in R8 full mode
-dontwarn java.lang.invoke.StringConcatFactory

# ========== Passkeys / WebAuthn (Corbado) ==========
# Keep all Corbado passkeys plugin classes and prevent obfuscation
-keep class com.corbado.passkeys_android.** { *; }
-keep class com.corbado.passkeys_doctor.** { *; }
-keep interface com.corbado.passkeys_android.** { *; }
-keep interface com.corbado.passkeys_doctor.** { *; }

# Keep all passkey exception classes with original names for debugging
-keep class com.corbado.passkeys_android.**$*Exception { *; }
-keep class com.corbado.passkeys_android.**$*Error { *; }
-keepnames class com.corbado.passkeys_android.** { *; }
-keepnames interface com.corbado.passkeys_android.** { *; }

# Keep all exception and error classes to preserve error messages
-keep class * extends java.lang.Exception { *; }
-keep class * extends java.lang.Error { *; }
-keep class * extends java.lang.Throwable { *; }
-keepnames class * extends java.lang.Exception { *; }
-keepnames class * extends java.lang.Error { *; }
-keepnames class * extends java.lang.Throwable { *; }

# Keep exception constructors and getMessage() for error reporting
-keepclassmembers class * extends java.lang.Throwable {
    <init>(...);
    public java.lang.String getMessage();
    public java.lang.String getLocalizedMessage();
    public java.lang.Throwable getCause();
    public java.lang.StackTraceElement[] getStackTrace();
}

# Keep WebAuthn/FIDO2 related classes (used by passkeys)
-keep class androidx.credentials.** { *; }
-keep interface androidx.credentials.** { *; }
-keepclassmembers class androidx.credentials.** { *; }
-keepnames class androidx.credentials.** { *; }

# Keep all credentials exceptions
-keep class androidx.credentials.exceptions.** { *; }
-keepnames class androidx.credentials.exceptions.** { *; }

# Keep Google Play Services Auth (required for passkeys on Android)
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.fido.** { *; }
-keep class com.google.android.gms.fido.fido2.** { *; }
-keepnames class com.google.android.gms.auth.** { *; }
-keepnames class com.google.android.gms.fido.** { *; }

# Keep all GMS exceptions for error reporting
-keep class com.google.android.gms.common.api.ApiException { *; }
-keep class com.google.android.gms.common.api.Status { *; }
-keepnames class com.google.android.gms.common.api.** { *; }

# Keep JSON serialization for passkey data structures
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep all method names for better stack traces
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*

# ========== Google Sign-In ==========
# Keep Google Sign-In plugin classes
-keep class io.flutter.plugins.googlesignin.** { *; }
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ========== Flutter Secure Storage ==========
# Keep flutter_secure_storage plugin (used for token persistence)
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep AndroidKeyStore (used by secure storage)
-keep class android.security.keystore.** { *; }
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }

# ========== Dio HTTP Client (OpenAI API Calls) ==========
# Keep Dio native adapter classes
-keep class io.flutter.plugins.connectivity.** { *; }
-keep class com.baseflow.connectivity_plus.** { *; }

# Keep HTTP/2 adapter
-keep class com.baseflow.http2adapter.** { *; }

# Keep cookie jar
-keep class io.flutter.plugins.cookiejar.** { *; }

# ========== JSON Serialization (API Configuration & Data Models) ==========
# Keep all JSON-related reflection for Dart models
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep all classes with toJson/fromJson methods (Dart models)
-keepclassmembers class * {
    public <methods>;
    public <fields>;
}

# Preserve line numbers for debugging stack traces
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ========== Apache Commons Imaging (AWT not available on Android) ==========
# Suppress warnings for Java AWT classes (not available on Android)
-dontwarn java.awt.**
-dontwarn javax.imageio.**
-dontwarn org.apache.commons.imaging.**

# Keep Apache Commons Imaging classes but ignore AWT dependencies
-keep class org.apache.commons.imaging.** { *; }
-keep interface org.apache.commons.imaging.** { *; }
