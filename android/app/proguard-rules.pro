# kotlinx.serialization: keep @Serializable classes and their companions so
# reflection-free codegen still resolves after shrinking.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

-keepclassmembers class * {
    *** Companion;
}
-keep class kotlinx.serialization.** { *; }
-keep class com.jamesdai.storycharts.data.** { *; }

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**

# Tink (via EncryptedSharedPreferences) references errorprone annotations
# that aren't on the Android classpath.
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
