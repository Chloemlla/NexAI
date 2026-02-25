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

# Keep shared_preferences plugin
-keep class io.flutter.plugins.sharedpreferences.** { *; }

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
