package com.codemates.auto_spare_hub

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.codemates.auto_spare_hub/version"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getAppVersion") {
                try {
                    val packageInfo = packageManager.getPackageInfo(packageName, 0)
                    val versionName = packageInfo.versionName ?: "1.0.0"
                    val versionCode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                        packageInfo.longVersionCode.toString()
                    } else {
                        @Suppress("DEPRECATION")
                        packageInfo.versionCode.toString()
                    }
                    result.success(mapOf("version" to versionName, "buildNumber" to versionCode))
                } catch (e: Exception) {
                    result.success(mapOf("version" to "1.0.0", "buildNumber" to "1"))
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
