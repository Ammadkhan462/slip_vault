# Flutter Wrapper Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Play Services & ML Kit Text Recognition
-keep class com.google.android.gms.** { *; }
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.mlkit.**

# Google Play Core & Flutter Deferred Components
-dontwarn com.google.android.play.core.**

# Drift & SQLite
-keep class net.sqlcipher.** { *; }
-keep class org.sqlite.** { *; }

# Local Auth Biometrics
-keep class androidx.biometric.** { *; }

# Share Plus & Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
