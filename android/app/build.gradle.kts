plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nullx.cyber"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    // ═══════════════════════════════════════════════════════════════
    // ✅ WAJIB: Core Library Desugaring untuk flutter_local_notifications
    // ═══════════════════════════════════════════════════════════════
    compileOptions {
        coreLibraryDesugaringEnabled true
        isCoreLibraryDesugaringEnabled = true       // ✅ TAMBAH
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.nullx.cyber"
        minSdk = 23                                  // ✅ GANTI dari flutter.minSdkVersion ke 21
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true                       // ✅ TAMBAH
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

// ═══════════════════════════════════════════════════════════════
// ✅ TAMBAH BLOK INI DI PALING BAWAH
// ═══════════════════════════════════════════════════════════════
dependencies {
    implementation("androidx.multidex:multidex:2.0.1")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}