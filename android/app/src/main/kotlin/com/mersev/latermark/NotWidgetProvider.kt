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
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.net.Uri
import android.os.Build
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import kotlin.math.cos
import kotlin.math.min
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
        const val PHOTO = "not_photo"
    }

    private object Palette {
        const val INK = 0xFFF3F1ED.toInt()
        const val INK_FAINT = 0x52F3F1ED.toInt()
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val hasNote = widgetData.getBoolean(Keys.HAS_NOTE, false)
        val noteId = widgetData.number(Keys.NOTE_ID)

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.not_widget)

            // Android 12+ köşeleri anahat üzerinden kırpabiliyor; böylece
            // fotoğraf da yuvarlak köşelere uyuyor.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setViewOutlinePreferredRadius(
                    R.id.widget_root,
                    24f,
                    TypedValue.COMPLEX_UNIT_DIP,
                )
            }

            if (hasNote) renderNote(views, widgetData) else renderEmpty(context, views)

            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    if (hasNote && noteId > 0) Uri.parse("notapp://note/$noteId") else null,
                ),
            )

            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun renderNote(views: RemoteViews, data: SharedPreferences) {
        views.setViewVisibility(R.id.widget_empty, View.GONE)
        views.setViewVisibility(R.id.widget_content, View.VISIBLE)
        views.setViewVisibility(R.id.widget_scrim, View.VISIBLE)

        val photo = data.getString(Keys.PHOTO, null)?.let(::decodeSquare)
        if (photo != null) {
            views.setImageViewBitmap(R.id.widget_photo, photo)
            views.setViewVisibility(R.id.widget_photo, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_photo, View.GONE)
        }

        val body = data.getString(Keys.BODY, "").orEmpty()
        views.setTextViewText(R.id.widget_body, body.ifEmpty { "Notsuz kayıt" })
        views.setTextColor(
            R.id.widget_body,
            if (body.isEmpty()) Palette.INK_FAINT else Palette.INK,
        )

        views.setTextViewText(R.id.widget_date, data.getString(Keys.DATE, "").orEmpty())
        views.setTextViewText(R.id.widget_time, data.getString(Keys.TIME, "").orEmpty())

        val remaining = remainingLabel(data.number(Keys.EXPIRES_AT))
        if (remaining == null) {
            views.setViewVisibility(R.id.widget_expiry, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_expiry, View.VISIBLE)
            views.setTextViewText(R.id.widget_expiry, remaining)
        }
    }

    private fun renderEmpty(context: Context, views: RemoteViews) {
        views.setViewVisibility(R.id.widget_content, View.GONE)
        views.setViewVisibility(R.id.widget_expiry, View.GONE)
        views.setViewVisibility(R.id.widget_photo, View.GONE)
        views.setViewVisibility(R.id.widget_scrim, View.GONE)
        views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
        views.setImageViewBitmap(
            R.id.widget_aperture,
            drawAperture(context.resources.displayMetrics.density),
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

    /** Kalan süreyi kısa Türkçe biçimde verir: `2g`, `5sa`, `9dk`. */
    private fun remainingLabel(epochSeconds: Long): String? {
        if (epochSeconds <= 0L) return null
        val left = epochSeconds - System.currentTimeMillis() / 1000
        return when {
            left <= 0 -> "şimdi"
            left >= 86_400 -> "${left / 86_400}g"
            left >= 3_600 -> "${left / 3_600}sa"
            left >= 60 -> "${left / 60}dk"
            else -> "<1dk"
        }
    }

    /**
     * Kareyi ortadan kare olarak kırpar.
     *
     * Widget her oranda olabildiği için `centerCrop` yeterli olurdu; kare
     * kırpmak, çok geniş kutularda konunun kenara kaçmasını engelliyor.
     */
    private fun decodeSquare(path: String): Bitmap? {
        val source = BitmapFactory.decodeFile(path) ?: return null
        val size = min(source.width, source.height)
        if (size == source.width && size == source.height) return source

        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val left = (source.width - size) / 2
        val top = (source.height - size) / 2
        canvas.drawBitmap(
            source,
            Rect(left, top, left + size, top + size),
            RectF(0f, 0f, size.toFloat(), size.toFloat()),
            Paint(Paint.FILTER_BITMAP_FLAG),
        )
        source.recycle()
        return output
    }

    /**
     * Boş durumdaki diyafram nişanı.
     *
     * Geometri Flutter ve SwiftUI taraflarıyla aynı: açıklık düzgün bir
     * çokgen, bıçak kenarları bu çokgenin kenarlarının dış çembere uzatılması.
     */
    private fun drawAperture(density: Float): Bitmap {
        val size = (58 * density).toInt().coerceAtLeast(58)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val center = size / 2f
        val outer = size / 2f - 1f
        val blades = 7
        val inradius = outer * 0.63f
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
                    0x59FF7A55, 0x00FF7A55, Shader.TileMode.CLAMP,
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
}
