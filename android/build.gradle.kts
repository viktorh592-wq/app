allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Стандартная настройка директории сборки для Flutter
val newBuildDir: org.gradle.api.file.Directory = rootProject.layout.buildDirectory.dir("../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: org.gradle.api.file.Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<org.gradle.api.tasks.Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
