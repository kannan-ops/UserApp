allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
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

subprojects {
    val configureAndroid = {
        val androidExtension = project.extensions.findByName("android")
        if (androidExtension != null) {
            val extensionClass = androidExtension.javaClass
            try {
                val getNamespaceMethod = extensionClass.getMethod("getNamespace")
                val currentNamespace = getNamespaceMethod.invoke(androidExtension) as? String
                if (currentNamespace.isNullOrEmpty()) {
                    val setNamespaceMethod = extensionClass.getMethod("setNamespace", String::class.java)
                    
                    var manifestPackage: String? = null
                    val manifestFile = project.file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        try {
                            val parser = javax.xml.parsers.DocumentBuilderFactory.newInstance().newDocumentBuilder()
                            val document = parser.parse(manifestFile)
                            manifestPackage = document.documentElement.getAttribute("package")
                        } catch (e: Exception) {
                            // ignore XML parsing errors
                        }
                    }
                    
                    val computedNamespace = if (!manifestPackage.isNullOrEmpty()) {
                        manifestPackage
                    } else {
                        "com.example.${project.name.replace("-", "_").replace(".", "_")}"
                    }
                    setNamespaceMethod.invoke(androidExtension, computedNamespace)
                    logger.quiet("Injected namespace '$computedNamespace' for subproject :${project.name}")
                }
            } catch (e: Exception) {
                logger.warn("Failed to inject namespace for :${project.name}: ${e.message}")
            }
        }
    }

    project.plugins.withId("com.android.application") {
        configureAndroid()
    }
    project.plugins.withId("com.android.library") {
        configureAndroid()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
