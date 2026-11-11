package space.freelan.app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

// FCM can start the process without ever creating MainActivity.
class FreelanApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(
                "freelan_updates", "Freelan Space notifications", NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Account updates and messages from Freelan Space"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
