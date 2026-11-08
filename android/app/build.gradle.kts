import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.isFile) { keyPropertiesFile.inputStream().use { keyProperties.load(it) } }
val requiredSigningProperties = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingSigningProperties = requiredSigningProperties.filter { keyProperties.getProperty(it).isNullOrBlank() }
val hasSigningProperties = keyPropertiesFile.isFile && missingSigningProperties.isEmpty()

// Never produce an unsigned artifact for distribution. Debug builds do not
// require a release keystore.
fun requireReleaseSigning() {
    if (!keyPropertiesFile.isFile) {
        throw GradleException("Release signing is required. Configure android/key.properties and a release keystore; see README.md.")
    }
    if (missingSigningProperties.isNotEmpty()) {
        throw GradleException("Release signing configuration is incomplete: ${missingSigningProperties.joinToString()}. See README.md.")
    }
    if (!file(keyProperties.getProperty("storeFile")).isFile) {
        throw GradleException("Release keystore file does not exist. Check storeFile in android/key.properties.")
    }
}
val releasePackagingTasks = setOf("packageRelease", "packageReleaseBundle", "signReleaseBundle")
// Check the entire task graph so aggregate tasks such as `build` cannot bypass
// the check, and fail before compiling a release that cannot be distributed.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name in releasePackagingTasks }) {
        requireReleaseSigning()
    }
}

android {
    namespace = "com.growthcircle.growth_circle"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.growthcircle.growth_circle"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasSigningProperties) {
            create("release") {
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            if (hasSigningProperties) signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
