/// Sistem paylaşım sayfasına verilen metin.
library;

/// Notun yazısı ve —açıksa— uygulamanın imzası.
///
/// İkisi de yoksa `null` döner: paylaşımda boş bir metin göndermek, alıcı
/// tarafta boş bir satır demek.
///
/// İmza notun **arkasına**, boş bir satır bırakılarak ekleniyor. Kullanıcının
/// cümlesiyle aynı paragrafta durursa imza da onun yazdığı bir şey gibi
/// okunuyor; arada boşluk olunca künye gibi duruyor.
String? shareMessage({required String body, String? signature}) {
  final text = body.trim();
  final mark = signature?.trim();
  final parts = [
    if (text.isNotEmpty) text,
    if (mark != null && mark.isNotEmpty) '— $mark',
  ];
  return parts.isEmpty ? null : parts.join('\n\n');
}
