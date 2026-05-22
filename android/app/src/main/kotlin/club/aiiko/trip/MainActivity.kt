package club.aiiko.trip

import android.content.Intent
import android.content.pm.PackageManager
import android.content.ComponentName
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.tasks.Task

class MainActivity : FlutterActivity() {
    private val CHANNEL = "flutter_background"
    private val BYD_CHANNEL = "byd_vehicle"
    private val LANGUAGE_CHANNEL = "app_language"
    private val NOTIFICATION_CLICK_CHANNEL = "notification_click"
    private val FLUTTER_BRIDGE_CHANNEL = "flutter_bridge"
    private val LOG_CHANNEL = "log_service"

    private val REQUEST_CODE_BYDAUTO_PERMISSIONS = 1001
    private val INSTALL_PERMISSION_REQUEST_CODE = 1002
    private val REQUEST_CODE_GOOGLE_SIGN_IN = 1003

    private var bydVehicleService: BYDAutoVehicleService? = null
    private var bydMethodChannel: MethodChannel? = null
    private var logMethodChannel: MethodChannel? = null
    private var isBydServiceAvailable = false
    private var pendingStartCarData = false
    private var pendingApkPath: String? = null
    
    // Google Sign-In
    private lateinit var googleSignInClient: GoogleSignInClient
    private var pendingThirdPartyLoginResult: ((Map<String, Any>) -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sendLog("app", "configureFlutterEngine 被调用")
        
        // 初始化Google Sign-In
        initGoogleSignIn()
        
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "geckoView",
            GeckoViewFactory(flutterEngine.dartExecutor.binaryMessenger)
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundService" -> {
                    startBackgroundService()
                    result.success(null)
                }
                "stopBackgroundService" -> {
                    stopBackgroundService()
                    result.success(null)
                }
                "updateNotification" -> {
                    val title = call.argument<String>("taskTitle")
                    val desc = call.argument<String>("taskDesc")
                    updateNotification(title, desc)
                    result.success(null)
                }
                else -> {
                    sendLog("app", "未实现的方法调用: ${call.method}")
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LANGUAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateAppTitle" -> {
                    val title = call.argument<String>("title")
                    updateAppTitle(title)
                    result.success(null)
                }
                else -> {
                    sendLog("app", "未实现的方法调用: ${call.method}")
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CLICK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openApp" -> {
                    openApp()
                    result.success(null)
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    installApk(path)
                    result.success(null)
                }
                else -> {
                    sendLog("app", "未实现的方法调用: ${call.method}")
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLUTTER_BRIDGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    installApk(path)
                    result.success(null)
                }
                "restartApp" -> {
                    restartApp()
                    result.success(null)
                }
                "quitApp" -> {
                    quitApp()
                    result.success(null)
                }
                "thirdPartyLogin" -> {
                    val type = call.argument<String>("type")
                    handleThirdPartyLogin(type, result)
                }
                else -> {
                    sendLog("app", "未实现的方法调用 (flutter_bridge): ${call.method}")
                    result.notImplemented()
                }
            }
        }

        bydMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BYD_CHANNEL)
        bydMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startCarDataUpdates" -> {
                    if (bydVehicleService == null) {
                        try {
                            sendCarLog("开始初始化 BYDAutoVehicleService")
                            bydVehicleService = BYDAutoVehicleService(applicationContext)
                            bydVehicleService?.setMethodChannel(bydMethodChannel!!)
                            isBydServiceAvailable = true
                            sendCarLog("BYDAutoVehicleService 初始化成功")
                        } catch (e: Exception) {
                            sendCarLog("BYDAutoVehicleService 初始化失败: ${e.message}")
                            sendCarLog("异常堆栈: ${e.stackTraceToString()}")
                            isBydServiceAvailable = false
                        }
                    }
                    if (isBydServiceAvailable && bydVehicleService != null) {
                        if (bydVehicleService?.hasRequiredPermissions() == true) {
                            sendCarLog("权限检查通过，启动车机数据监听")
                            bydVehicleService?.start()
                        } else {
                            sendCarLog("权限检查失败，准备申请权限")
                            pendingStartCarData = true
                            requestBydAutoPermissions()
                        }
                    }
                    result.success(null)
                }
                "stopCarDataUpdates" -> {
                    if (isBydServiceAvailable) {
                        bydVehicleService?.stop()
                    }
                    result.success(null)
                }
                "requestCarData" -> {
                    if (isBydServiceAvailable && bydVehicleService != null) {
                        bydVehicleService?.requestCarData()
                    } else {
                        sendCarLog("BYD服务不可用，发送空数据")
                        sendEmptyCarData()
                    }
                    result.success(null)
                }
                "hasBydPermissions" -> {
                    val hasPerms = bydVehicleService?.hasRequiredPermissions() ?: false
                    sendCarLog("hasBydPermissions 返回: $hasPerms")
                    result.success(hasPerms)
                }
                "requestBydPermissions" -> {
                    requestBydAutoPermissions()
                    result.success(null)
                }
                else -> {
                    sendCarLog("未实现的方法调用: ${call.method}")
                    result.notImplemented()
                }
            }
        }

        logMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOG_CHANNEL)
        logMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun requestBydAutoPermissions() {
        sendCarLog("requestBydAutoPermissions 被调用")
        bydVehicleService?.getRequiredPermissions()?.let { permissions ->
            sendCarLog("请求权限: ${permissions.joinToString()}")
            requestPermissions(permissions, REQUEST_CODE_BYDAUTO_PERMISSIONS)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        sendCarLog("onRequestPermissionsResult 被调用")
        sendCarLog("requestCode: $requestCode")
        sendCarLog("permissions: ${permissions.joinToString()}")
        sendCarLog("grantResults: ${grantResults.joinToString()}")
        
        if (requestCode == REQUEST_CODE_BYDAUTO_PERMISSIONS) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            sendCarLog("权限是否全部授予: $allGranted")
            
            if (allGranted && pendingStartCarData) {
                sendCarLog("权限授予成功，启动车机数据监听")
                bydVehicleService?.start()
                pendingStartCarData = false
            } else if (!allGranted) {
                sendCarLog("部分权限被拒绝")
            }
        }
    }

    private fun openApp() {
        sendLog("app", "openApp 被调用")
        val intent = Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        startActivity(intent)
    }

    private fun installApk(path: String?) {
        if (path.isNullOrEmpty()) {
            sendLog("app", "installApk: path is empty")
            return
        }

        pendingApkPath = path
        sendLog("app", "installApk: preparing to install from: $path")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (!packageManager.canRequestPackageInstalls()) {
                sendLog("app", "installApk: requesting install permission")
                // 跳转到设置页面请求权限
                val intent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                ).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivityForResult(intent, INSTALL_PERMISSION_REQUEST_CODE)
                return
            }
        }

        // 有权限，直接安装
        performInstall(path)
    }

    private fun performInstall(path: String) {
        try {
            val file = java.io.File(path)
            if (!file.exists()) {
                sendLog("app", "installApk: file not found: $path")
                return
            }
            sendLog("app", "installApk: file exists, starting install")

            val intent = Intent(Intent.ACTION_VIEW).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                val uri = androidx.core.content.FileProvider.getUriForFile(
                    this@MainActivity,
                    "${packageName}.fileprovider",
                    file
                )
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            sendLog("app", "installApk: install intent sent")
        } catch (e: Exception) {
            sendLog("app", "installApk failed: ${e.message}")
            e.printStackTrace()
        }
    }

    private fun sendEmptyCarData() {
        try {
            val emptyData = mapOf(
                "speed" to 0.0,
                "elecPercentage" to 0.0,
                "fuelPercentage" to 0,
                "accelerateDepth" to 0,
                "brakeDepth" to 0,
                "totalMileage" to 0,
                "evMileage" to 0,
                "tyrePressure" to mapOf(
                    "leftFront" to 0,
                    "rightFront" to 0,
                    "leftRear" to 0,
                    "rightRear" to 0
                ),
                "timestamp" to System.currentTimeMillis()
            )
            val jsonString = JSONObject(emptyData).toString()
            bydMethodChannel?.invokeMethod("onCarDataChanged", jsonString)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startBackgroundService() {
        sendLog("background", "startBackgroundService 被调用")
        val intent = Intent(this, BackgroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopBackgroundService() {
        sendLog("background", "stopBackgroundService 被调用")
        val intent = Intent(this, BackgroundService::class.java)
        stopService(intent)
    }

    private fun updateNotification(title: String?, desc: String?) {
        sendLog("background", "updateNotification 被调用, title: $title, desc: $desc")
        if (BackgroundService.isRunning) {
            val intent = Intent(this, BackgroundService::class.java)
            intent.putExtra("action", "update")
            intent.putExtra("title", title)
            intent.putExtra("desc", desc)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        }
    }

    private fun updateAppTitle(title: String?) {
        sendLog("background", "updateAppTitle 被调用, title: $title")
        try {
            if (title.isNullOrEmpty()) return
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
                val shortcutManager = getSystemService(ShortcutManager::class.java)
                if (shortcutManager != null) {
                    val shortcutInfo = ShortcutInfo.Builder(this, "app_launcher")
                        .setShortLabel(title)
                        .setLongLabel(title)
                        .setIntent(Intent(Intent.ACTION_MAIN).apply {
                            setClass(this@MainActivity, MainActivity::class.java)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        })
                        .build()
                    shortcutManager.updateShortcuts(listOf(shortcutInfo))
                }
            }
            
            val componentName = ComponentName(this, MainActivity::class.java)
            packageManager.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            packageManager.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            
        } catch (e: Exception) {
            sendLog("app", "updateAppTitle 失败: ${e.message}")
            sendLog("app", "异常堆栈: ${e.stackTraceToString()}")
        }
    }

    private fun sendCarLog(log: String) {
        try {
            val logData = mapOf(
                "type" to "carLog",
                "message" to log
            )
            val jsonString = JSONObject(logData).toString()
            logMethodChannel?.invokeMethod("onBydLog", jsonString)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun sendLog(type: String, message: String) {
        try {
            val logData = mapOf(
                "type" to type,
                "message" to message
            )
            val jsonString = JSONObject(logData).toString()
            logMethodChannel?.invokeMethod("onLog", jsonString)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or android.view.WindowManager.LayoutParams.SOFT_INPUT_STATE_HIDDEN)
    }

    override fun onResume() {
        super.onResume()
        // 隐藏输入法，防止 App 启动或从后台返回时无故唤起输入法
        val imm = getSystemService(android.content.Context.INPUT_METHOD_SERVICE) as? android.view.inputmethod.InputMethodManager
        imm?.hideSoftInputFromWindow(window.decorView.windowToken, 0)
    }

    private fun restartApp() {
        sendLog("app", "restartApp 被调用")
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        if (intent == null) {
            sendLog("app", "restartApp 失败: intent 为空")
            return
        }
        intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP or android.content.Intent.FLAG_ACTIVITY_CLEAR_TASK)
        startActivity(intent)
        sendLog("app", "restartApp 已启动新 Activity，准备退出")
        System.exit(0)
    }

    private fun quitApp() {
        sendLog("app", "quitApp 被调用")
        android.os.Process.killProcess(android.os.Process.myPid())
    }

    // ==================== Google Sign-In ====================
    
    private fun initGoogleSignIn() {
        val clientId = BuildConfig.GOOGLE_CLIENT_ID
        val webClientId = BuildConfig.GOOGLE_WEB_CLIENT_ID
        val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
             .requestEmail()
             .requestProfile()
             .build()
        
        googleSignInClient = GoogleSignIn.getClient(this, gso)
        sendLog("app", "Google Sign-In 初始化完成, clientId=$clientId, webClientId=$webClientId")
    }
    
    private fun handleThirdPartyLogin(type: String?, result: MethodChannel.Result) {
        sendLog("app", "handleThirdPartyLogin: $type")
        
        when (type) {
            "google" -> {
                signInWithGoogle(result)
            }
            "qq" -> {
                // QQ登录预留
                sendLog("app", "QQ登录功能尚未实现")
                result.success(mapOf("success" to false, "error" to "QQ登录功能尚未实现"))
            }
            "github" -> {
                // GitHub登录预留
                sendLog("app", "GitHub登录功能尚未实现")
                result.success(mapOf("success" to false, "error" to "GitHub登录功能尚未实现"))
            }
            else -> {
                result.success(mapOf("success" to false, "error" to "不支持的登录类型: $type"))
            }
        }
    }
    
    private fun signInWithGoogle(result: MethodChannel.Result) {
        sendLog("app", "signInWithGoogle 被调用")
        
        pendingThirdPartyLoginResult = { loginResult ->
            result.success(loginResult)
        }
        
        val signInIntent = googleSignInClient.signInIntent
        startActivityForResult(signInIntent, REQUEST_CODE_GOOGLE_SIGN_IN)
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == INSTALL_PERMISSION_REQUEST_CODE) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && packageManager.canRequestPackageInstalls()) {
                sendLog("app", "installApk: permission granted")
                pendingApkPath?.let {
                    performInstall(it)
                }
            } else {
                sendLog("app", "installApk: permission denied")
            }
        } else if (requestCode == REQUEST_CODE_GOOGLE_SIGN_IN) {
            val task = GoogleSignIn.getSignedInAccountFromIntent(data)
            handleSignInResult(task)
        }
    }
    
    private fun handleSignInResult(completedTask: Task<GoogleSignInAccount>) {
        try {
            val account = completedTask.getResult(ApiException::class.java)
            
            // 获取用户信息
            val userId = account.id ?: ""
            val userName = account.displayName ?: ""
            val userEmail = account.email ?: ""
            val userAvatar = account.photoUrl?.toString() ?: ""
            val idToken = account.idToken ?: ""
            
            sendLog("app", "Google登录成功: $userEmail")
            
            val resultMap = mapOf(
                "success" to true,
                "userId" to userId,
                "userName" to userName,
                "userEmail" to userEmail,
                "userAvatar" to userAvatar,
                "idToken" to idToken,
                "accessToken" to "" // Google Sign-In主要使用idToken
            )
            
            pendingThirdPartyLoginResult?.invoke(resultMap)
            pendingThirdPartyLoginResult = null
            
        } catch (e: ApiException) {
            sendLog("app", "Google登录失败: ${e.message}")
            
            val errorMessage = e.message ?: "登录失败"
            val resultMap: Map<String, Any> = mapOf(
                "success" to false,
                "error" to errorMessage
            )
            
            pendingThirdPartyLoginResult?.invoke(resultMap)
            pendingThirdPartyLoginResult = null
        }
    }
}
