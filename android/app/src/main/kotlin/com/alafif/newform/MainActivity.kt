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
                        val queryParams = "$paramKey=$posNumber&amount=$amount"
                        val uriStr = "$scheme:$path?$queryParams"
                        val uri = Uri.parse(uriStr)
                        
                        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                            `package` = JEEB_PACKAGE
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        }
                        startActivity(intent)
                        android.util.Log.d("JeebIntent", "✅ SUCCESS: $uriStr")
                        return true
                    } catch (e: Exception) {
                        android.util.Log.d("JeebIntent", "❌ FAILED (scheme): $scheme:$path?... ")
                    }
                }
            }
        }

        // ===== 2. جرب ACTION_VIEW بدون package (Android يختار التطبيق) =====
        for (scheme in schemes) {
            for (path in paths) {
                try {
                    val uriStr = "$scheme:$path?pos_number=$posNumber&amount=$amount"
                    val uri = Uri.parse(uriStr)
                    val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    // تحقق إذا أي تطبيق يستطيع معالجة هذا الـ intent
                    if (intent.resolveActivity(packageManager) != null ||
                        packageManager.queryIntentActivities(intent, 0).isNotEmpty()) {
                        startActivity(intent)
                        android.util.Log.d("JeebIntent", "✅ SUCCESS (no pkg): $uriStr")
                        return true
                    }
                } catch (e: Exception) { }
            }
        }

        // ===== 3. جرب https://jeeb.io/... (ربما التطبيق يستخدم Android App Links) =====
        val httpPaths = listOf(
            "https://jeeb.io/payment?pos_number=$posNumber&amount=$amount",
            "https://jeeb.io/pay?pos_number=$posNumber&amount=$amount",
            "https://jeeb.io/pos?pos_number=$posNumber&amount=$amount",
            "https://www.jeeb.io/payment?pos_number=$posNumber&amount=$amount"
        )
        for (httpUrl in httpPaths) {
            try {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(httpUrl)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (intent.resolveActivity(packageManager) != null ||
                    packageManager.queryIntentActivities(intent, 0).isNotEmpty()) {
                    startActivity(intent)
                    android.util.Log.d("JeebIntent", "✅ SUCCESS (http): $httpUrl")
                    return true
                }
            } catch (e: Exception) { }
        }

        // ===== 4. جرب getLaunchIntentForPackage مع extras =====
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(JEEB_PACKAGE)
            if (launchIntent != null) {
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
                    } catch (e: Exception) { }
                }
            }
        } catch (e: Exception) { }

        // ===== 5. اطبع كل Activities التطبيق للتشخيص =====
        try {
            val pi = packageManager.getPackageInfo(JEEB_PACKAGE, PackageManager.GET_ACTIVITIES)
            if (pi.activities != null) {
                android.util.Log.d("JeebIntent", "=== Jeeb App Activities ===")
                for (activity in pi.activities) {
                    android.util.Log.d("JeebIntent", "  Activity: ${activity.name} exported=${activity.exported}")
                    // جرب فتح كل Activity مصدرة
                    if (activity.exported) {
                        try {
                            val intent = Intent().apply {
                                setClassName(JEEB_PACKAGE, activity.name)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                putExtra("pos_number", posNumber)
                                putExtra("amount", amount)
                            }
                            startActivity(intent)
                            android.util.Log.d("JeebIntent", "✅ SUCCESS (activity): ${activity.name}")
                            return true
                        } catch (e: Exception) { }
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.d("JeebIntent", "❌ Could not read package info: $e")
        }

        // ===== 6. فشل كل شيء → افتح التطبيق فقط عالاقل =====
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
