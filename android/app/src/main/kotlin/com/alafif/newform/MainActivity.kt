package com.alafif.newform

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
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
                "diagnoseJeebApp" -> {
                    val info = diagnoseJeebApp()
                    result.success(info)
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

    /** تشخيص تطبيق جيب: قراءة كل الأنشطة والمقاصد */
    private fun diagnoseJeebApp(): String {
        val sb = StringBuilder()
        try {
            val flags = PackageManager.GET_ACTIVITIES or PackageManager.GET_RECEIVERS or PackageManager.GET_SERVICES
            val pi = packageManager.getPackageInfo(JEEB_PACKAGE, flags)
            
            // تطبيق مثبت
            sb.append("✅ Jeeb app installed: ${pi.versionName}")
            
            // الأنشطة (Activities)
            val activities = pi.activities
            if (activities != null) {
                sb.append("\n\n=== Activities (${activities.size}) ===")
                for (a in activities) {
                    sb.append("\n• ${a.name} exported=${a.exported}")
                }
            }
            
            // المستقبلات (Receivers)
            val receivers = pi.receivers
            if (receivers != null) {
                sb.append("\n\n=== Receivers (${receivers.size}) ===")
                for (r in receivers) {
                    sb.append("\n• ${r.name} exported=${r.exported}")
                }
            }
            
            // الخدمات (Services)
            val services = pi.services
            if (services != null) {
                sb.append("\n\n=== Services (${services.size}) ===")
                for (s in services) {
                    sb.append("\n• ${s.name} exported=${s.exported}")
                }
            }
            
            // محاولة فتح الأنشطة المصدرة
            if (pi.activities != null) {
                var triedAny = false
                for (a in pi.activities) {
                    if (a.exported && !a.name.contains("launcher", true) && !a.name.contains("splash", true) && !a.name.contains("main", true)) {
                        triedAny = true
                        try {
                            val intent = Intent().apply {
                                setClassName(JEEB_PACKAGE, a.name)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                putExtra("pos_number", "573157")
                                putExtra("amount", "1000")
                            }
                            startActivity(intent)
                            sb.append("\n\n✅ OPENED: ${a.name}")
                            return sb.toString() // نجح
                        } catch (e: Exception) {
                            sb.append("\n❌ Cannot open ${a.name}: ${e.message?.take(50)}")
                        }
                    }
                }
                if (!triedAny) {
                    sb.append("\n\n⚠️ No exported non-launcher activities found")
                }
            }
            
        } catch (e: Exception) {
            sb.append("\n❌ Diagnosis error: ${e.message}")
        }
        return sb.toString()
    }

    /** يجرب كل الصيغ الممكنة لفتح شاشة الدفع في محفظة جيب */
    private fun tryAllJeebIntents(posNumber: String, amount: String, orderId: String): Boolean {
        // ===== 1. الأفضل: جرب https://jeeb.app (هذا الـ domain اللي يسجله التطبيق) =====
        val jeebAppUrls = listOf(
            "https://jeeb.app/pay?pos_number=$posNumber&amount=$amount&order_id=$orderId",
            "https://jeeb.app/payment?pos_number=$posNumber&amount=$amount",
            "https://jeeb.app/pos?pos_number=$posNumber&amount=$amount",
            "https://jeeb.app/merchant?pos_number=$posNumber&amount=$amount",
            "https://jeeb.app/$posNumber/pay?amount=$amount",
            "https://jeeb.app/pay/$posNumber/$amount",
            "https://jeeb.app/payment/$posNumber/$amount",
            "https://www.jeeb.app/pay?pos_number=$posNumber&amount=$amount"
        )
        for (url in jeebAppUrls) {
            try {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                // تحقق إذا التطبيق يقدر يعالج هذا الرابط
                if (intent.resolveActivity(packageManager) != null ||
                    packageManager.queryIntentActivities(intent, 0).isNotEmpty()) {
                    startActivity(intent)
                    android.util.Log.d("JeebIntent", "✅ jeeb.app: $url")
                    return true
                }
                // جرب بدون resolve (في حال التطبيق ما يظهر في query)
                startActivity(intent)
                android.util.Log.d("JeebIntent", "✅ jeeb.app (direct): $url")
                return true
            } catch (e: Exception) { }
        }

        // ===== 2. جرب jeeb:// (الـ scheme الأصلي للتطبيق) =====
        val schemes = listOf("jeeb")
        val paths = listOf("/payment", "/pay", "/purchase", "/pos", "/scan", "/qrcode", "/merchant", "/terminal", "")
        val paramKeys = listOf("pos_number", "pos", "merchant_id", "terminal_id", "store_id", "terminal", "m_id", "t_id")
        
        // مع package
        for (scheme in allSchemes) {
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
                        android.util.Log.d("JeebIntent", "✅ PACKAGE: $uriStr")
                        return true
                    } catch (e: Exception) { }
                }
            }
        }
        
        // بدون package
        for (scheme in allSchemes) {
            for (path in paths) {
                try {
                    val uriStr = "$scheme:$path?pos_number=$posNumber&amount=$amount"
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uriStr)).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    if (intent.resolveActivity(packageManager) != null) {
                        startActivity(intent)
                        android.util.Log.d("JeebIntent", "✅ NO_PKG: $uriStr")
                        return true
                    }
                } catch (e: Exception) { }
            }
        }

        // ===== 2. جرب https://jeeb.io (App Links) =====
        val httpUrls = listOf(
            "https://jeeb.io/payment?pos_number=$posNumber&amount=$amount",
            "https://jeeb.io/pay?pos_number=$posNumber&amount=$amount",
            "https://jeeb.io/pos?pos_number=$posNumber&amount=$amount",
            "https://jeeb.io/qr?pos_number=$posNumber&amount=$amount",
            "https://jeeb.io/merchant?pos_number=$posNumber&amount=$amount",
            "https://www.jeeb.io/payment?pos_number=$posNumber&amount=$amount",
            "https://pay.jeeb.io?pos_number=$posNumber&amount=$amount",
            "https://app.jeeb.io/payment?pos_number=$posNumber&amount=$amount"
        )
        for (url in httpUrls) {
            try {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    android.util.Log.d("JeebIntent", "✅ HTTP: $url")
                    return true
                }
            } catch (e: Exception) { }
        }

        // ===== 3. جرب ACTION_SEND =====
        try {
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                `package` = JEEB_PACKAGE
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, "pos_number=$posNumber&amount=$amount")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(sendIntent)
            return true
        } catch (e: Exception) { }

        // ===== 4. جرب http:// بدلاً من https:// =====
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("http://jeeb.io/payment?pos_number=$posNumber&amount=$amount")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }
        } catch (e: Exception) { }

        // ===== 5. افتح التطبيق على الأقل + سجل التشخيص =====
        try {
            val fallbackIntent = packageManager.getLaunchIntentForPackage(JEEB_PACKAGE)
            if (fallbackIntent != null) {
                fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(fallbackIntent)
                
                // اطبع التشخيص في Logcat
                android.util.Log.d("JeebIntent", "=== DIAGNOSTIC ===")
                try {
                    val pi = packageManager.getPackageInfo(JEEB_PACKAGE, PackageManager.GET_ACTIVITIES)
                    if (pi.activities != null) {
                        for (a in pi.activities) {
                            android.util.Log.d("JeebIntent", "Activity: ${a.name} exported=${a.exported}")
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.d("JeebIntent", "Diagnosis failed: $e")
                }
            }
            return false
        } catch (e: Exception) {
            return false
        }
    }
}
