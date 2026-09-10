# R8 keeps for the plugins this app ships with native code.
#
# Flutter's Gradle plugin already contributes the engine's own rules, and each
# plugin ships its own consumer rules; these cover the entry points R8 cannot
# see because they are only ever reached over a method channel.
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# printing draws through the Android print framework, which instantiates these
# by name from the system side.
-keep class net.nfet.flutter.printing.** { *; }
-dontwarn net.nfet.flutter.printing.**

# Reflected by the Play Core split-install shim that the engine references but
# this app, being a plain APK, never bundles.
-dontwarn com.google.android.play.core.**
