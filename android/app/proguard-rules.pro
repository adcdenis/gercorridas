# Flutter rules
# Add project specific ProGuard rules here.
# You can control what gets obfuscated or shrunk by defining keep rules.

# Keep GSON classes for external APIs and serialization
-keep class com.google.gson.** { *; }

# Keep google api client classes if used
-keep class com.google.api.client.** { *; }
-keep class com.google.api.services.drive.** { *; }
-keep class com.google.apis.** { *; }
