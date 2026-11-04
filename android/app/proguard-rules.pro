# Flutter Wrapper & Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Zunify Native Android Classes (Equalizer + APK Self-Installer + FileProvider)
-keep class com.fannz.zunify.** { *; }
-keep class androidx.core.content.FileProvider { *; }

# Audio Service, Just Audio, & ExoPlayer / Media3
-keep class com.ryanheise.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media.** { *; }
-keep class androidx.media2.** { *; }
-keep class androidx.media3.** { *; }

# Flutter Local Notifications & GSON
-keep class com.dexterous.** { *; }
-keepattributes Signature, InnerClasses, EnclosingMethod, *Annotation*

-dontwarn com.google.android.play.core.**
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn org.checkerframework.**

