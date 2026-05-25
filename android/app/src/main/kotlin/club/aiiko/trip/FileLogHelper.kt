package club.aiiko.trip

import android.content.Context
import android.os.Environment
import android.util.Log
import java.io.*
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.Executors

object FileLogHelper {
    private const val LOG_DIR = "Download/log"
    private const val LOG_FILE_PREFIX = "app_native_log_"
    private const val MAX_LOG_SIZE = 5 * 1024 * 1024
    private const val MAX_LOG_FILES = 5

    private var logFile: File? = null
    private val logQueue = ConcurrentLinkedQueue<String>()
    private val executor = Executors.newSingleThreadExecutor()
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.getDefault())
    private var cleanupCounter = 0
    private const val CLEANUP_INTERVAL = 100

    val logFilePath: String?
        get() = logFile?.absolutePath

    fun init(context: Context) {
        try {
            val logDir = File(Environment.getExternalStorageDirectory(), LOG_DIR)
            if (!logDir.exists()) {
                logDir.mkdirs()
            }

            cleanupOldLogs(logDir)

            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            logFile = File(logDir, "${LOG_FILE_PREFIX}${timestamp}.txt")

            logFile?.writeText("=== Android Native Log Started at ${Date()} ===\n\n")

            writeLogDirect("FileLogHelper", "Log file initialized: ${logFile?.absolutePath}")

            cleanupOldLogs(logDir)

            startLogcatCapture()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startLogcatCapture() {
        Thread(Runnable {
            try {
                val process = Runtime.getRuntime().exec("logcat -v time")
                val reader = BufferedReader(InputStreamReader(process.inputStream))
                var line: String?

                while (reader.readLine().also { line = it } != null) {
                    line?.let {
                        executor.execute {
                            try {
                                logFile?.appendText("[LOGCAT] $it\n")
                            } catch (e: Exception) {
                                // 忽略写入错误
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }).start()
    }

    fun log(tag: String, message: String) {
        Log.d(tag, message)

        val timestamp = dateFormat.format(Date())
        val logLine = "[$timestamp] [$tag] $message"
        logQueue.add(logLine)
        flushLogs()
    }

    fun logError(tag: String, message: String, throwable: Throwable?) {
        Log.e(tag, message, throwable)

        val timestamp = dateFormat.format(Date())
        val logLine = "[$timestamp] [$tag] ERROR: $message"
        logQueue.add(logLine)

        throwable?.let {
            val sw = StringWriter()
            it.printStackTrace(PrintWriter(sw))
            logQueue.add("[$timestamp] [$tag] StackTrace: ${sw.toString()}")
        }

        flushLogs()
    }

    fun logException(tag: String, message: String, exception: Exception?) {
        Log.e(tag, message, exception)

        val timestamp = dateFormat.format(Date())
        val logLine = "[$timestamp] [$tag] EXCEPTION: $message"
        logQueue.add(logLine)

        exception?.let {
            val sw = StringWriter()
            it.printStackTrace(PrintWriter(sw))
            logQueue.add("[$timestamp] [$tag] Exception StackTrace: ${sw.toString()}")
        }

        flushLogs()
    }

    private fun flushLogs() {
        executor.execute {
            try {
                val file = logFile ?: return@execute
                val content = StringBuilder()

                while (logQueue.isNotEmpty()) {
                    logQueue.poll()?.let { content.append(it).append("\n") }
                }

                if (content.isNotEmpty()) {
                    if (file.length() >= MAX_LOG_SIZE) {
                        rotateLogFile()
                    }
                    file.appendText(content.toString())
                }

                cleanupCounter++
                if (cleanupCounter >= CLEANUP_INTERVAL) {
                    cleanupCounter = 0
                    logFile?.parentFile?.let { cleanupOldLogs(it) }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun writeLogDirect(tag: String, message: String) {
        try {
            val file = logFile ?: return
            val timestamp = dateFormat.format(Date())
            file.appendText("[$timestamp] [$tag] $message\n")

            if (file.length() >= MAX_LOG_SIZE) {
                rotateLogFile()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun rotateLogFile() {
        try {
            val currentFile = logFile ?: return
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            val oldFile = File(currentFile.parent, "${LOG_FILE_PREFIX}old_$timestamp.txt")
            currentFile.renameTo(oldFile)

            logFile = File(currentFile.parent, "${LOG_FILE_PREFIX}${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())}.txt")
            logFile?.writeText("=== Log Rotated at ${Date()} ===\n\n")

            currentFile.parentFile?.let { cleanupOldLogs(it) }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun cleanupOldLogs(logDir: File) {
        try {
            val process = Runtime.getRuntime().exec("ls -t $logDir")
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val allFileNames = mutableListOf<String>()
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                line?.let { allFileNames.add(it) }
            }
            reader.close()

            Log.d("FileLogHelper", "cleanupOldLogs: total files in dir: ${allFileNames.size}")

            val filtered = allFileNames.filter { it.startsWith(LOG_FILE_PREFIX) && it.endsWith(".txt") }
            Log.d("FileLogHelper", "cleanupOldLogs: filtered count: ${filtered.size}")

            val logFiles = filtered.map { File(logDir, it) }
            Log.d("FileLogHelper", "cleanupOldLogs: logFiles count: ${logFiles.size}")

            if (logFiles.size > MAX_LOG_FILES) {
                val toDelete = logFiles.drop(MAX_LOG_FILES)
                Log.d("FileLogHelper", "cleanupOldLogs: deleting ${toDelete.size} files")
                toDelete.forEach {
                    Log.d("FileLogHelper", "cleanupOldLogs: deleting ${it.name}")
                    it.delete()
                }
            }
        } catch (e: Exception) {
            Log.e("FileLogHelper", "cleanupOldLogs failed", e)
            e.printStackTrace()
        }
    }
}
