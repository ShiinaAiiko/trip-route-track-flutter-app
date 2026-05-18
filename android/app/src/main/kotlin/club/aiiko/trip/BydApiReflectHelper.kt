package club.aiiko.trip

import android.hardware.bydauto.AbsBYDAutoDevice
import android.util.Log

object BydApiReflectHelper {
    private const val TAG = "BydApiReflectHelper"

    fun get(device: AbsBYDAutoDevice?, deviceType: Int, featureId: Int): Int {
        Log.d(TAG, "[BYD-API] get() called - deviceType: $deviceType, featureId: $featureId")
        if (device == null) {
            Log.e(TAG, "[BYD-API] get() failed: device is null")
            return 0
        }
        try {
            val clz = Class.forName("android.hardware.bydauto.AbsBYDAutoDevice")
            val method = clz.getDeclaredMethod("get", Int::class.javaPrimitiveType, Int::class.javaPrimitiveType)
            method.isAccessible = true
            val result = method.invoke(device, deviceType, featureId) as Int
            Log.d(TAG, "[BYD-API] get() success - featureId: $featureId -> $result")
            return result
        } catch (e: ClassNotFoundException) {
            Log.e(TAG, "[BYD-API] get() failed: ClassNotFoundException - ${e.message}")
        } catch (e: NoSuchMethodException) {
            Log.e(TAG, "[BYD-API] get() failed: NoSuchMethodException - ${e.message}")
        } catch (e: IllegalAccessException) {
            Log.e(TAG, "[BYD-API] get() failed: IllegalAccessException - ${e.message}")
        } catch (e: java.lang.reflect.InvocationTargetException) {
            Log.e(TAG, "[BYD-API] get() failed: InvocationTargetException - ${e.message}")
            val cause = e.cause
            if (cause != null) {
                Log.e(TAG, "[BYD-API] get() cause: ${cause.javaClass.simpleName} - ${cause.message}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "[BYD-API] get() failed: ${e.javaClass.simpleName} - ${e.message}", e)
        }
        return 0
    }

    // 新增：获取 Double 类型数据
    fun getDouble(device: AbsBYDAutoDevice?, deviceType: Int, featureId: Int): Double {
        Log.d(TAG, "[BYD-API] getDouble() called - deviceType: $deviceType, featureId: $featureId")
        if (device == null) {
            Log.e(TAG, "[BYD-API] getDouble() failed: device is null")
            return 0.0
        }
        try {
            val clz = Class.forName("android.hardware.bydauto.AbsBYDAutoDevice")
            val method = clz.getDeclaredMethod("get", Int::class.javaPrimitiveType, Int::class.javaPrimitiveType)
            method.isAccessible = true
            val result = method.invoke(device, deviceType, featureId)
            Log.d(TAG, "[BYD-API] getDouble() success - featureId: $featureId -> $result")
            return when (result) {
                is Double -> result
                is Float -> result.toDouble()
                is Int -> result.toDouble()
                else -> result.toString().toDoubleOrNull() ?: 0.0
            }
        } catch (e: ClassNotFoundException) {
            Log.e(TAG, "[BYD-API] getDouble() failed: ClassNotFoundException - ${e.message}")
        } catch (e: NoSuchMethodException) {
            Log.e(TAG, "[BYD-API] getDouble() failed: NoSuchMethodException - ${e.message}")
        } catch (e: IllegalAccessException) {
            Log.e(TAG, "[BYD-API] getDouble() failed: IllegalAccessException - ${e.message}")
        } catch (e: java.lang.reflect.InvocationTargetException) {
            Log.e(TAG, "[BYD-API] getDouble() failed: InvocationTargetException - ${e.message}")
            val cause = e.cause
            if (cause != null) {
                Log.e(TAG, "[BYD-API] getDouble() cause: ${cause.javaClass.simpleName} - ${cause.message}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "[BYD-API] getDouble() failed: ${e.javaClass.simpleName} - ${e.message}", e)
        }
        return 0.0
    }

    fun invokeMethod(obj: Any?, methodName: String, vararg args: Any): Any? {
        Log.d(TAG, "[BYD-API] invokeMethod() called - methodName: $methodName, argsCount: ${args.size}")
        if (obj == null) {
            Log.e(TAG, "[BYD-API] invokeMethod() failed: obj is null")
            return null
        }
        try {
            val clz = obj.javaClass
            val parameterTypes = args.map { it.javaClass }.toTypedArray()
            val method = clz.getDeclaredMethod(methodName, *parameterTypes)
            method.isAccessible = true
            val result = method.invoke(obj, *args)
            Log.d(TAG, "[BYD-API] invokeMethod($methodName) success")
            return result
        } catch (e: ClassNotFoundException) {
            Log.e(TAG, "[BYD-API] invokeMethod() failed: ClassNotFoundException - ${e.message}")
        } catch (e: NoSuchMethodException) {
            Log.e(TAG, "[BYD-API] invokeMethod() failed: NoSuchMethodException - ${e.message}")
        } catch (e: IllegalAccessException) {
            Log.e(TAG, "[BYD-API] invokeMethod() failed: IllegalAccessException - ${e.message}")
        } catch (e: java.lang.reflect.InvocationTargetException) {
            Log.e(TAG, "[BYD-API] invokeMethod() failed: InvocationTargetException - ${e.message}")
            val cause = e.cause
            if (cause != null) {
                Log.e(TAG, "[BYD-API] invokeMethod() cause: ${cause.javaClass.simpleName} - ${cause.message}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "[BYD-API] invokeMethod($methodName) failed: ${e.javaClass.simpleName} - ${e.message}", e)
        }
        return null
    }

    fun invokeMethodNoArgs(obj: Any?, methodName: String): Any? {
        Log.d(TAG, "[BYD-API] invokeMethodNoArgs() called - methodName: $methodName")
        if (obj == null) {
            Log.e(TAG, "[BYD-API] invokeMethodNoArgs() failed: obj is null")
            return null
        }
        try {
            val clz = obj.javaClass
            val method = clz.getDeclaredMethod(methodName)
            method.isAccessible = true
            val result = method.invoke(obj)
            Log.d(TAG, "[BYD-API] invokeMethodNoArgs($methodName) success")
            return result
        } catch (e: ClassNotFoundException) {
            Log.e(TAG, "[BYD-API] invokeMethodNoArgs() failed: ClassNotFoundException - ${e.message}")
        } catch (e: NoSuchMethodException) {
            Log.e(TAG, "[BYD-API] invokeMethodNoArgs() failed: NoSuchMethodException - ${e.message}")
        } catch (e: IllegalAccessException) {
            Log.e(TAG, "[BYD-API] invokeMethodNoArgs() failed: IllegalAccessException - ${e.message}")
        } catch (e: java.lang.reflect.InvocationTargetException) {
            Log.e(TAG, "[BYD-API] invokeMethodNoArgs() failed: InvocationTargetException - ${e.message}")
            val cause = e.cause
            if (cause != null) {
                Log.e(TAG, "[BYD-API] invokeMethodNoArgs() cause: ${cause.javaClass.simpleName} - ${cause.message}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "[BYD-API] invokeMethodNoArgs($methodName) failed: ${e.javaClass.simpleName} - ${e.message}", e)
        }
        return null
    }
}
