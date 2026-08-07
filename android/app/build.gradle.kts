// Kotlin DSL bu sınıfları örtük olarak getirmiyor; Groovy'den geçerken en sık
// atlanan yer burası.
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
// key.properties dosyasını yükle
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
android {
    namespace = "com.mersev.latermark"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mersev.latermark"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        multiDexEnabled = true
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

signingConfigs {
        create("release") {
            // Dosyadan oku, eğer dosya yoksa hata verme (CI/CD dostu yapı)
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true

            // Sadece bu blok kalmalı, altındaki Groovy satırını sildik:
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        getByName("debug") {
            // Debug da ayrı, karışmaması iyi
        }
    }
}

dependencies {
    // ML Kit metin tanıma — Flutter eklentisi olarak değil, doğrudan Gradle
    // bağımlılığı olarak. Eklenti sürümü iOS tarafında CocoaPods zorunlu
    // kılıyor ve projenin Swift Package Manager kurulumunu bozuyordu.
    //
    // Play Services sürümü seçildi: model APK'ya gömülmüyor, ilk kullanımda
    // cihaza iniyor. Paket boyutu birkaç MB yerine birkaç KB artıyor.
    implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.1")
    implementation("androidx.exifinterface:exifinterface:1.4.2")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
