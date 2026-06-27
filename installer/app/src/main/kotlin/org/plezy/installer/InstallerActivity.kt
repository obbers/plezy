package org.plezy.installer

import android.app.Activity
import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import androidx.core.content.FileProvider
import java.io.File

class InstallerActivity : Activity() {

    companion object {
        private const val KEY_DOWNLOAD_ID = "download_id"
    }

    private var downloadId = -1L

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
            if (id == downloadId) {
                triggerInstall(id)
                finish()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState != null) {
            downloadId = savedInstanceState.getLong(KEY_DOWNLOAD_ID, -1L)
        }
        // Register receiver before enqueuing to avoid lost-broadcast window
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                receiver,
                IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE),
                RECEIVER_EXPORTED,
            )
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE))
        }
        if (downloadId == -1L) {
            downloadId = enqueueDownload(apkUrlForAbi(Build.SUPPORTED_ABIS[0]))
        }
        // Activity stays alive (invisible) while download progresses.
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putLong(KEY_DOWNLOAD_ID, downloadId)
    }

    private fun enqueueDownload(url: String): Long {
        val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle("Downloading Plezy")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, "plezy.apk")
        return dm.enqueue(request)
    }

    private fun triggerInstall(id: Long) {
        val dm = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        dm.query(DownloadManager.Query().setFilterById(id)).use { cursor ->
            if (cursor.moveToFirst()) {
                val statusIdx = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)
                if (cursor.getInt(statusIdx) == DownloadManager.STATUS_SUCCESSFUL) {
                    val file = File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "plezy.apk")
                    val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                    startActivity(
                        Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                            data = uri
                            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                    )
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try { unregisterReceiver(receiver) } catch (_: Exception) {}
    }
}
