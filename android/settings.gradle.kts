pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val localPropsFile = java.io.File(rootDir, "local.properties")
        if (localPropsFile.exists()) {
            localPropsFile.inputStream().use { properties.load(it) }
        }
        val fromLocal = properties.getProperty("flutter.sdk")
        val fromEnv = System.getenv("FLUTTER_HOME") ?: System.getenv("FLUTTER_SDK")
        val resolved = fromLocal ?: fromEnv
        require(resolved != null) {
            "Flutter SDK path not found. Set 'flutter.sdk' in local.properties or define FLUTTER_HOME/FLUTTER_SDK environment variable."
        }
        resolved
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
