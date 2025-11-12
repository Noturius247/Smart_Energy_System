allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Only relocate buildDir for modules that live inside this repository (e.g., :app).
// Do NOT override external plugin modules (e.g., ones under Pub cache on a different drive),
// to avoid cross-drive path issues on Windows.
subprojects {
    val projectIsInThisRepo = project.projectDir.absolutePath.startsWith(rootDir.absolutePath)
    if (projectIsInThisRepo) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Workaround for AGP 8+ requiring namespace in library modules (some plugins may miss it)
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
