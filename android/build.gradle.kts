import org.gradle.api.tasks.testing.Test
import org.gradle.api.tasks.testing.logging.TestLogEvent

plugins {
    id("com.android.library")
}

group = "me.carda.awesome_notifications"
version = "0.11.0"

repositories {
    google()
    mavenCentral()

    maven {
        url = uri("https://jitpack.io")
    }
}

android {
    namespace = "me.carda.awesome_notifications"

    compileSdk = 37

    defaultConfig {
        minSdk = 24

        testInstrumentationRunner =
            "androidx.test.runner.AndroidJUnitRunner"

        consumerProguardFiles("consumer-rules.pro")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

tasks.withType<Test>().configureEach {
    testLogging {
        events(
            TestLogEvent.PASSED,
            TestLogEvent.SKIPPED,
            TestLogEvent.FAILED,
            TestLogEvent.STANDARD_OUT,
            TestLogEvent.STANDARD_ERROR
        )
        showStandardStreams = true
    }
    outputs.upToDateWhen { false }
}

tasks.withType<JavaCompile>().configureEach {
    options.compilerArgs.add("-Xlint:deprecation")
}

dependencies {
    val awnCoreProject = rootProject.findProject(":awn_core")
    if (awnCoreProject != null) {
        implementation(awnCoreProject)
    } else {
        implementation("com.github.kumsumit.AndroidAwnCore:core:0f9e80f2f3ffbe47bb99811c327f7645225ed6ff")
    }

    implementation("com.google.guava:guava:33.6.0-android")

    // Unit tests
    testImplementation("junit:junit:4.13.2")
    testImplementation("androidx.arch.core:core-testing:2.2.0")
    testImplementation("org.mockito:mockito-core:5.23.0")

    // Android instrumented tests
    androidTestImplementation("androidx.annotation:annotation:1.10.1")
    androidTestImplementation("org.mockito:mockito-core:5.23.0")
    androidTestImplementation("org.mockito:mockito-android:5.23.0")

    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test:core:1.7.0")
}
