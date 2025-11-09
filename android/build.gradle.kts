import com.android.build.gradle.LibraryExtension
import kotlin.math.max

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    if (name == "contacts_service") {
        afterEvaluate {
            extensions.findByName("android")?.let { extension ->
                if (extension is LibraryExtension) {
                    extension.namespace = "flutter.plugins.contactsservice.contactsservice"
                    extension.compileSdk = 34
                    extension.defaultConfig {
                        minSdk = max(minSdk ?: 16, 24)
                        targetSdk = 34
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
