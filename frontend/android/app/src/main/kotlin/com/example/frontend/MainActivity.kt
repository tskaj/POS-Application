package com.example.frontend

import android.os.Bundle
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "ttp244_printer"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"printTspl" -> {
					val commands = call.argument<String>("commands") ?: ""
					try {
						// Scaffold: write TSPL commands to cache for debug and return path.
						// TODO: Replace with actual USB/serial write to TTP-244 when available.
						val file = File(cacheDir, "ttp244_${System.currentTimeMillis()}.tspl")
						file.writeText(commands)
						val map: Map<String, Any> = mapOf("path" to file.absolutePath)
						result.success(map)
					} catch (e: Exception) {
						result.error("PRINT_ERROR", e.message, null)
					}
				}
				else -> result.notImplemented()
			}
		}
	}
}
