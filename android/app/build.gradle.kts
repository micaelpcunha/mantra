import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keyPropertiesFile.exists()

if (hasReleaseSigning) {
    keyPropertiesFile.inputStream().use(keyProperties::load)
}

fun requiredReleaseProperty(name: String): String {
    val value = keyProperties.getProperty(name)?.trim()
    if (value.isNullOrEmpty()) {
        throw GradleException(
            "android/key.properties is missing `$name` for release signing.",
        )
    }
    return value
}

val requestedTaskNames = gradle.startParameter.taskNames.map { it.lowercase() }
val isReleaseTaskRequested = requestedTaskNames.any { taskName ->
    taskName.contains("release")
}

if (isReleaseTaskRequested && !hasReleaseSigning) {
    throw GradleException(
        "Missing android/key.properties for release signing. " +
            "Copy android/key.properties.example, point it to your keystore, " +
            "and fill in the real credentials before building release.",
    )
}

android {
    namespace = "com.micaelcunha.mantra"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.micaelcunha.mantra"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                val resolvedStoreFile = rootProject.file(
                    requiredReleaseProperty("storeFile"),
                )
                if (!resolvedStoreFile.exists()) {
                    throw GradleException(
                        "Release keystore not found at `${resolvedStoreFile.path}`.",
                    )
                }

                storeFile = resolvedStoreFile
                storePassword = requiredReleaseProperty("storePassword")
                keyAlias = requiredReleaseProperty("keyAlias")
                keyPassword = requiredReleaseProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
