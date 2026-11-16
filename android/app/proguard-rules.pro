# Flutter embedding references Play Core (deferred components) which we don't ship.
-dontwarn com.google.android.play.core.**

# Components declared in the manifest are kept automatically by AAPT rules;
# keep our capture package explicitly so method-channel/service wiring never breaks.
-keep class app.upme.upme.capture.** { *; }
