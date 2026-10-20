import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // after the Android and Kotlin plugins
}

// Upload-key credentials live in android/key.properties (never committed).
// Without that file, release builds are debug-signed: fine for testing on
// a phone, not accepted by Google Play.
val signing = Properties().apply {
    rootProject.file("key.properties").takeIf { it.exists() }?.let { load(FileInputStream(it)) }
}
val hasUploadKey = signing.isNotEmpty()

android {
    namespace = "com.foliomed.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.foliomed.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 35 // Google Play's current minimum for new apps
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true // java.time for scheduled notifications
    }
    kotlinOptions { jvmTarget = "17" }

    signingConfigs {
        create("upload") {
            if (hasUploadKey) {
                storeFile = file(signing.getProperty("storeFile"))
                storePassword = signing.getProperty("storePassword")
                keyAlias = signing.getProperty("keyAlias")
                keyPassword = signing.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "upload" else "debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
