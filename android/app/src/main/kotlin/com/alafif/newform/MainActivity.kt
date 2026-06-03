package com.alafif.newform

import android.content.Intent
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.alafif.newform/app_launcher"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchAppByPackage" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    if (packageName.isEmpty()) {
                        result.error("INVALID_ARG", "packageName is required", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                        if (launchIntent != null) {
                            // إضافة parameters للدفع إذا وجدت
                            launchIntent.putExtra("pos_number", call.argument<String>("posNumber") ?: "573157")
                            launchIntent.putExtra("amount", call.argument<String>("amount") ?: "0")
                            launchIntent.putExtra("order_id", call.argument<String>("orderId") ?: "")
                            startActivity(launchIntent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "isAppInstalled" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    if (packageName.isEmpty()) {
                        result.error("INVALID_ARG", "packageName is required", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        packageManager.getPackageInfo(packageName, 0)
                        result.success(true)
                    } catch (e: PackageManager.NameNotFoundException) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
