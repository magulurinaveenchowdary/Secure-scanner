package com.securescan.securescan

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity

class AfterCallActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_after_call)

        if (!Settings.canDrawOverlays(this)) {
            val builder = AlertDialog.Builder(this)
            builder.setTitle("Overlay permission required")
            builder.setMessage("This app needs the overlay permission to show the after-call screen. Please grant it.")
            builder.setPositiveButton("Grant") { _, _ ->
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivity(intent)
            }
            builder.setNegativeButton("Cancel", null)
            builder.show()
        }

        Handler(Looper.getMainLooper()).postDelayed({
            finish()
        }, 5000)
    }
}
