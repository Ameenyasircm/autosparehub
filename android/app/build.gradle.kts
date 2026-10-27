plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.codemates.auto_spare_hub"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.codemates.auto_spare_hub"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        manifestPlaceholders["appName"] = "SN AutoSpare"
    }

    flavorDimensions += "default"
    productFlavors {
        create("user") {
            dimension = "default"
            applicationId = "com.codemates.auto_spare_hub"
            manifestPlaceholders["appName"] = "SN AutoSpare"
        }
        create("admin") {
            dimension = "default"
            applicationId = "com.codemates.auto_spare_hub_admin"
            manifestPlaceholders["appName"] = "SNAuto Admin"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

tasks.matching { it.name.contains("GlobalSynthetics") }.configureEach {
    doFirst {
        outputs.files.files.forEach { file ->
            file.mkdirs()
        }
    }
}
