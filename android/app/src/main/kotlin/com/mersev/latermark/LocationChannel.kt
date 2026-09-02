package com.mersev.latermark

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel

/**
 * Tek seferlik konum okuması.
 *
 * **Play Services kullanılmıyor.** `FusedLocationProvider` daha isabetli bir
 * sonuç verir ama Google Play Services bağımlılığı ekler; `LocationManager`
 * işletim sisteminin parçası ve bu iş için yeterli. Aynı gerekçeyle iOS
 * tarafında da `CoreLocation` doğrudan kullanılıyor.
 *
 * Sürekli takip yok: bir sabitleme alınır ve durulur. Uygulamanın konuma
 * ihtiyacı yalnızca çekim anında var.
 */
class LocationChannel(private val activity: Activity) {

    companion object {
        const val NAME = "latermark/location"
        const val PERMISSION_REQUEST = 6041

        /** Cihaz sabitleyemezse Flutter tarafı sonsuza kadar beklemesin. */
        private const val TIMEOUT_MS = 8_000L
        /// Son sabitlemenin taze sayıldığı süre; iOS ile aynı.
        private const val CACHE_WINDOW_MS = 120_000L
    }

    private var pendingPermission: MethodChannel.Result? = null

    fun register(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasPermission())
                "requestPermission" -> requestPermission(result)
                "current" -> currentLocation(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun hasPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success(true)
            return
        }
        // Aynı anda tek istek: kullanıcı istemi kapatmadan ikinci kez sormak
        // sistem tarafından sessizce yutulur ve ilk çağrı sarkardı.
        pendingPermission?.success(false)
        pendingPermission = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
            PERMISSION_REQUEST,
        )
    }

    /** [Activity.onRequestPermissionsResult] buradan geçer. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        val granted = grantResults.isNotEmpty() &&
            grantResults.any { it == PackageManager.PERMISSION_GRANTED }
        pendingPermission?.success(granted)
        pendingPermission = null
        return true
    }

    private fun currentLocation(result: MethodChannel.Result) {
        if (!hasPermission()) {
            result.success(null)
            return
        }

        val manager =
            activity.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (manager == null) {
            result.success(null)
            return
        }

        val provider = when {
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ->
                LocationManager.GPS_PROVIDER
            manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ->
                LocationManager.NETWORK_PROVIDER
            else -> null
        }
        if (provider == null) {
            result.success(null)
            return
        }

        // Sonuç tek kez döner: zaman aşımı ile gerçek sabitleme yarışıyor ve
        // ikisi de aynı `Result`'ı kapatmaya çalışabilir.
        var settled = false
        fun settle(location: Location?) {
            if (settled) return
            settled = true
            result.success(
                location?.let {
                    mapOf("latitude" to it.latitude, "longitude" to it.longitude)
                },
            )
        }

        Handler(Looper.getMainLooper()).postDelayed({ settle(null) }, TIMEOUT_MS)

        try {
            // Sistem son sabitlemeyi zaten tutuyor. Yeterince tazeyse yeni bir
            // istek açmanın karşılığı yok: kullanıcı kaydın konumunu soruyor,
            // metre metre takip değil. iOS tarafı da aynı kuralı uyguluyor.
            @Suppress("DEPRECATION")
            val cached = manager.getLastKnownLocation(provider)
            if (cached != null &&
                System.currentTimeMillis() - cached.time <= CACHE_WINDOW_MS
            ) {
                settle(cached)
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                manager.getCurrentLocation(
                    provider,
                    CancellationSignal(),
                    activity.mainExecutor,
                ) { location -> settle(location) }
            } else {
                @Suppress("DEPRECATION")
                settle(manager.getLastKnownLocation(provider))
            }
        } catch (error: SecurityException) {
            settle(null)
        }
    }
}
