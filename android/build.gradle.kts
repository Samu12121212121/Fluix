allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Permitir compilar con dependencias compiladas con Kotlin más nuevo (Firebase/GMS)
subprojects {
    afterEvaluate {
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            kotlinOptions {
                freeCompilerArgs = freeCompilerArgs + listOf("-Xskip-metadata-version-check")
            }
        }
    }
}

// Fix para plugins legacy sin namespace (ej: blue_thermal_printer) con AGP 8.x
subprojects {
    afterEvaluate {
        val androidLib = extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
        if (androidLib != null && androidLib.namespace == null) {
            // Usar el applicationId del manifest como namespace
            val manifestFile = file("src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val content = manifestFile.readText()
                val match = Regex("""package="([^"]+)"""").find(content)
                if (match != null) {
                    androidLib.namespace = match.groupValues[1]
                }
            }
        }
    }
}

// Configuración de directorio de build personalizado
val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()

rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
