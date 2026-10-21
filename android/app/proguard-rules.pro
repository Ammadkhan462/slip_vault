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
-keep class io.simonbinder.sqlite3_flutter_libs.** { *; }
-dontwarn io.simonbinder.sqlite3_flutter_libs.**

# Flutter Image Compress
-keep class com.example.flutter_image_compress.** { *; }
-dontwarn com.example.flutter_image_compress.**

# In-App Review & Purchase
-keep class io.flutter.plugins.inappreview.** { *; }
-keep class io.flutter.plugins.inapppurchase.** { *; }
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# Local Auth Biometrics
-keep class androidx.biometric.** { *; }

# Share Plus & Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
