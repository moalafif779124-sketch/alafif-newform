package com.alafif.newform

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.alafif.newform/app_launcher"
    private val JEEB_PACKAGE = "com.ahd.jaib"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchJeebPayment" -> {
                    val posNumber = call.argument<String>("posNumber") ?: "573157"
                    val amount = call.argument<String>("amount") ?: "0"
                    val orderId = call.argument<String>("orderId") ?: ""
                    
                    val success = tryAllJeebIntents(posNumber, amount, orderId)
                    result.success(success)
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
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uriStr)).apply {
                                `package` = packageName
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
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

    /** يجرب كل الصيغ الممكنة لفتح شاشة الدفع في محفظة جيب */
    private fun tryAllJeebIntents(posNumber: String, amount: String, orderId: String): Boolean {
        // ===== 1. جرب ACTION_VIEW مع كل الـ schemes والـ paths الممكنة =====
        val schemes = listOf("jeeb", "jaib", "pay", "wallet")
        val paths = listOf("/payment", "/pay", "/purchase", "/pos", "/scan", "/qr", "")
        val paramKeys = listOf("pos_number", "pos", "merchant_id", "terminal_id", "store_id", "terminal")
        
        for (scheme in schemes) {
            for (path in paths) {
                for (paramKey in paramKeys) {
                    try {
                        // حاول بكل combination
                        val queryParams = "$paramKey=$posNumber&amount=$amount"
                        val uriStr = "$scheme:$path?$queryParams"
                        val uri = Uri.parse(uriStr)
                        
                        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                            `package` = JEEB_PACKAGE
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        }
                        startActivity(intent)
                        // إذا وصلنا هنا يعني نجح
                        android.util.Log.d("JeebIntent", "✅ SUCCESS: $uriStr")
                        return true
                    } catch (e: Exception) {
                        android.util.Log.d("JeebIntent", "❌ FAILED: $scheme:$path?$paramKey=... : $e")
                    }
                }
            }
        }

        // ===== 2. جرب getLaunchIntentForPackage مع extras =====
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(JEEB_PACKAGE)
            if (launchIntent != null) {
                // جرب وضع pos_number في extras بعدة أسماء
                val extraKeys = listOf(
                    "pos_number", "pos", "merchant_id", "terminal_id",
                    "store_id", "terminal", "extra_pos_number", "extra_pos"
                )
                for (extraKey in extraKeys) {
                    try {
                        val intent = launchIntent.cloneFilter() as Intent
                        intent.putExtra(extraKey, posNumber)
                        intent.putExtra("amount", amount)
                        intent.putExtra("order_id", orderId)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        android.util.Log.d("JeebIntent", "✅ SUCCESS (extras): $extraKey=$posNumber")
                        return true
                    } catch (e: Exception) {
                        android.util.Log.d("JeebIntent", "❌ FAILED (extras): $extraKey")
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.d("JeebIntent", "❌ FAILED (launchIntent): $e")
        }

        // ===== 3. جرب ACTION_MAIN بدلاً من ACTION_VIEW =====
        try {
            val mainIntent = Intent(Intent.ACTION_MAIN).apply {
                `package` = JEEB_PACKAGE
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                // جرب صيغ data مختلفة
                data = Uri.parse("jeeb://payment?pos_number=$posNumber")
            }
            startActivity(mainIntent)
            return true
        } catch (e: Exception) { }

        // ===== 4. فشل كل شيء → افتح التطبيق فقط عالاقل =====
        try {
            val fallbackIntent = packageManager.getLaunchIntentForPackage(JEEB_PACKAGE)
            if (fallbackIntent != null) {
                fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(fallbackIntent)
                return true
            }
        } catch (e: Exception) { }

        return false
    }
}
