# R8 / ProGuard rules for release builds.
#
# The Flutter Gradle plugin already contributes the rules that keep the engine,
# the embedding and the generated plugin registrant. Keep this file minimal:
# broad `-keep class **` rules would defeat `isMinifyEnabled = true`.
#
# Add a targeted `-keep` here only when R8 is observed stripping something. R8
# failures are usually runtime, not build-time, so always launch the release APK
# on a device after changing dependencies.

# Annotation processors and their transitive logging facades are compile-time
# only; R8 warns about the classes they reference but never ships them.
-dontwarn javax.annotation.**
-dontwarn org.slf4j.**
