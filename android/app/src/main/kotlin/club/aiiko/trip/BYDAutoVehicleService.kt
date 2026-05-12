package club.aiiko.trip

import android.content.Context
import android.hardware.bydauto.speed.BYDAutoSpeedDevice
import android.hardware.bydauto.speed.AbsBYDAutoSpeedListener
import android.hardware.bydauto.statistic.BYDAutoStatisticDevice
import android.hardware.bydauto.statistic.AbsBYDAutoStatisticListener
import android.hardware.bydauto.tyre.BYDAutoTyreDevice
import android.hardware.bydauto.tyre.AbsBYDAutoTyreListener
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class BYDAutoVehicleService(private val context: Context) {
    private var speedDevice: BYDAutoSpeedDevice? = null
    private var statisticDevice: BYDAutoStatisticDevice? = null
    private var tyreDevice: BYDAutoTyreDevice? = null

    private var methodChannel: MethodChannel? = null
    private var isStarted = false

    private var lastSpeed: Double = 0.0
    private var lastAccelerateDepth: Int = 0
    private var lastBrakeDepth: Int = 0
    private var lastElecPercentage: Double = 0.0
    private var lastFuelPercentage: Int = 0
    private var lastTotalMileage: Int = 0
    private var lastEVMileage: Int = 0
    private var lastTyrePressureLF: Int = 0
    private var lastTyrePressureRF: Int = 0
    private var lastTyrePressureLR: Int = 0
    private var lastTyrePressureRR: Int = 0

    private var speedListener: AbsBYDAutoSpeedListener? = null
    private var statisticListener: AbsBYDAutoStatisticListener? = null
    private var tyreListener: AbsBYDAutoTyreListener? = null

    fun setMethodChannel(channel: MethodChannel) {
        this.methodChannel = channel
    }

    fun start() {
        if (isStarted) return
        isStarted = true

        try {
            speedDevice = BYDAutoSpeedDevice.getInstance(context)
            speedListener = object : AbsBYDAutoSpeedListener() {
                override fun onSpeedChanged(value: Double) {
                    if (value != lastSpeed) {
                        lastSpeed = value
                        sendCarData(buildCarData())
                    }
                }

                override fun onAccelerateDeepnessChanged(value: Int) {
                    if (value != lastAccelerateDepth) {
                        lastAccelerateDepth = value
                        sendCarData(buildCarData())
                    }
                }

                override fun onBrakeDeepnessChanged(value: Int) {
                    if (value != lastBrakeDepth) {
                        lastBrakeDepth = value
                        sendCarData(buildCarData())
                    }
                }
            }
            speedDevice?.registerListener(speedListener)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        try {
            statisticDevice = BYDAutoStatisticDevice.getInstance(context)
            statisticListener = object : AbsBYDAutoStatisticListener() {
                override fun onElecPercentageChanged(value: Double) {
                    if (value != lastElecPercentage) {
                        lastElecPercentage = value
                        sendCarData(buildCarData())
                    }
                }

                override fun onFuelPercentageChanged(value: Int) {
                    if (value != lastFuelPercentage) {
                        lastFuelPercentage = value
                        sendCarData(buildCarData())
                    }
                }

                override fun onTotalMileageValueChanged(value: Int) {
                    if (value != lastTotalMileage) {
                        lastTotalMileage = value
                        sendCarData(buildCarData())
                    }
                }

                override fun onEVMileageValueChanged(value: Int) {
                    if (value != lastEVMileage) {
                        lastEVMileage = value
                        sendCarData(buildCarData())
                    }
                }
            }
            statisticDevice?.registerListener(statisticListener)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        try {
            tyreDevice = BYDAutoTyreDevice.getInstance(context)
            tyreListener = object : AbsBYDAutoTyreListener() {
                override fun onTyrePressureValueChanged(area: Int, value: Int) {
                    val changed = when (area) {
                        0 -> {
                            if (value != lastTyrePressureLF) {
                                lastTyrePressureLF = value
                                true
                            } else false
                        }
                        1 -> {
                            if (value != lastTyrePressureRF) {
                                lastTyrePressureRF = value
                                true
                            } else false
                        }
                        2 -> {
                            if (value != lastTyrePressureLR) {
                                lastTyrePressureLR = value
                                true
                            } else false
                        }
                        3 -> {
                            if (value != lastTyrePressureRR) {
                                lastTyrePressureRR = value
                                true
                            } else false
                        }
                        else -> false
                    }
                    if (changed) {
                        sendCarData(buildCarData())
                    }
                }
            }
            tyreDevice?.registerListener(tyreListener)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun stop() {
        if (!isStarted) return
        isStarted = false

        try {
            speedListener?.let { speedDevice?.unregisterListener(it) }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        try {
            statisticListener?.let { statisticDevice?.unregisterListener(it) }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        try {
            tyreListener?.let { tyreDevice?.unregisterListener(it) }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun buildCarData(): Map<String, Any?> {
        return mapOf(
            "speed" to lastSpeed,
            "elecPercentage" to lastElecPercentage,
            "fuelPercentage" to lastFuelPercentage,
            "accelerateDepth" to lastAccelerateDepth,
            "brakeDepth" to lastBrakeDepth,
            "totalMileage" to lastTotalMileage,
            "evMileage" to lastEVMileage,
            "tyrePressure" to mapOf(
                "leftFront" to lastTyrePressureLF,
                "rightFront" to lastTyrePressureRF,
                "leftRear" to lastTyrePressureLR,
                "rightRear" to lastTyrePressureRR
            ),
            "timestamp" to System.currentTimeMillis()
        )
    }

    private fun sendCarData(data: Map<String, Any?>) {
        try {
            val jsonString = JSONObject(data).toString()
            methodChannel?.invokeMethod("onCarDataChanged", jsonString)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun requestCarData() {
        sendCarData(buildCarData())
    }
}
