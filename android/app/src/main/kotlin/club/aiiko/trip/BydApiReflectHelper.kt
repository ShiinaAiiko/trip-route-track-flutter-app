package club.aiiko.trip

import android.hardware.bydauto.AbsBYDAutoDevice
import android.util.Log

object BydApiReflectHelper {
    private const val TAG = "BydApiReflectHelper"

    fun get(device: AbsBYDAutoDevice?, deviceType: Int, featureId: Int): Int {
        if (device == null) {
            Log.e(TAG, "device is null")
            return 0
        }
        try {
            val clz = Class.forName("android.hardware.bydauto.AbsBYDAutoDevice")
            val method = clz.getDeclaredMethod("get", Int::class.javaPrimitiveType, Int::class.javaPrimitiveType)
            method.isAccessible = true
            val result = method.invoke(device, deviceType, featureId) as Int
            Log.d(TAG, "get feature $featureId -> $result")
            return result
        } catch (e: Exception) {
            Log.e(TAG, "get() failed: ${e.message}", e)
            return 0
        }
    }

    fun invokeMethod(obj: Any?, methodName: String, vararg args: Any): Any? {
        if (obj == null) {
            Log.e(TAG, "obj is null")
            return null
        }
        try {
            val clz = obj.javaClass
            val parameterTypes = args.map { it.javaClass }.toTypedArray()
            val method = clz.getDeclaredMethod(methodName, *parameterTypes)
            method.isAccessible = true
            return method.invoke(obj, *args)
        } catch (e: Exception) {
            Log.e(TAG, "invokeMethod($methodName) failed: ${e.message}", e)
            return null
        }
    }

    fun invokeMethodNoArgs(obj: Any?, methodName: String): Any? {
        if (obj == null) {
            Log.e(TAG, "obj is null")
            return null
        }
        try {
            val clz = obj.javaClass
            val method = clz.getDeclaredMethod(methodName)
            method.isAccessible = true
            return method.invoke(obj)
        } catch (e: Exception) {
            Log.e(TAG, "invokeMethodNoArgs($methodName) failed: ${e.message}", e)
            return null
        }
    }
}
