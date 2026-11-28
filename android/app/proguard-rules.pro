# ── ML Kit linkfirebase ────────────────────────────────────────────────
# google_mlkit_image_labeling depends on com.google.mlkit:linkfirebase:17.0.0,
# which has compile-time references to the deprecated firebase-iid module.
# firebase-iid is excluded from the dependency tree (no longer shipped),
# so we tell R8 to ignore the missing classes instead of failing the build.
-dontwarn com.google.firebase.iid.**
-dontwarn com.google.firebase.iid.FirebaseInstanceId

# ── ML Kit Image Labeling (preserve for Android release builds) ────────
-keep class com.google.mlkit.vision.label.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_label** { *; }
