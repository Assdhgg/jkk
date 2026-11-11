package space.freelan.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private var downloading = false
    @Suppress("DEPRECATION")
    private fun code(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
    @Suppress("DEPRECATION")
    private fun flags(): Int = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
    private fun hex(bytes: ByteArray): String = bytes.joinToString("") { "%02x".format(it.toInt() and 255) }
    @Suppress("DEPRECATION")
    private fun validSigner(installed: PackageInfo, archive: PackageInfo): Boolean {
        if (Build.VERSION.SDK_INT >= 28) {
            val old = installed.signingInfo ?: return false
            val next = archive.signingInfo ?: return false
            val current = old.apkContentsSigners.map { hex(it.toByteArray()) }.toSet()
            if (current.isEmpty()) return false
            if (old.hasMultipleSigners() || next.hasMultipleSigners()) {
                return current == next.apkContentsSigners.map { hex(it.toByteArray()) }.toSet()
            }
            return next.signingCertificateHistory.map { hex(it.toByteArray()) }.toSet().containsAll(current)
        }
        return installed.signatures?.map { hex(it.toByteArray()) }?.toSet() == archive.signatures?.map { hex(it.toByteArray()) }?.toSet() && !archive.signatures.isNullOrEmpty()
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel("freelan_updates", "Freelan Space notifications", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "Account updates and messages from Freelan Space"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "growth_circle/app_updates").setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    try {
                        val settings = if (Build.VERSION.SDK_INT >= 26) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                        }
                        startActivity(settings)
                        result.success(null)
                    } catch (_: Exception) { result.error("permission", "Unable to open notification settings.", null) }
                }
                "installedVersion" -> result.success(code(packageManager.getPackageInfo(packageName, 0)))
                "installUpdate" -> {
                    val url = call.argument<String>("url") ?: ""
                    val hash = call.argument<String>("sha256") ?: ""
                    val expected = call.argument<Number>("versionCode")?.toLong() ?: 0
                    val size = call.argument<Number>("sizeBytes")?.toLong() ?: 0
                    if (!hash.matches(Regex("[a-f0-9]{64}")) || expected <= 0 || size !in 1..209715200L) {
                        result.error("invalid_release", "Invalid release metadata.", null)
                    } else if (downloading) {
                        result.error("busy", "An update is already downloading.", null)
                    } else if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
                        try {
                            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                            result.success("permission_required")
                        } catch (_: Exception) { result.error("permission", "Open Android settings to allow app installation.", null) }
                    } else {
                        downloading = true
                        Thread {
                            val directory = File(cacheDir, "app_updates").apply { mkdirs() }
                            val temporary = File(directory, "download.part")
                            try {
                                val installed = packageManager.getPackageInfo(packageName, flags())
                                require(expected > code(installed)) { "This version is already installed." }
                                var current = URL(url)
                                var connection: HttpURLConnection? = null
                                for (redirect in 0..5) {
                                    require(current.protocol == "https" && current.userInfo == null) { "Only HTTPS downloads are allowed." }
                                    val candidate = current.openConnection() as HttpURLConnection
                                    candidate.connectTimeout = 15000
                                    candidate.readTimeout = 30000
                                    candidate.instanceFollowRedirects = false
                                    val status = candidate.responseCode
                                    if (status in listOf(301, 302, 303, 307, 308)) {
                                        val location = candidate.getHeaderField("Location")
                                        candidate.disconnect()
                                        require(location != null && redirect < 5) { "Invalid download redirect." }
                                        current = URL(current, location)
                                    } else {
                                        if (status != 200) {
                                            candidate.disconnect()
                                            error("APK download failed.")
                                        }
                                        connection = candidate
                                        break
                                    }
                                }
                                val download = requireNotNull(connection)
                                val digest = MessageDigest.getInstance("SHA-256")
                                try {
                                    var count = 0L
                                    val started = System.currentTimeMillis()
                                    download.inputStream.use { input -> temporary.outputStream().use { output ->
                                        val buffer = ByteArray(65536)
                                        while (true) {
                                            val read = input.read(buffer)
                                            if (read < 0) break
                                            count += read
                                            require(count <= size && System.currentTimeMillis() - started < 600000) { "APK download exceeded limits." }
                                            digest.update(buffer, 0, read)
                                            output.write(buffer, 0, read)
                                        }
                                    } }
                                    require(count == size && hex(digest.digest()) == hash) { "APK integrity check failed." }
                                } finally { download.disconnect() }
                                val archive = requireNotNull(packageManager.getPackageArchiveInfo(temporary.path, flags())) { "Invalid APK." }
                                require(archive.packageName == packageName && code(archive) == expected && validSigner(installed, archive)) { "APK package, version or signature does not match this app." }
                                val apk = File(directory, "$expected.apk")
                                directory.listFiles()?.filter { it.name.endsWith(".apk") }?.forEach { it.delete() }
                                require(temporary.renameTo(apk)) { "Unable to prepare APK." }
                                runOnUiThread {
                                    try {
                                        val uri = FileProvider.getUriForFile(this, "$packageName.updates", apk)
                                        startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
                                        result.success("installer_opened")
                                    } catch (_: Exception) { result.error("installer", "Unable to open Android installer.", null) }
                                    finally { downloading = false }
                                }
                            } catch (_: Exception) {
                                temporary.delete()
                                runOnUiThread { downloading = false; result.error("update_failed", "Download or verification failed. Check the connection and release signing key, then retry.", null) }
                            }
                        }.start()
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
