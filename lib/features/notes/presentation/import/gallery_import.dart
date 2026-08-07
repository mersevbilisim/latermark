import 'package:image_picker/image_picker.dart';

/// iOS ve Android'in kendi fotoğraf seçicisine açılan tek kapı.
///
/// Seçici orijinal galeri varlığını değiştirmez; uygulamaya geçici bir
/// [XFile] verir. Latermark kayıt sırasında bunu kendi kalıcı klasörüne
/// kopyalar.
abstract final class GalleryImport {
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pick() => _picker.pickImage(
    source: ImageSource.gallery,
    // Konum ve tam EXIF verisine ihtiyacımız yok. iOS böylece fotoğraf
    // kitaplığının tamamına erişim istemeden sistem seçicisini kullanabilir.
    requestFullMetadata: false,
  );

  /// Android, sistem seçicisi açıkken uygulamayı bellekten atabilir.
  /// Sonuç bu durumda ilk Future'a dönmez; açılışta buradan geri alınır.
  static Future<XFile?> recover() async {
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return null;

    final files = response.files;
    if (files != null && files.isNotEmpty) return files.first;

    final exception = response.exception;
    if (exception != null) throw exception;
    return null;
  }
}
