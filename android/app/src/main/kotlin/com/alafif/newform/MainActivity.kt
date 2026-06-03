package com.alafif.newform

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.alafif.newform/app_launcher"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchJeebPayment" -> {
                    val posNumber = call.argument<String>("posNumber") ?: "573157"
                    val amount = call.argument<String>("amount") ?: "0"
                    val orderId = call.argument<String>("orderId") ?: ""
                    
                    try {
                        // بناء URI بصيغة deep link الصحيحة: jeeb://payment?pos_number=XXXXXX&amount=YYYY
                        val uri = Uri.parse("jeeb://payment?pos_number=$posNumber&amount=$amount&order_id=$orderId")
                        
                        // Intent ACTION_VIEW مع تحديد الحزمة مباشرة
                        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                            `package` = "com.ahd.jaib"
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        // إذا فشل ACTION_VIEW، نجرب getLaunchIntentForPackage كبديل
                        try {
                            val fallbackIntent = packageManager.getLaunchIntentForPackage("com.ahd.jaib")
                            if (fallbackIntent != null) {
                                fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(fallbackIntent)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } catch (e2: Exception) {
                            result.success(false)
                        }
                    }
                }
                "launchAppByPackage" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val uriStr = call.argument<String>("uri") ?: ""
                    
                    if (packageName.isEmpty()) {
                        result.error("INVALID_ARG", "packageName is required", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        if (uriStr.isNotEmpty()) {
                            // Use ACTION_VIEW with specific URI
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uriStr)).apply {
                                `package` = packageName
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            // Fall back to launcher intent
                            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                            if (launchIntent != null) {
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(launchIntent)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
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
