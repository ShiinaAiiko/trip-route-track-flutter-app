# Flutter 相关规则
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# GeckoView 相关规则
-keep class org.mozilla.gecko.** { *; }
-keep class org.mozilla.geckoview.** { *; }
-dontwarn org.mozilla.gecko.**
-dontwarn org.mozilla.geckoview.**

# 我们的代码库 - nyanya_webview 插件
-keep class club.aiiko.nyanya_webview.** { *; }
-keepclassmembers class club.aiiko.nyanya_webview.** { *; }

# 保留所有注解
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# 自动生成的缺失规则
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
-dontwarn java.beans.BeanInfo
-dontwarn java.beans.FeatureDescriptor
-dontwarn java.beans.IntrospectionException
-dontwarn java.beans.Introspector
-dontwarn java.beans.PropertyDescriptor
-dontwarn okhttp3.Cache
-dontwarn okhttp3.Call
-dontwarn okhttp3.ConnectionSpec
-dontwarn okhttp3.FormBody$Builder
-dontwarn okhttp3.FormBody
-dontwarn okhttp3.Interceptor$Chain
-dontwarn okhttp3.Interceptor
-dontwarn okhttp3.MediaType
-dontwarn okhttp3.MultipartBody$Builder
-dontwarn okhttp3.MultipartBody
-dontwarn okhttp3.OkHttpClient$Builder
-dontwarn okhttp3.OkHttpClient
-dontwarn okhttp3.Request$Builder
-dontwarn okhttp3.Request
-dontwarn okhttp3.RequestBody
-dontwarn okhttp3.Response
-dontwarn okhttp3.ResponseBody
-dontwarn okhttp3.internal.Version

# Tencent SDK 相关
-keep class com.tencent.** { *; }
-dontwarn com.tencent.**

# 比亚迪 BYD Auto SDK 相关
-keep class com.byd.** { *; }
-keep class com.baidu.** { *; }
-keep class bydaid.** { *; }
-dontwarn com.byd.**
-dontwarn com.baidu.**
-dontwarn bydaid.**
