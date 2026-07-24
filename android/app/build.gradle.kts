plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
    // FCM wake-up (ADR-003) — google-services.json is already present at
    // android/app/google-services.json (prompts/Firebase_Setup.md).
    id "com.google.gms.google-services"
}

android {
    namespace = "com.pokatuha.app"
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.pokatuha.app"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // Never expose FCM token / secrets in release (Firebase_Setup.md).
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // FCM wake-up only (ADR-003). Forbidden: Firestore, Auth, Storage, etc.
    implementation platform("com.google.firebase:firebase-bom:33.4.0")
    implementation("com.google.firebase:firebase-messaging")
}
