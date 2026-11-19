pluginManagement {
    val flutterSdkPath = run {
        val localPropsFile = file("local.properties")
        val fromProps = if (localPropsFile.exists()) {
            val properties = java.util.Properties()
            localPropsFile.inputStream().use { properties.load(it) }
            properties.getProperty("flutter.sdk")
        } else {
            null
        }
        val resolved = fromProps ?: System.getenv("FLUTTER_ROOT")
        require(!resolved.isNullOrBlank()) {
            "flutter.sdk not set in local.properties and FLUTTER_ROOT env var is empty"
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
    id("com.android.application") version "8.6.1" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}

include(":app")
