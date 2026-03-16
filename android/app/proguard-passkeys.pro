# Dedicated ProGuard rules for Passkeys/WebAuthn to prevent obfuscation
# This file ensures passkey error messages remain readable in production builds

# ========== Passkeys Core (Corbado) ==========
# Prevent ALL obfuscation of passkeys classes
-keep,allowobfuscation !class com.corbado.passkeys_android.** { *; }
-keep class com.corbado.passkeys_android.** { *; }
-keep class com.corbado.passkeys_doctor.** { *; }
-keep interface com.corbado.passkeys_android.** { *; }
-keep interface com.corbado.passkeys_doctor.** { *; }

# Keep all inner classes and enums
-keep class com.corbado.passkeys_android.**$* { *; }
-keepnames class com.corbado.passkeys_android.**$* { *; }

# ========== Exception Handling ==========
# Keep ALL exception classes with original names for debugging
-keep class * extends java.lang.Exception { *; }
-keep class * extends java.lang.Error { *; }
-keep class * extends java.lang.Throwable { *; }

# Prevent obfuscation of exception class names
-keepnames class * extends java.lang.Exception
-keepnames class * extends java.lang.Error
-keepnames class * extends java.lang.Throwable

# Keep exception constructors and methods
-keepclassmembers class * extends java.lang.Throwable {
    <init>(...);
    public java.lang.String getMessage();
    public java.lang.String getLocalizedMessage();
    public java.lang.String toString();
    public java.lang.Throwable getCause();
    public java.lang.StackTraceElement[] getStackTrace();
    public void printStackTrace();
}

# ========== AndroidX Credentials API ==========
# Keep all credentials classes (used by passkeys)
-keep class androidx.credentials.** { *; }
-keep interface androidx.credentials.** { *; }
-keepnames class androidx.credentials.** { *; }

# Keep credentials exceptions with original names
-keep class androidx.credentials.exceptions.** { *; }
-keepnames class androidx.credentials.exceptions.** { *; }

# ========== Google Play Services FIDO2 ==========
# Keep all FIDO2/WebAuthn classes
-keep class com.google.android.gms.fido.** { *; }
-keep class com.google.android.gms.fido.fido2.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keepnames class com.google.android.gms.fido.** { *; }

# Keep GMS exceptions
-keep class com.google.android.gms.common.api.ApiException { *; }
-keep class com.google.android.gms.common.api.Status { *; }
-keep class com.google.android.gms.common.api.ResolvableApiException { *; }
-keepnames class com.google.android.gms.common.api.** { *; }

# Keep status codes for error reporting
-keepclassmembers class com.google.android.gms.common.api.Status {
    public int getStatusCode();
    public java.lang.String getStatusMessage();
}

# ========== Debugging Support ==========
# Preserve source file names and line numbers for stack traces
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep all annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep method parameter names for better debugging
-keepparameternames

# ========== Prevent Aggressive Optimization ==========
# Don't optimize passkey-related code to prevent runtime issues
-keep,allowshrinking class com.corbado.passkeys_android.** { *; }
-keep,allowshrinking class androidx.credentials.** { *; }
-keep,allowshrinking class com.google.android.gms.fido.** { *; }
