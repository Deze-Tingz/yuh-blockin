# Flutter and Dart
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Supabase / Network
-keep class io.supabase.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# OkHttp / Network
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Keep model classes
-keep class com.yuhblockin.** { *; }
