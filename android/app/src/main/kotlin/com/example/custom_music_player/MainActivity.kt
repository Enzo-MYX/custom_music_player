package com.example.custom_music_player

import android.media.MediaMetadataRetriever
import android.net.Uri
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
                        "artwork" to retriever.embeddedPicture
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
}