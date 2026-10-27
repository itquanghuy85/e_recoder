# Flutter and Media3 ship their own consumer rules. The app code uses no reflection; the only
# names that must survive are the ones looked up by the platform from the manifest.
-keep class com.huluca.escreenrecorder.MainActivity { *; }
-keep class com.huluca.escreenrecorder.RecorderService { *; }
# Play Core classes referenced (but not shipped) by the Flutter embedding's deferred components.
-dontwarn com.google.android.play.core.**
