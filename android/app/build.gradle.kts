import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Load signing credentials from key.properties ──────────────────────────────
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    namespace = "com.expensetracker.app.expense_tracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.expensetracker.app.expense_tracker"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Reduces APK size by only including resources for the languages used
        resourceConfigurations += listOf("en")
    }

    signingConfigs {
        create("release") {
            keyAlias      = keystoreProperties["keyAlias"]     as String? ?: ""
            keyPassword   = keystoreProperties["keyPassword"]  as String? ?: ""
            storeFile     = rootProject.file("app/moneybook-release.jks")
            storePassword = keystoreProperties["storePassword"] as String? ?: ""
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            isDebuggable = true
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            // ── APK / AAB size reduction ────────────────────────────────────
            isMinifyEnabled = true        // R8 code shrinking
            isShrinkResources = true      // Remove unused resources
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // ── Release keystore (Play Store ready) ─────────────────────────
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
