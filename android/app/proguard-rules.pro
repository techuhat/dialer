# Used only when R8 is enabled in app/build.gradle.kts. Flutter and plugins ship their own rules;
# these cover classes Android instantiates by name from the manifest.
-keep class com.techuhat.umar.MainActivity { *; }
-keep class com.techuhat.umar.services.MyCallService { *; }
-keep class com.techuhat.umar.receivers.** { *; }
-dontwarn io.flutter.embedding.**
