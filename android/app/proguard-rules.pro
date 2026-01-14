# Add project specific ProGuard rules here.

# Keep Google Tink classes used by androidx.security:security-crypto
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# Ignore missing error-prone annotations (compile-time only, not needed at runtime)
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn javax.annotation.concurrent.**

# Keep EncryptedSharedPreferences classes
-keep class androidx.security.crypto.** { *; }
