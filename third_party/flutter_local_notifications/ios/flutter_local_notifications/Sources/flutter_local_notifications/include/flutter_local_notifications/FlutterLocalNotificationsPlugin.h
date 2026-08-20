#import <Flutter/Flutter.h>
#import <UserNotifications/UserNotifications.h>

@interface FlutterLocalNotificationsPlugin : NSObject <FlutterPlugin>

/// Bildirim düğmeleri uygulamayı açmadan işlendiğinde eklenti başsız bir
/// `FlutterEngine` başlatıyor ve o motorun eklentilerini bu geri çağrıyla
/// kaydediyor.
///
/// Yöntem yukarı akışta uygulanıyor ama başlıkta bildirilmiyordu; bildirilmeyince
/// Swift göremiyor. Ayarlanmadan bırakılırsa motor `registerPlugins` nil'ken
/// çağrılıyor: hata ayıklamada `NSAssert`, yayında çökme. Bildirimi burada
/// olması gereken yere ekliyoruz — uygulama tarafında `+[FlutterPlugin
/// setPluginRegistrantCallback:]` sözleşmesinin aynısı.
+ (void)setPluginRegistrantCallback:(FlutterPluginRegistrantCallback)callback;

@end
