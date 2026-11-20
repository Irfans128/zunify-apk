# Flutter Wrapper & Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ZunifyG Native Activity
-keep class com.fannz.zunifyg.** { *; }

# Audio Service, Just Audio, & ExoPlayer / Media3
-keep class com.ryanheise.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media.** { *; }
-keep class androidx.media2.** { *; }
-keep class androidx.media3.** { *; }

-keepattributes Signature, InnerClasses, EnclosingMethod, *Annotation*
-dontwarn com.google.android.play.core.**
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn org.checkerframework.**
