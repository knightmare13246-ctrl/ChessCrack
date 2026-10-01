package org.chesscrack.app

import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "org.chesscrack.app/native"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNativeLibraryDir" -> {
                    result.success(applicationInfo.nativeLibraryDir)
                }
                "getDeviceAbi" -> {
                    val abis = Build.SUPPORTED_ABIS
                    if (abis != null && abis.isNotEmpty()) {
                        result.success(abis[0])
                    } else {
                        result.success(Build.CPU_ABI)
                    }
                }
                "setExecutable" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            val file = File(path)
                            file.setReadable(true, false)
                            file.setExecutable(true, false)
                            try {
                                val p = Runtime.getRuntime().exec(arrayOf("chmod", "755", path))
                                p.waitFor()
                            } catch (_: Exception) {}
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("CHMOD_ERROR", e.message, null)
                        }
                    } else {
                        result.error("NULL_PATH", "Path was null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
