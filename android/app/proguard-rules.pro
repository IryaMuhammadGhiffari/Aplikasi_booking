# Flutter needed rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Google Fonts download
-keep class com.google.** { *; }

# Keep shared_preferences
-keep class com.example.** { *; }

# Play Core (split compat / deferred components) — optional, needed for Play Store
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# error_prone_annotations — referenced by lint annotations
-dontwarn javax.lang.model.element.Modifier
