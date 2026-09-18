# ── Flutter / Dart ────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ── Firebase Core ─────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Firebase Auth ─────────────────────────────────────────────────────────────
-keep class com.google.firebase.auth.** { *; }

# ── Firestore ─────────────────────────────────────────────────────────────────
-keep class com.google.firebase.firestore.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# ── Google Sign-In ────────────────────────────────────────────────────────────
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ── Kotlin ────────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keepclassmembers class **$WhenMappings { *; }

# ── General ───────────────────────────────────────────────────────────────────
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Prevent removing unused constructors needed by reflection
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
