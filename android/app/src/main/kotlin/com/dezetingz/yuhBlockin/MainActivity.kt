package com.dezetingz.yuhBlockin

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Push notification channel
            val pushChannel = NotificationChannel(
                "yuh_blockin_push",
                "Yuh Blockin Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Push notifications for parking alerts"
                enableVibration(true)
                enableLights(true)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(pushChannel)
        }
    }
}
