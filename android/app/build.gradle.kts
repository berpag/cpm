plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
}

fun localProperties(key: String, file: String = "local.properties"): String {
    val properties = java.util.Properties()
    val localPropertiesFile = rootProject.file(file)
    if (localPropertiesFile.exists()) {
        properties.load(java.io.FileInputStream(localPropertiesFile))
    }
    return properties.getProperty(key) ?: ""
}

val flutterVersionCode: String = localProperties("flutter.versionCode")
val flutterVersionName: String = localProperties("flutter.versionName")

android {
    namespace = "com.example.cpm" // Puedes cambiar "com.example" por tu propio dominio si quieres
    compileSdk = 34 // Usamos una versión fija recomendada por Flutter
    
    // --- LÍNEA AÑADIDA ---
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        applicationId = "com.example.cpm" // Debe coincidir con el namespace
        
        // --- LÍNEA MODIFICADA ---
        minSdk = 23
        
        targetSdk = 34
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            isSigningReady = true // Opcional, pero ayuda a evitar warnings
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Las dependencias se quedan como están
}