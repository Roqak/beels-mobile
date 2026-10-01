package com.beels.beels_mobile

import android.nfc.cardemulation.HostApduService
import android.os.Bundle

/**
 * Pure codec for the bytes the HCE service serves over ISO-DEP. Kept free of
 * android framework types so it can be unit tested.
 */
object BeelNdefCodec {
    /**
     * NDEF well-known URI record for a single URL:
     * `91 01 <payload len> 55 <URI prefix code> <URI bytes>`.
     * Header: MB|ME|SR + TNF(0x01 well-known); the payload is the 0x55 type
     * byte plus the URI.
     */
    fun buildUriRecord(url: String): ByteArray {
        val uriPayload = uriPrefixAndBytes(url)
        val body = byteArrayOf(0x55) + uriPayload // type "U" + payload
        val payloadLen = body.size
        require(payloadLen in 1..0xFF) { "URI too long for a short NDEF record" }
        return byteArrayOf(0x91.toByte(), 0x01.toByte(), payloadLen.toByte()) + body
    }

    /** 1-byte NFC "URI identifier code" prefix + the remainder as ASCII. */
    private fun uriPrefixAndBytes(url: String): ByteArray {
        // Longest prefixes first so "https://www." is not eaten by "https://".
        val prefixes = listOf(
            "https://www." to 0x02,
            "http://www." to 0x01,
            "https://" to 0x04,
            "http://" to 0x03,
        )
        for ((prefix, code) in prefixes) {
            if (url.startsWith(prefix)) {
                return byteArrayOf(code.toByte()) +
                    url.removePrefix(prefix).toByteArray(Charsets.US_ASCII)
            }
        }
        return byteArrayOf(0x00) + url.toByteArray(Charsets.US_ASCII)
    }

    /**
     * 15-byte Capability Container (NFC Forum T4T 1.0):
     * `00 0F 20 00 3B 00 34 04 06 E1 04 <nlen hi> <nlen lo> 00 00`.
     * The bytes after E1 04 carry the advertised NDEF size kept in sync with
     * the served NLEN so readers never think the file is truncated.
     */
    fun buildCapabilityContainer(ndefFileLen: Int): ByteArray {
        require(ndefFileLen in 0x0002..0xFFFF) { "NDEF length out of range" }
        return byteArrayOf(
            0x00, 0x0F, // CC length
            0x20,       // mapping version 2.0
            0x00, 0x3B, // MLe: max READ BINARY size we accept
            0x00, 0x34, // MLc: max WRITE BINARY size we accept
            0x04, 0x06, // NDEF file control TLV: T=04 L=06
            0xE1.toByte(), 0x04,          // NDEF file ID
            (ndefFileLen shr 8).toByte(), // advertised NDEF file size (hi)
            (ndefFileLen and 0xFF).toByte(), // (lo)
            0x00, 0x00, // read (unrestricted) / write (never allowed)
        )
    }

    /** NDEF file layout: big-endian NLEN followed by the message. */
    fun buildNdefFile(url: String): ByteArray {
        val message = buildUriRecord(url)
        val len = message.size
        return byteArrayOf((len shr 8).toByte(), (len and 0xFF).toByte()) + message
    }
}

class BeelInviteApduService : HostApduService() {
    companion object {
        private const val TAG = "BeelInviteApdu"

        /** Armed join URL; null disables emulation (everything -> 6D00). */
        @Volatile
        private var inviteUrl: String? = null

        /** 0x9000: instruction executed correctly. */
        private val SW_OK = byteArrayOf(0x90.toByte(), 0x00)

        /** 0x6D00: instruction not supported / nothing to serve. */
        private val SW_ERR = byteArrayOf(0x6D.toByte(), 0x00.toByte())

        /** NDEF application AID from the NFC Forum Type 4 Tag spec. */
        private val NDEF_APP_AID = byteArrayOf(
            0xD2.toByte(), 0x76.toByte(), 0x00.toByte(), 0x00.toByte(),
            0x85.toByte(), 0x01.toByte(), 0x01,
        )
        private val CC_FILE_ID = byteArrayOf(0xE1.toByte(), 0x03)
        private val NDEF_FILE_ID = byteArrayOf(0xE1.toByte(), 0x04)

        /** Arms / disarms emulation. Live update, no restart needed. */
        fun setInviteUrl(url: String?) {
            inviteUrl = url
        }

        fun clearInviteToken() {
            inviteUrl = null
        }
    }

    private enum class SelectedFile { NONE, CC, NDEF }
    private var selected = SelectedFile.NONE

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        val apdu = commandApdu ?: return SW_ERR
        if (apdu.size < 5) return SW_ERR
        val cla = apdu[0].toInt() and 0xFF
        val ins = apdu[1].toInt() and 0xFF
        return try {
            // SELECT (00 A4 ...): NDEF application or one of our two files.
            if (cla == 0x00 && ins == 0xA4) handleSelect(apdu)
            // READ BINARY (00 B0 P1P2 Le): serve CC or NDEF file slice.
            else if (cla == 0x00 && ins == 0xB0) handleReadBinary(apdu)
            else SW_ERR
        } catch (e: Exception) {
            android.util.Log.e(TAG, "APDU handling failed", e)
            SW_ERR
        }
    }

    /**
     * SELECT handling. Android's reader stack addresses files with P2=0x0C
     * ("no FCI returned"), so a bare status word is the right answer.
     */
    private fun handleSelect(apdu: ByteArray): ByteArray {
        // Disarmed: nothing to emulate; the reader must not see an NDEF app.
        if (inviteUrl == null) return SW_ERR
        val lc = apdu[4].toInt() and 0xFF
        val data = if (apdu.size >= 5 + lc) {
            apdu.copyOfRange(5, 5 + lc)
        } else {
            ByteArray(0)
        }
        val file = when {
            data.contentEquals(NDEF_APP_AID) -> {
                // Selecting the NDEF application resets any previous selection.
                selected = SelectedFile.NONE
                null
            }
            data.contentEquals(CC_FILE_ID) -> SelectedFile.CC
            data.contentEquals(NDEF_FILE_ID) -> SelectedFile.NDEF
            else -> return SW_ERR
        }
        if (file != null) {
            // A file select only counts if the tag is armed; otherwise the
            // reader must not discover an NDEF file at all.
            if (ndefFile() == null) return SW_ERR
            selected = file
        }
        return SW_OK
    }

    private fun handleReadBinary(apdu: ByteArray): ByteArray {
        val offset = ((apdu[2].toInt() and 0xFF) shl 8) or (apdu[3].toInt() and 0xFF)
        // Le=0 encodes 256.
        val le = if (apdu.size >= 5) (apdu[4].toInt() and 0xFF).let {
            if (it == 0) 256 else it
        } else 256
        val file = when (selected) {
            SelectedFile.CC ->
                ndefFileLen()?.let { BeelNdefCodec.buildCapabilityContainer(it) }
            SelectedFile.NDEF -> ndefFile()
            SelectedFile.NONE -> null
        } ?: return SW_ERR
        if (offset > file.size) return SW_ERR
        val end = minOf(file.size, offset + le)
        return file.copyOfRange(offset, end) + SW_OK
    }

    private fun ndefFile(): ByteArray? =
        inviteUrl?.let { BeelNdefCodec.buildNdefFile(it) }

    private fun ndefFileLen(): Int? = ndefFile()?.size

    override fun onDeactivated(reason: Int) {
        // Keep serving the same invite across field on/off cycles; the armed
        // URL stays until Dart disarms it.
    }
}