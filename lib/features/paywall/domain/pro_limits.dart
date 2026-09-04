import '../../notes/domain/note_reminder.dart';

/// Ücretsiz katmanın sınırları.
///
/// Tek yerde toplu duruyorlar: sayılar koda dağılırsa hem değiştirmek zorlaşır
/// hem de paywall'da yazan sayı ile gerçekte uygulanan sayı zamanla ayrışır.
///
/// Sınırların tasarım kuralı:
///
/// * **Kullanıcının yaptığı hiçbir şey paywall yüzünden silinmez veya
///   gizlenmez.** Sınır yalnızca *yeni* kayda uygulanır; mevcut kareler her
///   zaman açılabilir, düzenlenebilir, dışa aktarılabilir.
/// * **Sınır aynı andadır, toplam değil.** Kümülatif sayaç, otomatik silmeyi
///   kullanan kullanıcıyı elinde sıfır kare varken "dolu" durumuna düşürürdü —
///   yani uygulamayı tasarlandığı gibi kullandığı için cezalandırırdı.
/// * **Ücretsiz katman süresiz kullanılabilir kalır.** Bir kare silmek yer
///   açar; kullanıcı ödemeden de uygulamaya devam edebilir.

abstract final class ProLimits {
  /// Ücretsiz katmanda aynı anda tutulabilecek kare sayısı.
  ///
  /// Sayı burada tek yerde duruyor ve arayüzdeki her metin onu buradan
  /// okuyor — paywall başlığı dahil. Eskiden başlıkta sabit "10" yazıyordu ve
  /// sınır değiştiğinde ekran yalan söylemeye başlıyordu.
  static const freeNotes = 5;

  /// Sayacın göründüğü son kare sayısı.
  ///
  /// Sınırın kaçta kaçında uyarılacağı orantılı olmalı: on karede son üçte
  /// uyarmak makul bir eşikti, beş karede aynı mutlak mesafe kullanıcıyı
  /// arşivi yarısına gelmeden sıkıştırırdı.
  static const counterWindow = 2;

  /// Kullanıcı bu sayıya ulaştığında yeni çekim paywall'a yönlenir.
  static bool blocksNewNote(int noteCount, {required bool isPro}) =>
      !isPro && noteCount >= freeNotes;

  /// Sınıra yaklaşıldı mı? Deklanşörün altında sayaç göstermek için.
  ///
  /// Kullanıcı duvara habersiz toslamamalı; son birkaç karede sayaç görünür.
  static bool showsCounter(int noteCount, {required bool isPro}) =>
      !isPro && noteCount >= freeNotes - counterWindow;

  /// Ücretsiz katmanda ömür boyu kurulabilecek hatırlatma sayısı.
  ///
  /// Ücretsiz kullanıcının ürünü **yaşayabilmesi** için var. Uygulamanın sözü
  /// "yaz ve unut"; o sözün karşılığı kaydetmek değil, kaydın doğru anda geri
  /// gelmesi. O an tümden paywall'ın arkasındayken kullanıcı hiç yaşamadığı
  /// bir şey için ödemeye çağrılıyordu.
  ///
  /// Sayı **süre değil adet**: değer, hatırlatma çaldığında doğuyor. Yedi
  /// günlük bir deneme, onuncu güne kurulmuş bir hatırlatmayı hiç göstermez.
  /// Ölçünün birimi tamamlanmış turdur.
  static const freeReminders = 2;

  /// Ücretsiz hatırlatma hakkı açık mı.
  ///
  /// [freeReminders] sıfırlandığında özellik tümden kapanır ve hatırlatma
  /// eskisi gibi yalnız Pro'ya ait olur — tek sabitle geri alınabilen bir
  /// kapatma anahtarı.
  ///
  /// Kapalıyken **kotadan hiç söz edilmiyor**. "Hakkın doldu" demek, hiç hakkı
  /// olmamış birine olmayan bir şeyi kaybettirmek olurdu; o hâlde ekran da
  /// Siri de sade Pro kapısına dönüyor.
  static bool get freeRemindersEnabled => freeReminders > 0;

  /// Hatırlatma altyapısı bu katmanda kullanılabilir mi.
  ///
  /// Bu soru kotadan farklıdır: hakkı bitmiş bir Free kullanıcı daha önce
  /// hakkını yakmış bir kaydı yeniden kurabilir ve ana şalteri kapatıp açabilir.
  /// Kaç yeni kayıt kurulabileceğine [allowsReminder] karar verir; servis ve
  /// ayarlar yalnız özelliğin katmana bütünüyle açık olup olmadığını sorar.
  static bool remindersAvailable({required bool isPro}) =>
      isPro || freeRemindersEnabled;

  /// Bu kayda hatırlatma kurulabilir mi.
  ///
  /// [usedNoteIds] hakkı **yakmış** kayıtların kimlikleri: bildirimi çalmış
  /// olanlar. [inFlight] henüz çalmamış ama kurulu duran hatırlatma sayısı —
  /// [noteId] kendisi buna dahil edilmez.
  ///
  /// Hak kurulumda değil **teslimde** yanıyor: kullanıcı kurup vazgeçtiyse
  /// ortada teslim edilmiş bir değer yok, hak da durur. Ama kurulu olanlar
  /// kapıya dahil; aksi hâlde hiçbiri çalmadan on tane kurup hepsini bedavaya
  /// almak mümkün olurdu.
  ///
  /// Zaten hakkını yakmış bir kayıt **yeniden ücretlendirilmiyor**: kullanıcının
  /// kendi kurduğu hatırlatmayı kapatıp açması, saatini değiştirmesi ya da
  /// bildirimden ertelemesi ikinci bir hak yemez.
  /// [burnedFloor] yeniden kurulumdan sonra da duran hak tabanı: kimlik
  /// listesi kuruluma özel olduğu için silip yeniden kuran kullanıcıda boş
  /// başlıyor, taban ise cihazda kalıyor.
  static bool allowsReminder({
    required bool isPro,
    required Set<int> usedNoteIds,
    int inFlight = 0,
    int burnedFloor = 0,
    int? noteId,
  }) {
    if (isPro) return true;
    if (!freeRemindersEnabled) return false;
    if (noteId != null && usedNoteIds.contains(noteId)) return true;
    return burnedCount(usedNoteIds, burnedFloor) + inFlight < freeReminders;
  }

  /// Harcanmış hak: listedeki kayıt sayısı ile silinmeyen tabandan büyük olan.
  static int burnedCount(Set<int> usedNoteIds, int burnedFloor) =>
      usedNoteIds.length > burnedFloor ? usedNoteIds.length : burnedFloor;

  /// Ücretsiz katmanda tekrar **yok**.
  ///
  /// Hak "iki bildirim" demek. Tekrarlı bir hatırlatma tek hakla sınırsız
  /// bildirim üretir: günlük tekrar kuran bir kullanıcı bir slotla ömür boyu
  /// hatırlatma alır ve sayının hiçbir anlamı kalmaz. Ritim bu yüzden Pro'da.
  static ReminderCadence effectiveCadence(
    ReminderCadence cadence, {
    required bool isPro,
  }) => isPro ? cadence : ReminderCadence.once;

  /// Ücretsiz katmanda kalan hatırlatma hakkı.
  ///
  /// Kurulu ama henüz çalmamış olanlar da düşülüyor: kullanıcıya "2 hakkın
  /// var" deyip ikincisini kurdurmamak olmaz.
  static int remainingReminders(
    Set<int> usedNoteIds, {
    int inFlight = 0,
    int burnedFloor = 0,
  }) {
    final left =
        freeReminders - burnedCount(usedNoteIds, burnedFloor) - inFlight;
    return left < 0 ? 0 : left;
  }
}
