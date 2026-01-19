plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.sage.tools"
    compileSdk = 35
    ndkVersion = "26.1.10909125"
    buildToolsVersion = "35.0.0" // <--- CRITICAL FIX

    defaultConfig {
        applicationId = "com.sage.tools"
        minSdk = 23
        targetSdk = 35
        versionCode = flutterVersionCode.toInteger()
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
            // Basic shrinking for release
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.24")
}
