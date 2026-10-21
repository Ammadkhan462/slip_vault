import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeyProperties = keystorePropertiesFile.exists()
if (hasKeyProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.slipvault.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (hasKeyProperties) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                storeFile = if (storeFilePath != null) rootProject.file(storeFilePath) else null
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    defaultConfig {
        applicationId = "com.slipvault.app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "version"

    productFlavors {
        create("core") {
            dimension = "version"
            applicationIdSuffix = ""
            manifestPlaceholders["appLabel"] = "Slip Vault"
        }
        create("autoscan") {
            dimension = "version"
            applicationIdSuffix = ".autoscan"
            manifestPlaceholders["appLabel"] = "Slip Vault (AutoScan)"
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasKeyProperties && signingConfigs.findByName("release") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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

gradle.projectsEvaluated {
    tasks.findByName("assembleDebug")?.doLast {
        val buildDir = layout.buildDirectory.get().asFile
        val coreApk = File(buildDir, "outputs/flutter-apk/app-core-debug.apk")
        val fallbackApk = File(buildDir, "outputs/flutter-apk/app-debug.apk")
        if (coreApk.exists()) {
            coreApk.copyTo(fallbackApk, overwrite = true)
        }
    }
    tasks.findByName("assembleRelease")?.doLast {
        val buildDir = layout.buildDirectory.get().asFile
        val coreApk = File(buildDir, "outputs/flutter-apk/app-core-release.apk")
        val fallbackApk = File(buildDir, "outputs/flutter-apk/app-release.apk")
        if (coreApk.exists()) {
            coreApk.copyTo(fallbackApk, overwrite = true)
        }
    }
}
