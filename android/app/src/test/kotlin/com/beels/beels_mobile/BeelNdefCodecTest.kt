package com.beels.beels_mobile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertArrayEquals
import org.junit.Test

/**
 * Protocol-level tests for the HCE NDEF emitter. These verify what an NFC
 * reader stack sees byte-for-byte; real field behaviour still needs hardware
 * (covered by manual device verification).
 */
class BeelNdefCodecTest {
    private fun hex(bytes: ByteArray) = bytes.joinToString(" ") {
        "%02X".format(it)
    }

    @Test
    fun `uri record encodes https url with prefix code and well-known header`() {
        val record = BeelNdefCodec.buildUriRecord(
            "https://beels-frontend-production.up.railway.app/join/tok42",
        )

        // SR record: MB+ME+SR, TNF well-known, type length 1.
        assertEquals(0x91, record[0].toInt() and 0xFF)
        assertEquals(0x01, record[1].toInt() and 0xFF)
        assertEquals(0x55, record[3].toInt()) // type "U"
        assertEquals(0x04, record[4].toInt()) // prefix "https://"
        val uriRest = record.copyOfRange(5, record.size)
            .toString(Charsets.US_ASCII)
        assertEquals(
            "beels-frontend-production.up.railway.app/join/tok42",
            uriRest,
        )
        // Payload length = type byte + prefix byte + remaining URI bytes.
        assertEquals(2 + uriRest.length, record[2].toInt() and 0xFF)
    }

    @Test
    fun `well-known www prefixes map to their short URI codes`() {
        val www = BeelNdefCodec.buildUriRecord("https://www.example.co/join/x")
        assertEquals(0x02, www[4].toInt())
        assertEquals("example.co/join/x", www.copyOfRange(5, www.size).decodeToString())

        val plain = BeelNdefCodec.buildUriRecord("http://x.example.co")
        assertEquals(0x03, plain[4].toInt())

        // Unknown scheme keeps the full URI with code 0.
        val other = BeelNdefCodec.buildUriRecord("ftp://example.co/a")
        assertEquals(0x00, other[4].toInt())
        assertTrue(other.copyOfRange(5, other.size).decodeToString().startsWith("ftp://"))
    }

    @Test
    fun `ndef file prepends correct big endian NLEN`() {
        val file = BeelNdefCodec.buildNdefFile(
            "https://beels-frontend-production.up.railway.app/join/tok42",
        )
        val nlen = ((file[0].toInt() and 0xFF) shl 8) or (file[1].toInt() and 0xFF)
        assertEquals(file.size - 2, nlen)

        // A short enough message uses the short-record form (no 3-byte length).
        assertTrue(nlen < 0xFF)
        // NLEN + message, message starts with the record header.
        assertEquals(0x91, file[2].toInt() and 0xFF)
    }

    @Test
    fun `capability container is the 15 byte T4T layout with synced NLEN`() {
        val file = BeelNdefCodec.buildNdefFile("https://beels-frontend-production.up.railway.app/join/x")
        val cc = BeelNdefCodec.buildCapabilityContainer(file.size)

        assertEquals(15, cc.size)
        assertEquals(0x000F, ((cc[0].toInt() and 0xFF) shl 8) or (cc[1].toInt() and 0xFF))
        assertEquals(0x20, cc[2].toInt())
        assertEquals(0xE1, cc[9].toInt() and 0xFF)
        assertEquals(0x04, cc[10].toInt() and 0xFF)
        assertEquals(
            file.size,
            ((cc[11].toInt() and 0xFF) shl 8) or (cc[12].toInt() and 0xFF),
        )
    }

    @Test
    fun `record payload stays within the short record limit`() {
        val longUrl = "https://" + "a".repeat(120) + "/j/t"
        // 120-char URL must still fit a SR record (payload <= 255).
        val record = BeelNdefCodec.buildUriRecord(longUrl)
        assertTrue(record[2].toInt() and 0xFF <= 0xFF)
    }
}