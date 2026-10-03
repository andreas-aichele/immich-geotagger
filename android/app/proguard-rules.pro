# Workaround for flutter-maplibre 0.3.6 on Android 17 release builds.
# Upstream issue: https://github.com/josxha/flutter-maplibre/issues/562
# Upstream fix: https://github.com/josxha/flutter-maplibre/pull/564
#
# MapLibre's JNI bridge relies on Flutter platform-view types retaining their
# original names. R8/ProGuard obfuscation otherwise causes the native map view
# to fail to initialize in release builds.
-keep class io.flutter.plugin.platform.** { *; }
