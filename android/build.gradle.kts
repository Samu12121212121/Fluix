// Fuerza KGP 2.4.0 en el classpath del buildscript principal, overrideando el 2.2.x que Flutter
// bundlea en su composite build (flutter_tools/gradle). Sin esto, Gradle usa el KGP de Flutter
// y el compiler version es 2.2.x, incompatible con Firebase/GMS compilado con Kotlin 2.4.0.
buildscript {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Garantiza -Xskip-metadata-version-check en todos los subproyectos con Kotlin Android plugin
allprojects {
    plugins.withId("org.jetbrains.kotlin.android") {
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                freeCompilerArgs.addAll(listOf("-Xskip-metadata-version-check"))
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
