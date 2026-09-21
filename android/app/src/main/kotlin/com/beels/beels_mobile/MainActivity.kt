package com.beels.beels_mobile

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.ContactsContract.CommonDataKinds.Email
import android.provider.ContactsContract.CommonDataKinds.Phone
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.activity.result.contract.ActivityResultContracts

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth:
// the BiometricPrompt API only attaches to FragmentActivity subclasses.
class MainActivity : FlutterFragmentActivity() {
    private var pendingResult: MethodChannel.Result? = null

    // Registered as a property so it exists before the activity is STARTED.
    private val pickContact =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val pending = pendingResult ?: return@registerForActivityResult
            pendingResult = null
            val uri = result.data?.data
            if (result.resultCode != Activity.RESULT_OK || uri == null) {
                pending.success(null) // cancelled
            } else {
                pending.success(readContact(uri))
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "beels/contacts")
            .setMethodCallHandler { call, result ->
                if (call.method != "pick") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingResult != null) {
                    result.error("busy", "A contact pick is already in progress.", null)
                    return@setMethodCallHandler
                }
                pendingResult = result
                try {
                    // The system picker hands back exactly the row the user
                    // chose, so no READ_CONTACTS permission is needed.
                    pickContact.launch(Intent(Intent.ACTION_PICK, Phone.CONTENT_URI))
                } catch (e: ActivityNotFoundException) {
                    pendingResult = null
                    result.error("unavailable", "No contacts app is available.", null)
                }
            }
    }

    private fun readContact(uri: Uri): Map<String, String?>? {
        val row = contentResolver.query(
            uri,
            arrayOf(Phone.DISPLAY_NAME, Phone.NUMBER, Phone.CONTACT_ID),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                Triple(cursor.getString(0), cursor.getString(1), cursor.getString(2))
            } else {
                null
            }
        } ?: return null

        val (name, phone, contactId) = row
        var email: String? = null
        if (contactId != null) {
            try {
                email = contentResolver.query(
                    Email.CONTENT_URI,
                    arrayOf(Email.ADDRESS),
                    "${Email.CONTACT_ID} = ?",
                    arrayOf(contactId),
                    null,
                )?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
            } catch (e: SecurityException) {
                // Without contacts permission the email simply stays blank.
            }
        }
        return mapOf("name" to name, "phone" to phone, "email" to email)
    }
}
