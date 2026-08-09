package com.mersev.latermark

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.Shader
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tan

/**
 * Ana ekranda en son notu gösteren widget.
 *
 * Flutter tarafı verileri [es.antonborri.home_widget.HomeWidgetPlugin]'in
 * paylaşılan tercihlerine yazar; burada yalnızca çizim yapılır. Anahtar
 * isimleri `lib/features/home_widget/widget_keys.dart` ile birebir aynı olmalı.
 */
class NotWidgetProvider : HomeWidgetProvider() {

    private object Keys {
        const val HAS_NOTE = "not_has_note"
        const val NOTE_ID = "not_note_id"
        const val BODY = "not_body"
        const val TIME = "not_time"
        const val DATE = "not_date"
        const val EXPIRES_AT = "not_expires_at"
        const val CREATED_AT = "not_created_at"
        const val COUNT = "not_count"
        const val PRO = "not_pro"
        const val ACCENT = "not_accent"
        const val PHOTO = "not_photo"
    }

    private object Palette {
        const val INK = 0xFFF3F1ED.toInt()
        const val INK_FAINT: Int = 0x52F3F1ED
        const val DEFAULT_ACCENT = 0xFFFF7A55.toInt()
    }

    /**
     * Aynı widget, launcher'ın verdiği alana göre üç ayrı kompozisyon kullanır.
     * Sadece metni büyütüp küçültmek yerine fotoğraf/not ilişkisi de değişir:
     * karede üst üste, yatayda yan yana, yüksek alanda fotoğraf üstte.
     */
    private enum class WidgetFormat(
        val layout: Int,
        val signatureDp: Int,
        val fieldMarkDp: Int,
        val emptyMarkDp: Int,
        val lifeRuleDp: Int,
    ) {
        COMPACT(R.layout.not_widget, 18, 86, 52, 116),
        WIDE(R.layout.not_widget_wide, 20, 72, 48, 176),
        TALL(R.layout.not_widget_tall, 20, 104, 58, 218),
    }

    private companion object {
        // home_widget paketinin Android tarafında kullandığı sabit ad.
        // Boyut değişiminde Flutter çalışmıyor olabileceği için veriyi doğrudan
        // buradan yeniden okuyup yeni RemoteViews kompozisyonunu kuruyoruz.
        const val HOME_WIDGET_PREFERENCES = "HomeWidgetPreferences"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            updateWidget(context, appWidgetManager, id, widgetData)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateWidget(
            context,
            appWidgetManager,
            appWidgetId,
            context.getSharedPreferences(HOME_WIDGET_PREFERENCES, Context.MODE_PRIVATE),
            newOptions,
        )
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        id: Int,
        data: SharedPreferences,
        suppliedOptions: Bundle? = null,
    ) {
        // Silme işini uygulama yapıyor ve yalnızca çalışırken yapabiliyor.
        // Kullanıcı uygulamayı günlerce açmazsa widget bayat bir kaydı
        // göstermeye devam ederdi; süre kontrolü bu yüzden burada da var.
        val expiresAt = data.number(Keys.EXPIRES_AT)
        val expired = expiresAt > 0L && expiresAt <= System.currentTimeMillis() / 1000
        val hasNote = data.getBoolean(Keys.HAS_NOTE, false) && !expired
        val isPro = data.getBoolean(Keys.PRO, false)
        val noteId = data.number(Keys.NOTE_ID)
        val accent = data.accent()
        val format = widgetFormat(
            suppliedOptions ?: appWidgetManager.getAppWidgetOptions(id),
        )
        val views = RemoteViews(context.packageName, format.layout)

        // Android 12+ köşeleri anahat üzerinden kırpabiliyor; böylece
        // fotoğraf da sistemin widget siluetine uyuyor. İçeride ikinci bir
        // kart/radius katmanı yok.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setViewOutlinePreferredRadius(
                R.id.widget_root,
                24f,
                TypedValue.COMPLEX_UNIT_DIP,
            )
        }

        when {
            !isPro -> renderLocked(context, views, format, accent)
            hasNote -> renderNote(context, views, data, format, accent)
            else -> renderEmpty(context, views, format, accent)
        }

        val opensNote = isPro && hasNote && noteId > 0
        views.setOnClickPendingIntent(
            R.id.widget_root,
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                if (opensNote) Uri.parse("latermark://note/$noteId?homeWidget") else null,
            ),
        )

        appWidgetManager.updateAppWidget(id, views)
    }

    private fun widgetFormat(options: Bundle): WidgetFormat {
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        return when {
            height >= 240 -> WidgetFormat.TALL
            width >= 250 -> WidgetFormat.WIDE
            else -> WidgetFormat.COMPACT
        }
    }

    private fun renderNote(
        context: Context,
        views: RemoteViews,
        data: SharedPreferences,
        format: WidgetFormat,
        accent: Int,
    ) {
        views.setViewVisibility(R.id.widget_main, View.VISIBLE)
        views.setViewVisibility(R.id.widget_empty, View.GONE)
        views.setViewVisibility(R.id.widget_locked, View.GONE)
        views.setViewVisibility(R.id.widget_scrim, View.VISIBLE)

        val photo = data.getString(Keys.PHOTO, null)?.let(::decodePhoto)
        if (photo != null) {
            views.setImageViewBitmap(R.id.widget_photo, photo)
            views.setViewVisibility(R.id.widget_photo, View.VISIBLE)
            views.setViewVisibility(R.id.widget_no_photo_art, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_photo, View.GONE)
            views.setViewVisibility(R.id.widget_no_photo_art, View.VISIBLE)
        }

        val expiresAt = data.number(Keys.EXPIRES_AT)
        val fraction = lifeFraction(
            createdAt = data.number(Keys.CREATED_AT),
            expiresAt = expiresAt,
        )
        val openness = fraction?.let { 0.22f + (0.50f * it) } ?: 0.72f
        val density = context.resources.displayMetrics.density

        views.setImageViewBitmap(
            R.id.widget_signature,
            drawAperture(density, accent, format.signatureDp, openness),
        )
        views.setImageViewBitmap(
            R.id.widget_no_photo_art,
            drawAperture(density, accent, format.fieldMarkDp, openness),
        )
        views.setImageViewBitmap(
            R.id.widget_life_rule,
            drawLifeRule(density, format.lifeRuleDp, accent, fraction),
        )
        if (format != WidgetFormat.COMPACT) {
            views.setInt(R.id.widget_accent_seam, "setBackgroundColor", accent)
        }

        val body = data.getString(Keys.BODY, "").orEmpty().trim()
        views.setTextViewText(
            R.id.widget_body,
            body.ifEmpty { context.getString(R.string.widget_note_without_body) },
        )
        views.setTextColor(
            R.id.widget_body,
            if (body.isEmpty()) Palette.INK_FAINT else Palette.INK,
        )

        views.setTextViewText(R.id.widget_date, data.getString(Keys.DATE, "").orEmpty())
        views.setTextViewText(R.id.widget_time, data.getString(Keys.TIME, "").orEmpty())
        views.setTextViewText(
            R.id.widget_folio,
            context.getString(
                R.string.widget_folio,
                data.number(Keys.COUNT).coerceAtLeast(1L),
            ),
        )

        val remaining = remainingLabel(context, expiresAt)
        if (remaining == null) {
            // Süresiz not da sessizce boşluğa düşmüyor: açık uçlu yaşam
            // çizgisinin yanında sonsuzluk işareti kalıyor.
            views.setTextViewText(R.id.widget_expiry, "∞")
            views.setTextColor(R.id.widget_expiry, Palette.INK_FAINT)
        } else {
            views.setTextViewText(R.id.widget_expiry, remaining)
            views.setTextColor(R.id.widget_expiry, accent)
        }
    }

    private fun renderEmpty(
        context: Context,
        views: RemoteViews,
        format: WidgetFormat,
        accent: Int,
    ) {
        views.setViewVisibility(R.id.widget_main, View.GONE)
        views.setViewVisibility(R.id.widget_locked, View.GONE)
        views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
        views.setImageViewBitmap(
            R.id.widget_empty_aperture,
            drawAperture(
                context.resources.displayMetrics.density,
                accent,
                format.emptyMarkDp,
                0.72f,
            ),
        )
    }

    private fun renderLocked(
        context: Context,
        views: RemoteViews,
        format: WidgetFormat,
        accent: Int,
    ) {
        views.setViewVisibility(R.id.widget_main, View.GONE)
        views.setViewVisibility(R.id.widget_empty, View.GONE)
        views.setViewVisibility(R.id.widget_locked, View.VISIBLE)
        views.setImageViewBitmap(
            R.id.widget_locked_aperture,
            drawAperture(
                context.resources.displayMetrics.density,
                accent,
                format.emptyMarkDp,
                0.38f,
            ),
        )
    }

    /**
     * Sayısal değeri türden bağımsız okur.
     *
     * Flutter'ın mesaj kodlayıcısı 32 bite sığan tam sayıları `Int`, daha
     * büyüklerini `Long` olarak gönderir; hangisinin geleceğini varsaymak
     * ileride sessiz bir çökmeye yol açar.
     */
    private fun SharedPreferences.number(key: String): Long = try {
        getLong(key, 0L)
    } catch (_: ClassCastException) {
        getInt(key, 0).toLong()
    }

    private fun SharedPreferences.accent(): Int =
        getString(Keys.ACCENT, null)?.toLongOrNull(16)?.toInt()
            ?: Palette.DEFAULT_ACCENT

    /** 1 = yeni, 0 = ömrünün sonu. Süresiz notlarda açık uç için `null`. */
    private fun lifeFraction(createdAt: Long, expiresAt: Long): Float? {
        if (expiresAt <= 0L) return null
        val total = expiresAt - createdAt
        if (createdAt <= 0L || total <= 0L) return 0f
        val left = expiresAt - System.currentTimeMillis() / 1000
        return (left.toDouble() / total.toDouble()).coerceIn(0.0, 1.0).toFloat()
    }

    /** Kalan süreyi widget'ın yürürlükteki dilinde kısa biçimde verir. */
    private fun remainingLabel(context: Context, epochSeconds: Long): String? {
        if (epochSeconds <= 0L) return null
        val left = epochSeconds - System.currentTimeMillis() / 1000
        return when {
            left <= 0 -> context.getString(R.string.widget_remaining_now)
            left >= 86_400 -> context.getString(
                R.string.widget_remaining_days,
                ceil(left / 86_400.0).toLong(),
            )
            left >= 3_600 -> context.getString(
                R.string.widget_remaining_hours,
                ceil(left / 3_600.0).toLong(),
            )
            left >= 60 -> context.getString(
                R.string.widget_remaining_minutes,
                ceil(left / 60.0).toLong(),
            )
            else -> context.getString(R.string.widget_remaining_less_than_minute)
        }
    }

    /**
     * Fotoğrafın kadrajını bozmadan güvenli boyutta çözer.
     *
     * Üç kompozisyonun oranları farklı; burada kareye kırpmak yatay ve yüksek
     * widget'ta gereksiz ikinci bir crop yapıyordu. Son kırpmayı XML'deki
     * `centerCrop` kendi gerçek alanına göre yapar.
     */
    private fun decodePhoto(path: String): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sample = 1
        val longestEdge = maxOf(bounds.outWidth, bounds.outHeight)
        while (longestEdge / sample > 1_440) sample *= 2

        return BitmapFactory.decodeFile(
            path,
            BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = Bitmap.Config.ARGB_8888
            },
        )
    }

    /**
     * Boş durumdaki diyafram nişanı.
     *
     * Geometri Flutter ve SwiftUI taraflarıyla aynı: açıklık düzgün bir
     * çokgen, bıçak kenarları bu çokgenin kenarlarının dış çembere uzatılması.
     */
    private fun drawAperture(
        density: Float,
        accent: Int,
        sizeDp: Int,
        openness: Float,
    ): Bitmap {
        val size = (sizeDp * density).roundToInt().coerceAtLeast(sizeDp)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val center = size / 2f
        val outer = size / 2f - 1f
        val blades = 7
        val open = openness.coerceIn(0f, 1f)
        val inradius = outer * (0.045f + ((0.63f - 0.045f) * open))
        val circumradius = inradius / cos(Math.PI / blades).toFloat()
        val halfSide = inradius * tan(Math.PI / blades).toFloat()
        val reach = sqrt((outer * outer - inradius * inradius).coerceAtLeast(0f))

        // Açıklıktan sızan sıcak çekirdek.
        canvas.drawCircle(
            center,
            center,
            inradius,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(
                    center, center, inradius,
                    (accent and 0x00FFFFFF) or (0x59 shl 24),
                    accent and 0x00FFFFFF,
                    Shader.TileMode.CLAMP,
                )
            },
        )

        val hole = Path()
        for (k in 0 until blades) {
            val angle = (2 * k + 1) * Math.PI / blades
            val x = center + cos(angle).toFloat() * circumradius
            val y = center + sin(angle).toFloat() * circumradius
            if (k == 0) hole.moveTo(x, y) else hole.lineTo(x, y)
        }
        hole.close()

        val body = Path().apply {
            addCircle(center, center, outer, Path.Direction.CW)
            op(hole, Path.Op.DIFFERENCE)
        }
        canvas.drawPath(
            body,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(
                    0f, 0f, size.toFloat(), size.toFloat(),
                    0x3DFFFFFF, 0x14FFFFFF, Shader.TileMode.CLAMP,
                )
            },
        )

        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = density
            color = Color.argb(56, 255, 255, 255)
        }
        for (k in 0 until blades) {
            val angle = 2 * Math.PI * k / blades
            val tx = -sin(angle).toFloat()
            val ty = cos(angle).toFloat()
            val px = center + cos(angle).toFloat() * inradius
            val py = center + sin(angle).toFloat() * inradius
            canvas.drawLine(
                px + tx * halfSide, py + ty * halfSide,
                px + tx * reach, py + ty * reach,
                stroke,
            )
        }

        stroke.color = Color.argb(118, 255, 255, 255)
        canvas.drawPath(hole, stroke)
        stroke.color = Color.argb(97, 255, 255, 255)
        canvas.drawCircle(center, center, outer, stroke)
        return bitmap
    }

    /**
     * Latermark'ın ince yaşam cetveli. Progress bar gibi kalın bir kapsül
     * değil: süreli notta elmas biçimli "şimdi" işareti, süresizde açık bir
     * uç kullanır. Böylece kısa bir notun altında bile zaman bağlamı kalır.
     */
    private fun drawLifeRule(
        density: Float,
        widthDp: Int,
        accent: Int,
        remainingFraction: Float?,
    ): Bitmap {
        val width = (widthDp * density).roundToInt().coerceAtLeast(widthDp)
        val height = (8 * density).roundToInt().coerceAtLeast(8)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val centerY = height / 2f
        val inset = 2f * density
        val end = width - inset
        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Palette.INK_FAINT
            strokeWidth = 0.75f * density
            strokeCap = Paint.Cap.SQUARE
        }

        if (remainingFraction == null) {
            val openEnd = end - (5f * density)
            canvas.drawLine(inset, centerY, openEnd, centerY, track)
            track.color = (accent and 0x00FFFFFF) or (0xA8 shl 24)
            track.strokeWidth = density
            canvas.drawLine(openEnd, centerY, end, centerY - (2f * density), track)
            canvas.drawLine(openEnd, centerY, end, centerY + (2f * density), track)
            return bitmap
        }

        canvas.drawLine(inset, centerY, end, centerY, track)
        val markerX = inset + ((end - inset) * remainingFraction.coerceIn(0f, 1f))
        track.color = accent
        track.strokeWidth = 1.35f * density
        canvas.drawLine(inset, centerY, markerX, centerY, track)

        val half = 2.15f * density
        val diamond = Path().apply {
            moveTo(markerX, centerY - half)
            lineTo(markerX + half, centerY)
            lineTo(markerX, centerY + half)
            lineTo(markerX - half, centerY)
            close()
        }
        canvas.drawPath(
            diamond,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = accent
                style = Paint.Style.FILL
            },
        )
        return bitmap
    }
}
