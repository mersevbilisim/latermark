package com.mersev.latermark

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.exifinterface.media.ExifInterface
import com.google.android.gms.tasks.Tasks
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import kotlin.math.max
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private companion object {
        const val IMPORT_CHANNEL = "latermark/shared_import"
        const val SETTINGS_CHANNEL = "latermark/app_settings"
        const val OCR_CHANNEL = "latermark/ocr"
        const val IMAGE_CHANNEL = "latermark/image"
        const val REMINDER_ACTION_CHANNEL = "latermark/reminder_actions"
        const val INBOX = "latermark_shared_imports"
        const val OCR_MAX_DIMENSION = 2560
        const val OCR_LOG_TAG = "LatermarkOCR"
    }

    private val importExecutor = Executors.newSingleThreadExecutor()
    private val ocrExecutor = Executors.newSingleThreadExecutor()
    private var importChannel: MethodChannel? = null
    private var settingsChannel: MethodChannel? = null
    private var ocrChannel: MethodChannel? = null
    private var imageChannel: MethodChannel? = null
    private var reminderActionChannel: MethodChannel? = null
    private var locationChannel: MethodChannel? = null
    private var location: LocationChannel? = null

    /// Tanıyıcı tembel kuruluyor: OCR hiç kullanılmayabilir ve kurulum
    /// Play Services'e gidiyor.
    private val recognizer = lazy {
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureSharedImage(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureSharedImage(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        imageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IMAGE_CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "compress") {
                    result.notImplemented()
                } else {
                    val path = call.argument<String>("path")
                    val maxEdge = call.argument<Int>("maxEdge") ?: 2048
                    val quality = call.argument<Int>("quality") ?: 88
                    importExecutor.execute {
                        val done = compressImage(path, maxEdge, quality)
                        runOnUiThread { result.success(done) }
                    }
                }
            }
        }

        ocrChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OCR_CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "read") {
                    result.notImplemented()
                } else {
                    readText(call.argument<String>("path"), result)
                }
            }
        }

        importChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IMPORT_CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePendingSharedImport" -> result.success(nextPendingImport())
                    "completeSharedImport" -> {
                        val id = call.argument<String>("id")
                        if (id != null) completeImport(id)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        locationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LocationChannel.NAME,
        ).also { channel ->
            LocationChannel(this).also { handler ->
                location = handler
                handler.register(channel)
            }
        }

        reminderActionChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            REMINDER_ACTION_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "timeZoneIdentifier" -> result.success(TimeZone.getDefault().id)
                    else -> result.notImplemented()
                }
            }
        }

        settingsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SETTINGS_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationSettings" -> result.success(openNotificationSettings())
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        importChannel?.setMethodCallHandler(null)
        importChannel = null
        settingsChannel?.setMethodCallHandler(null)
        settingsChannel = null
        ocrChannel?.setMethodCallHandler(null)
        ocrChannel = null
        reminderActionChannel?.setMethodCallHandler(null)
        reminderActionChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (location?.onPermissionResult(requestCode, grantResults) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        importExecutor.shutdown()
        if (recognizer.isInitialized()) {
            // Kuyrukta kalan okumalar tamamlandıktan sonra yerel kaynakları bırak.
            ocrExecutor.execute { recognizer.value.close() }
        }
        ocrExecutor.shutdown()
        super.onDestroy()
    }

    /// Karedeki yazıyı okur.
    ///
    /// `null` ile `""` ayrı anlamlar taşıyor: `null` "okuma yapılamadı, sonra
    /// yeniden dene", `""` ise "okundu, yazı yok".
    ///
    /// Bu ayrım Android'de kritik: model APK'da gömülü değil, ilk kullanımda
    /// Play Services'ten iniyor. O aralıkta başarısızlığı boş dize saymak,
    /// kareyi kalıcı olarak "taranmış ve yazısız" işaretlerdi.
    private fun readText(path: String?, result: MethodChannel.Result) {
        val file = if (path != null) File(path) else null
        if (file == null || !file.isFile) {
            result.success(null)
            return
        }

        try {
            ocrExecutor.execute {
                var bitmap: Bitmap? = null
                try {
                    val prepared = prepareOcrImage(file)
                    bitmap = prepared?.bitmap
                    if (prepared == null) {
                        deliverOcrResult(result, null)
                        return@execute
                    }

                    // await yalnızca OCR kuyruğunu bekletir. Böylece aynı anda birden
                    // fazla büyük kare işlenmez ve ana thread hiçbir aşamada bloklanmaz.
                    val text = Tasks.await(
                        recognizer.value.process(
                            InputImage.fromBitmap(prepared.bitmap, prepared.rotationDegrees),
                        ),
                    )
                    deliverOcrResult(
                        result,
                        text.text.replace(Regex("\\s+"), " ").trim(),
                    )
                } catch (error: Exception) {
                    Log.w(OCR_LOG_TAG, "Text recognition failed", error)
                    deliverOcrResult(result, null)
                } finally {
                    bitmap?.recycle()
                }
            }
        } catch (_: RejectedExecutionException) {
            result.success(null)
        }
    }

    private data class PreparedOcrImage(
        val bitmap: Bitmap,
        val rotationDegrees: Int,
    )

    /// Görseli tam çözünürlükte belleğe almadan OCR için yeterli boyuta indirir.
    /// EXIF yönü ayrıca korunur; bu yüzden döndürülmüş kamera kareleri doğru okunur.
    private fun prepareOcrImage(file: File): PreparedOcrImage? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        val decodeOptions = BitmapFactory.Options().apply {
            inSampleSize = calculateOcrSampleSize(bounds.outWidth, bounds.outHeight)
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        var bitmap = BitmapFactory.decodeFile(file.absolutePath, decodeOptions) ?: return null

        val longestSide = max(bitmap.width, bitmap.height)
        if (longestSide > OCR_MAX_DIMENSION) {
            val scale = OCR_MAX_DIMENSION.toFloat() / longestSide
            val scaled = Bitmap.createScaledBitmap(
                bitmap,
                (bitmap.width * scale).roundToInt().coerceAtLeast(1),
                (bitmap.height * scale).roundToInt().coerceAtLeast(1),
                true,
            )
            if (scaled !== bitmap) bitmap.recycle()
            bitmap = scaled
        }

        val exif = try {
            ExifInterface(file)
        } catch (error: Exception) {
            Log.w(OCR_LOG_TAG, "Could not read image orientation", error)
            null
        }

        if (exif?.isFlipped == true) {
            val flipped = Bitmap.createBitmap(
                bitmap,
                0,
                0,
                bitmap.width,
                bitmap.height,
                Matrix().apply { setScale(-1f, 1f) },
                true,
            )
            if (flipped !== bitmap) bitmap.recycle()
            bitmap = flipped
        }

        return PreparedOcrImage(
            bitmap = bitmap,
            rotationDegrees = exif?.rotationDegrees ?: 0,
        )
    }

    private fun calculateOcrSampleSize(width: Int, height: Int): Int {
        var sampleSize = 1
        while (max(width, height) / (sampleSize * 2) >= OCR_MAX_DIMENSION) {
            sampleSize *= 2
        }
        return sampleSize
    }

    private fun deliverOcrResult(result: MethodChannel.Result, value: String?) {
        runOnUiThread { result.success(value) }
    }

    /// Kareyi yerinde küçültür. Başarısız olursa dosyaya **dokunmaz**.
    ///
    /// Sıkıştırma bir iyileştirme; kullanıcının karesini kaybetmektense büyük
    /// saklamak yeğdir.
    private fun compressImage(path: String?, maxEdge: Int, quality: Int): Boolean {
        val file = if (path != null) File(path) else null
        if (file == null || !file.exists()) return false

        try {
            // Önce yalnızca boyutu oku; tam çözünürlüklü bir kareyi belleğe
            // almadan küçültme oranını hesaplamak için.
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.path, bounds)
            val longest = maxOf(bounds.outWidth, bounds.outHeight)
            if (longest <= 0 || longest <= maxEdge) return false

            var sample = 1
            while (longest / (sample * 2) >= maxEdge) sample *= 2

            val decoded = BitmapFactory.decodeFile(
                file.path,
                BitmapFactory.Options().apply { inSampleSize = sample },
            ) ?: return false

            val current = maxOf(decoded.width, decoded.height)
            val ratio = maxEdge.toFloat() / current
            val scaled = if (ratio < 1f) {
                Bitmap.createScaledBitmap(
                    decoded,
                    (decoded.width * ratio).toInt(),
                    (decoded.height * ratio).toInt(),
                    true,
                )
            } else {
                decoded
            }

            // EXIF yönü: `BitmapFactory` etiketi uygulamıyor. Yeniden
            // kodlarken etiket de kaybolacağı için dönüşü kareye işliyoruz;
            // yoksa fotoğraflar yan yatardı.
            val upright = applyExifRotation(file, scaled)

            // Yeni kare **yan dosyaya** yazılıp sonra yerine taşınıyor.
            // Doğrudan `file.outputStream()` açmak dosyayı önce sıfırlıyordu:
            // 12 MP bir kareyi kodlamak yüz milisaniyeler sürer ve uygulama o
            // aralıkta öldürülürse kullanıcının fotoğrafı yarım kalırdı.
            // `renameTo` aynı klasörde atomik; okuyan taraf ya eski ya yeni
            // kareyi görür, ikisinin arasını asla görmez.
            val staging = File(file.parentFile, "${file.name}.tmp")
            try {
                staging.outputStream().use { stream ->
                    upright.compress(Bitmap.CompressFormat.JPEG, quality, stream)
                }
                if (!staging.renameTo(file)) {
                    staging.delete()
                    return false
                }
                return true
            } catch (error: Exception) {
                staging.delete()
                return false
            }
        } catch (error: Exception) {
            return false
        }
    }

    private fun applyExifRotation(file: File, bitmap: Bitmap): Bitmap {
        val degrees = when (
            ExifInterface(file.path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        ) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
        if (degrees == 0f) return bitmap

        val matrix = Matrix().apply { postRotate(degrees) }
        return Bitmap.createBitmap(
            bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true,
        )
    }

    private fun captureSharedImage(sourceIntent: Intent?) {
        if (sourceIntent?.action != Intent.ACTION_SEND) return
        if (sourceIntent.type?.startsWith("image/") != true) return

        val uri = sharedUri(sourceIntent) ?: return
        // Aynı intent bir yapılandırma değişiminde tekrar işlenmesin.
        sourceIntent.action = null

        val initialText = sourceIntent.getStringExtra(Intent.EXTRA_TEXT).orEmpty()
        val mimeType = sourceIntent.type
        importExecutor.execute {
            if (copyIntoInbox(uri, mimeType, initialText)) {
                runOnUiThread {
                    importChannel?.invokeMethod("sharedImportAvailable", null)
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun sharedUri(intent: Intent): Uri? {
        val stream = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
        return stream ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
    }

    private fun copyIntoInbox(uri: Uri, mimeType: String?, initialText: String): Boolean {
        val directory = inboxDirectory()
        val id = UUID.randomUUID().toString()
        val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
            ?.takeIf { it.matches(Regex("[A-Za-z0-9]{1,8}")) }
            ?: "jpg"
        val image = File(directory, "$id.$extension")
        val metadata = File(directory, "$id.json")

        return try {
            contentResolver.openInputStream(uri)?.use { input ->
                image.outputStream().use { output -> input.copyTo(output) }
            } ?: return false

            val payload = JSONObject()
                .put("id", id)
                .put("imageName", image.name)
                .put("initialText", initialText)
                .put("createdAtMilliseconds", System.currentTimeMillis())
                .put("saveImmediately", false)
            metadata.writeText(payload.toString())
            true
        } catch (_: Exception) {
            image.delete()
            metadata.delete()
            false
        }
    }

    private fun nextPendingImport(): Map<String, Any>? {
        val directory = inboxDirectory()
        val metadataFiles = directory.listFiles { file -> file.extension == "json" }
            ?.sortedBy { it.lastModified() }
            .orEmpty()

        for (metadataFile in metadataFiles) {
            try {
                val payload = JSONObject(metadataFile.readText())
                val id = payload.getString("id")
                val image = File(directory, payload.getString("imageName"))
                if (!isInsideInbox(image, directory) || !image.isFile) {
                    metadataFile.delete()
                    continue
                }
                return mapOf(
                    "id" to id,
                    "path" to image.absolutePath,
                    "initialText" to payload.optString("initialText"),
                    "createdAtMilliseconds" to payload.optLong("createdAtMilliseconds"),
                    "saveImmediately" to payload.optBoolean("saveImmediately", false),
                )
            } catch (_: Exception) {
                metadataFile.delete()
            }
        }
        return null
    }

    private fun completeImport(id: String) {
        if (!id.matches(Regex("[0-9a-fA-F-]{36}"))) return
        val directory = inboxDirectory()
        val metadata = File(directory, "$id.json")
        try {
            if (metadata.isFile) {
                val payload = JSONObject(metadata.readText())
                val image = File(directory, payload.optString("imageName"))
                if (isInsideInbox(image, directory)) image.delete()
            }
        } catch (_: Exception) {
            // Bozuk yan veri görselin güvenli sınırlar dışında silinmesine yol açmaz.
        }
        metadata.delete()
    }

    private fun inboxDirectory(): File = File(cacheDir, INBOX).apply { mkdirs() }

    private fun openNotificationSettings(): Boolean {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        } else {
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            )
        }

        return try {
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun isInsideInbox(file: File, directory: File): Boolean =
        file.canonicalFile.parentFile == directory.canonicalFile
}
