import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toInt() ?: 1
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    namespace = "com.sage.tools"
    compileSdk = 35
    ndkVersion = "26.1.10909125"
    buildToolsVersion = "35.0.0"

    defaultConfig {
        applicationId = "com.sage.tools"
        minSdk = 23
        targetSdk = 35
        versionCode = flutterVersionCode
        versionName = flutterVersionName
    }

    // 1. Define the Signing Config
    signingConfigs {
        create("release") {
            // We will create this file in the GitHub Action
            storeFile = file("app.jks")
            storePassword = "password"
            keyAlias = "key"
            keyPassword = "password"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    buildTypes {
        release {
            // 2. Apply the Signing Config
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.24")
}
