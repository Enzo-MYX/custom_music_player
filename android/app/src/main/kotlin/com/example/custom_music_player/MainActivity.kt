package com.example.custom_music_player

import android.media.MediaMetadataRetriever
import android.net.Uri
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.charset.Charset

class MainActivity : AudioServiceActivity() {
    private val metadataChannel =
        "com.example.custom_music_player/metadata"

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            metadataChannel
        ).setMethodCallHandler { call, result ->
            if (call.method != "readMetadata") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val uriString = call.argument<String>("uri")
            val lyricsUriString = call.argument<String>("lyricsUri")

            if (uriString == null) {
                result.error(
                    "missing_uri",
                    "No song URI was supplied.",
                    null
                )
                return@setMethodCallHandler
            }

            val retriever = MediaMetadataRetriever()

            try {
                retriever.setDataSource(
                    applicationContext,
                    Uri.parse(uriString)
                )

                result.success(
                    mapOf<String, Any?>(
                        "title" to retriever.extractMetadata(
                            MediaMetadataRetriever.METADATA_KEY_TITLE
                        ),
                        "artist" to retriever.extractMetadata(
                            MediaMetadataRetriever.METADATA_KEY_ARTIST
                        ),
                        "album" to retriever.extractMetadata(
                            MediaMetadataRetriever.METADATA_KEY_ALBUM
                        ),
                        "albumArtist" to retriever.extractMetadata(
                            MediaMetadataRetriever.METADATA_KEY_ALBUMARTIST
                        ),
                        "trackNumber" to retriever.extractMetadata(
                            MediaMetadataRetriever.METADATA_KEY_CD_TRACK_NUMBER
                        ),
                        "year" to retriever.extractMetadata(
                            MediaMetadataRetriever.METADATA_KEY_YEAR
                        ),
                        "artwork" to retriever.embeddedPicture,
                        "embeddedLyrics" to readEmbeddedLyrics(
                            Uri.parse(uriString)
                        ),
                        "sidecarLyrics" to lyricsUriString?.let {
                            readText(Uri.parse(it))
                        }
                    )
                )
            } catch (error: Exception) {
                result.error(
                    "metadata_error",
                    error.message,
                    null
                )
            } finally {
                retriever.release()
            }
        }
    }

    private fun readText(uri: Uri): String? {
        return try {
            val bytes = applicationContext.contentResolver
                .openInputStream(uri)
                ?.use { it.readBytes() }
                ?: return null
            val text = when {
                bytes.size >= 3 &&
                    bytes[0] == 0xef.toByte() &&
                    bytes[1] == 0xbb.toByte() &&
                    bytes[2] == 0xbf.toByte() ->
                    bytes.copyOfRange(3, bytes.size).toString(Charsets.UTF_8)
                bytes.size >= 2 &&
                    bytes[0] == 0xff.toByte() &&
                    bytes[1] == 0xfe.toByte() ->
                    bytes.copyOfRange(2, bytes.size)
                        .toString(Charset.forName("UTF-16LE"))
                bytes.size >= 2 &&
                    bytes[0] == 0xfe.toByte() &&
                    bytes[1] == 0xff.toByte() ->
                    bytes.copyOfRange(2, bytes.size)
                        .toString(Charset.forName("UTF-16BE"))
                else -> bytes.toString(Charsets.UTF_8)
            }
            text.trim().takeIf { it.isNotBlank() }
        } catch (_: Exception) {
            null
        }
    }

    private fun readEmbeddedLyrics(uri: Uri): String? {
        return try {
            applicationContext.contentResolver.openInputStream(uri)?.use {
                input ->
                val signature = input.readExact(4) ?: return@use null

                when {
                    signature[0] == 'I'.code.toByte() &&
                        signature[1] == 'D'.code.toByte() &&
                        signature[2] == '3'.code.toByte() ->
                        readId3Lyrics(input, signature)
                    signature.contentEquals("fLaC".toByteArray()) ->
                        readFlacLyrics(input)
                    else -> null
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun readId3Lyrics(
        input: InputStream,
        signature: ByteArray
    ): String? {
        val rest = input.readExact(6) ?: return null
        val header = signature + rest
        val version = header[3].toInt() and 0xff
        if (version !in 3..4) return null

        val tagSize = syncSafeInt(header, 6)
        val tag = input.readExact(tagSize) ?: return null
        var offset = 0

        while (offset + 10 <= tag.size) {
            val id = tag.copyOfRange(offset, offset + 4)
                .toString(Charsets.ISO_8859_1)
            if (id.all { it == '\u0000' }) break

            val size = if (version == 4) {
                syncSafeInt(tag, offset + 4)
            } else {
                ByteBuffer.wrap(tag, offset + 4, 4).int
            }
            if (size <= 0 || offset + 10 + size > tag.size) break

            val payload = tag.copyOfRange(offset + 10, offset + 10 + size)
            when (id) {
                "SYLT" -> decodeSylt(payload)?.let { return it }
                "USLT" -> decodeUslt(payload)?.let { return it }
            }
            offset += 10 + size
        }

        return null
    }

    private fun decodeUslt(data: ByteArray): String? {
        if (data.size < 5) return null
        val encoding = data[0].toInt() and 0xff
        val descriptorEnd = terminatedStringEnd(data, 4, encoding)
        val lyricsStart = descriptorEnd + terminatorLength(encoding)
        if (lyricsStart > data.size) return null
        return decodeText(data.copyOfRange(lyricsStart, data.size), encoding)
            .trim('\u0000', ' ', '\r', '\n')
            .takeIf { it.isNotBlank() }
    }

    private fun decodeSylt(data: ByteArray): String? {
        if (data.size < 7) return null
        val encoding = data[0].toInt() and 0xff
        val timestampFormat = data[4].toInt() and 0xff
        if (timestampFormat != 2) return null

        var offset = terminatedStringEnd(data, 6, encoding) +
            terminatorLength(encoding)
        val result = StringBuilder()

        while (offset < data.size) {
            val textEnd = terminatedStringEnd(data, offset, encoding)
            val timeOffset = textEnd + terminatorLength(encoding)
            if (timeOffset + 4 > data.size) break

            val text = decodeText(
                data.copyOfRange(offset, textEnd),
                encoding
            ).trim()
            val milliseconds = ByteBuffer
                .wrap(data, timeOffset, 4)
                .int
                .toLong() and 0xffffffffL
            val minutes = milliseconds / 60000
            val seconds = (milliseconds % 60000) / 1000
            val millis = milliseconds % 1000

            result.append(
                "[%02d:%02d.%03d]%s\n".format(
                    minutes,
                    seconds,
                    millis,
                    text
                )
            )
            offset = timeOffset + 4
        }

        return result.toString().trim().takeIf { it.isNotBlank() }
    }

    private fun readFlacLyrics(input: InputStream): String? {
        var isLast = false

        while (!isLast) {
            val header = input.readExact(4) ?: return null
            isLast = (header[0].toInt() and 0x80) != 0
            val type = header[0].toInt() and 0x7f
            val length = ((header[1].toInt() and 0xff) shl 16) or
                ((header[2].toInt() and 0xff) shl 8) or
                (header[3].toInt() and 0xff)
            val block = input.readExact(length) ?: return null

            if (type == 4) {
                return readVorbisLyrics(block)
            }
        }

        return null
    }

    private fun readVorbisLyrics(data: ByteArray): String? {
        val buffer = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN)
        if (buffer.remaining() < 4) return null
        val vendorLength = buffer.int
        if (vendorLength < 0 || vendorLength > buffer.remaining()) return null
        buffer.position(buffer.position() + vendorLength)
        if (buffer.remaining() < 4) return null

        val count = buffer.int
        var unsynchronized: String? = null

        repeat(count.coerceAtLeast(0)) {
            if (buffer.remaining() < 4) return@repeat
            val length = buffer.int
            if (length < 0 || length > buffer.remaining()) return@repeat
            val bytes = ByteArray(length)
            buffer.get(bytes)
            val comment = bytes.toString(Charsets.UTF_8)
            val separator = comment.indexOf('=')
            if (separator <= 0) return@repeat

            val key = comment.substring(0, separator).uppercase()
            val value = comment.substring(separator + 1).trim()
            when (key) {
                "SYNCEDLYRICS", "SYNCLYRICS" ->
                    if (value.isNotEmpty()) return value
                "LYRICS", "UNSYNCEDLYRICS", "UNSYNCED LYRICS" ->
                    if (value.isNotEmpty()) unsynchronized = value
            }
        }

        return unsynchronized
    }

    private fun syncSafeInt(data: ByteArray, offset: Int): Int {
        return ((data[offset].toInt() and 0x7f) shl 21) or
            ((data[offset + 1].toInt() and 0x7f) shl 14) or
            ((data[offset + 2].toInt() and 0x7f) shl 7) or
            (data[offset + 3].toInt() and 0x7f)
    }

    private fun terminatedStringEnd(
        data: ByteArray,
        start: Int,
        encoding: Int
    ): Int {
        val step = terminatorLength(encoding)
        var index = start
        while (index + step <= data.size) {
            if (data[index] == 0.toByte() &&
                (step == 1 || data[index + 1] == 0.toByte())) {
                return index
            }
            index += step
        }
        return data.size
    }

    private fun terminatorLength(encoding: Int): Int {
        return if (encoding == 1 || encoding == 2) 2 else 1
    }

    private fun decodeText(data: ByteArray, encoding: Int): String {
        val charset = when (encoding) {
            0 -> Charsets.ISO_8859_1
            1 -> Charsets.UTF_16
            2 -> Charset.forName("UTF-16BE")
            else -> Charsets.UTF_8
        }
        return data.toString(charset)
    }

    private fun InputStream.readExact(length: Int): ByteArray? {
        if (length < 0) return null
        val output = ByteArrayOutputStream(length)
        val buffer = ByteArray(minOf(8192, maxOf(length, 1)))
        var remaining = length

        while (remaining > 0) {
            val read = read(buffer, 0, minOf(buffer.size, remaining))
            if (read < 0) return null
            output.write(buffer, 0, read)
            remaining -= read
        }

        return output.toByteArray()
    }
}
