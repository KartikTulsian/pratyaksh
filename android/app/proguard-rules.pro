# Flutter & Dart
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# Only suppress warnings about SplitCompatApplication (do NOT keep)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google Play services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ML Kit + TensorFlow Lite GPU
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
