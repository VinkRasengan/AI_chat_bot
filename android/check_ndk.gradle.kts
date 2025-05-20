import org.gradle.api.Project
import java.io.File

fun Project.findAvailableNdk(): String? {
    val ndkDir = File(System.getenv("ANDROID_SDK_ROOT") ?: System.getenv("ANDROID_HOME") ?: "", "ndk")
    if (ndkDir.exists() && ndkDir.isDirectory) {
        // Get all installed NDK versions and sort them by version number
        val installedVersions = ndkDir.listFiles()
            ?.filter { it.isDirectory }
            ?.sortedByDescending { it.name }
        
        // Return the highest available version, or null if none found
        return installedVersions?.firstOrNull()?.name
    }
    return null
}

// Make the function available to other build files
extra["findAvailableNdk"] = ::findAvailableNdk
