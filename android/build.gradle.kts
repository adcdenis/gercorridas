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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Tasks utilitárias para rodar o app no Android via Flutter
tasks.register<Exec>("runAndroid") {
    group = "run"
    description = "Inicia um emulador/dispositivo e roda o app no Android (debug)"
    // Caminho relativo do módulo Android até o script na raiz do projeto
    commandLine("powershell", "-ExecutionPolicy", "Bypass", "-File", "../scripts/run_android.ps1")
}

tasks.register<Exec>("runAndroidRelease") {
    group = "run"
    description = "Roda o app no Android (release)"
    commandLine("powershell", "-ExecutionPolicy", "Bypass", "-File", "../scripts/run_android.ps1", "-Release")
}
