// android/app/build.gradle.kts
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // <-- Añadido
}

android {
    namespace = "com.example.cpm"
    compileSdk = 35 
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8 // <-- Cambiado a 1.8 por compatibilidad
        targetCompatibility = JavaVersion.VERSION_1_8 // <-- Cambiado a 1.8
    }

    kotlinOptions {
        jvmTarget = "1.8" // <-- Cambiado a 1.8
    }

    defaultConfig {
        applicationId = "com.example.cpm"
        minSdk = 23 // <-- Requisito de Firebase
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true // <-- Añadido
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1") // <-- Añadido
}