plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.blueprint_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    flavorDimensions += "env"

    productFlavors {
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "[S] Blueprint App")
            // BEGIN_ADS
            manifestPlaceholders["admobAppId"] = "ca-app-pub-3940256099942544~3347511713"
            // END_ADS
        }
        create("production") {
            dimension = "env"
            resValue("string", "app_name", "Blueprint App")
            // BEGIN_ADS
            manifestPlaceholders["admobAppId"] = "ca-app-pub-3940256099942544~3347511713"
            // END_ADS
        }
    }

    defaultConfig {
        applicationId = "com.example.blueprint_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystorePath = System.getenv("UPLOAD_KEYSTORE_PATH")
    if (!keystorePath.isNullOrEmpty()) {
        signingConfigs {
            create("release") {
                storeFile = file(keystorePath)
                storePassword = System.getenv("UPLOAD_STORE_PASSWORD") ?: ""
                keyAlias = System.getenv("UPLOAD_KEY_ALIAS") ?: ""
                keyPassword = System.getenv("UPLOAD_KEY_PASSWORD") ?: ""
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (!keystorePath.isNullOrEmpty()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
