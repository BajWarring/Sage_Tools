import java.util.Properties // <--- FIX: Import explicit class to avoid name conflict

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// --- START: Define Version Variables ---
val localProperties = Properties() // Now usage is clean
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toInt() ?: 1
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"
// --- END: Define Version Variables ---

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

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    buildTypes {
        release {
            isMinifyEnabled = true 
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.24")
}
