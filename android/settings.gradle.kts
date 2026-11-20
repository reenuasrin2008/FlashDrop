pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val localPropertiesFile = file("local.properties")
        val fromLocalProperties = if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { properties.load(it) }
            properties.getProperty("flutter.sdk")
        } else {
            null
        }
        val sdkPath = fromLocalProperties ?: System.getenv("FLUTTER_ROOT")
        require(!sdkPath.isNullOrBlank()) {
            "flutter.sdk not set in local.properties and FLUTTER_ROOT is not set"
        }
        sdkPath
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
    id("com.android.application") version "8.6.0" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
