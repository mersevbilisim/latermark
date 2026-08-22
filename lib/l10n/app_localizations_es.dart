// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class L10nEs extends L10n {
  L10nEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Latermark';

  @override
  String get actionSave => 'Guardar';

  @override
  String get composeSaving => 'Guardando';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionClose => 'Cerrar';

  @override
  String get actionBack => 'Atrás';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionMore => 'Más';

  @override
  String get openPhotoSemantic => 'Abrir la foto en pantalla completa';

  @override
  String get actionRetry => 'Volver a intentar';

  @override
  String get actionGoBack => 'Volver';

  @override
  String get actionOpen => 'Abrir';

  @override
  String get settingsAction => 'Ajustes';

  @override
  String get shutterSemantic => 'Hacer una foto';

  @override
  String get searchHint => 'Buscar';

  @override
  String searchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados',
      one: '$count resultado',
    );
    return '$_temp0';
  }

  @override
  String get searchEmpty => 'Eşleşen kayıt yok';

  @override
  String get searchCancel => 'Vazgeç';

  @override
  String get searchInPhoto => 'karede';

  @override
  String get notesTitle => 'Notas';

  @override
  String get dateGroupToday => 'Hoy';

  @override
  String get dateGroupYesterday => 'Ayer';

  @override
  String get dateGroupPastWeek => 'Últimos 7 días';

  @override
  String get dateGroupPastMonth => 'Último mes';

  @override
  String get dateGroupPastThreeMonths => 'Últimos 3 meses';

  @override
  String get dateGroupPastYear => 'Último año';

  @override
  String get dateGroupOlder => 'Hace más de un año';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas',
      one: '1 nota',
      zero: 'Sin notas',
    );
    return '$_temp0';
  }

  @override
  String get noteWithoutBody => 'Sin nota';

  @override
  String get inviteTitle => 'Toca para capturar';

  @override
  String get inviteBody =>
      'Un recibo, dónde aparcaste, un detalle…\nHaz una foto, añade unas palabras y sigue.';

  @override
  String get pickFromGallery => 'Elegir de Fotos';

  @override
  String get pickFromGallerySemantic => 'Elegir una foto de la fototeca';

  @override
  String get galleryPickerOpening => 'Abriendo el selector de fotos';

  @override
  String get manifestoFirst => 'Simple';

  @override
  String get manifestoSecond => 'Privado';

  @override
  String get manifestoThird => 'Tuyo';

  @override
  String get switchToLargeView => 'Cambiar a vista grande';

  @override
  String get switchToGridView => 'Cambiar a cuadrícula';

  @override
  String get toastPhotoPickFailed =>
      'No se pudo seleccionar esa foto. Inténtalo de nuevo.';

  @override
  String get toastPendingPickFailed =>
      'No se pudo recuperar la selección interrumpida.';

  @override
  String get toastSharedPhotoAdded => 'Foto compartida añadida.';

  @override
  String get toastSharedPhotoFailed =>
      'No se pudo añadir la foto compartida. Lo intentaremos de nuevo.';

  @override
  String get toastDeleteFailed => 'No se pudo eliminar. Inténtalo de nuevo.';

  @override
  String get toastSaveFailed => 'No se pudo guardar. Inténtalo de nuevo.';

  @override
  String get toastEditFailed => 'No se pudieron guardar los cambios.';

  @override
  String get toastPermissionDenied =>
      'Las notificaciones están desactivadas. Los recordatorios permanecerán en silencio.';

  @override
  String get deleteConfirmTitle => '¿Eliminar esta captura?';

  @override
  String get deleteConfirmCaption => 'La foto y la nota se eliminarán juntas.';

  @override
  String get holdToDelete => 'Mantén pulsado para eliminar';

  @override
  String get holdStageAlmost => 'Ya casi';

  @override
  String get holdStageRelease => 'Sigue pulsando…';

  @override
  String get holdStageGone => 'Eliminada';

  @override
  String get cameraNotFoundTitle => 'Cámara no disponible';

  @override
  String get cameraNotFoundBody =>
      'Este dispositivo no tiene una cámara disponible.';

  @override
  String get cameraDeniedTitle => 'Acceso a la cámara desactivado';

  @override
  String get cameraDeniedBody =>
      'Permite el acceso en Ajustes › Latermark para hacer fotos aquí.';

  @override
  String get cameraFailedTitle => 'No se pudo abrir la cámara';

  @override
  String get cameraFailedBody => 'Ha ocurrido algo inesperado.';

  @override
  String get switchLens => 'Cambiar de cámara';

  @override
  String flashSemantic(String state) {
    return 'Flash: $state';
  }

  @override
  String get flashOff => 'desactivado';

  @override
  String get flashAuto => 'automático';

  @override
  String get flashOn => 'activado';

  @override
  String get composeHint => '¿Por qué hiciste esta foto?';

  @override
  String get composeReminderDescription =>
      'Recupera esta captura el día que elijas.';

  @override
  String get composeLocationDescription =>
      'Asocia tu ubicación actual únicamente a esta captura.';

  @override
  String get composeLocationResolving => 'Obteniendo tu ubicación…';

  @override
  String get composeLocationReady =>
      'La ubicación está lista para esta captura.';

  @override
  String get composeLocationPermissionRequired =>
      'Se necesita permiso de ubicación.';

  @override
  String get composeAnotherPhoto => 'Elegir otra foto';

  @override
  String get composeRetake => 'Repetir';

  @override
  String get sourceGallery => 'FOTOS';

  @override
  String get sourceShared => 'COMPARTIDA';

  @override
  String get reminderLabel => 'Recordarme';

  @override
  String get addedLabel => 'Fecha de adición';

  @override
  String get lastUpdatedLabel => 'Última actualización';

  @override
  String get locationLabel => 'Ubicación';

  @override
  String get locationAddLabel => 'Añadir ubicación';

  @override
  String get locationBlocked =>
      'Añadir la ubicación depende de tu permiso. Permite el acceso a la ubicación para registrar dónde se hizo la foto.';

  @override
  String get compassNorth => 'N';

  @override
  String get compassSouth => 'S';

  @override
  String get compassEast => 'E';

  @override
  String get compassWest => 'O';

  @override
  String get toastMapFailed => 'No se pudo abrir Mapas';

  @override
  String get reminderSuffixActive => 'días después';

  @override
  String get reminderSuffixOff => 'días — desactivado';

  @override
  String get backupSectionTitle => 'Copia de seguridad';

  @override
  String get backupManageTitle => 'Gestionar copias';

  @override
  String get backupManageDescription =>
      'Crea una copia cifrada o restaura una copia existente.';

  @override
  String get backupCreateTitle => 'Crear una copia';

  @override
  String get backupNothingToSave => 'Todavía no hay nada que copiar.';

  @override
  String get backupCreateDescription =>
      'Todo lo de este dispositivo, sellado en un archivo cifrado.';

  @override
  String get backupRestoreTitle => 'Restaurar una copia';

  @override
  String get backupRestoreDescription =>
      'Reemplaza todo lo de aquí con un archivo de copia.';

  @override
  String get backupPasswordTitle => 'Elige una contraseña';

  @override
  String get backupPasswordSubtitle =>
      'Esta contraseña es la única llave de tu copia.';

  @override
  String get backupPasswordLabel => 'Contraseña';

  @override
  String get backupPasswordRepeat => 'Repite la contraseña';

  @override
  String get backupPasswordMismatch => 'Las dos contraseñas no coinciden.';

  @override
  String backupPasswordShort(int count) {
    return 'Usa al menos $count caracteres.';
  }

  @override
  String get backupStrengthWeak => 'Débil';

  @override
  String get backupStrengthFair => 'Media';

  @override
  String get backupStrengthStrong => 'Fuerte';

  @override
  String get backupLossWarning =>
      'Entiendo que si pierdo esta contraseña, esta copia no podrá abrirse nunca.';

  @override
  String get backupActionCreate => 'Crear copia';

  @override
  String get backupPhasePreparing => 'Preparando';

  @override
  String get backupPhaseKey => 'Derivando clave';

  @override
  String get backupPhaseWriting => 'Cifrando';

  @override
  String get backupPhaseReading => 'Descifrando';

  @override
  String get backupPhaseVerifying => 'Verificando';

  @override
  String get backupPhaseApplying => 'Restaurando';

  @override
  String backupItems(int done, int total) {
    return '$done de $total';
  }

  @override
  String get backupReadyTitle => 'Tu copia está lista';

  @override
  String backupReadySubtitle(int notes, int photos) {
    return '$notes notas y $photos fotos, cifradas.';
  }

  @override
  String get backupActionSave => 'Guardar en este dispositivo';

  @override
  String get backupSavedToDevice => 'Guardado.';

  @override
  String get backupPickFile => 'Elegir un archivo';

  @override
  String get backupUnlockTitle => 'Introduce la contraseña';

  @override
  String get backupUnlockSubtitle =>
      'La contraseña que elegiste al crear esta copia.';

  @override
  String get backupFoundTitle => 'Copia encontrada';

  @override
  String backupFoundCounts(int notes, int photos) {
    return '$notes notas, $photos fotos';
  }

  @override
  String backupFoundDate(String when) {
    return 'Creada el $when';
  }

  @override
  String get backupReplaceWarning =>
      'Restaurar reemplaza todas las notas y fotos de este dispositivo. No se puede deshacer.';

  @override
  String get backupReplaceAcknowledge =>
      'Entiendo que mis datos actuales se borrarán.';

  @override
  String get backupActionRestore => 'Restaurar';

  @override
  String get backupRestoredTitle => 'Todo ha vuelto.';

  @override
  String get backupErrorWrongPassword => 'Contraseña incorrecta.';

  @override
  String get backupErrorNotABackup => 'Esto no es una copia de Latermark.';

  @override
  String get backupErrorCorrupt => 'Este archivo está dañado o incompleto.';

  @override
  String get backupErrorUnsupported =>
      'Esta copia se hizo con una versión más reciente de Latermark.';

  @override
  String get backupErrorGeneric => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get paywallFeatureBackup => 'Copia cifrada';

  @override
  String get paywallFeatureBackupDetail =>
      'Lleva tus notas y fotos a un teléfono nuevo.';

  @override
  String get reminderSuffixRepeating => 'días · se repite';

  @override
  String get reminderRepeatToggle => 'Repetir recordatorio';

  @override
  String get reminderRepeatOnce => 'Se recuerda una vez.';

  @override
  String get reminderRepeatNeedsInterval =>
      'Introduce primero el número de días.';

  @override
  String reminderRepeatSummary(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Se recuerda cada $days días.',
      one: 'Se recuerda cada día.',
    );
    return '$_temp0';
  }

  @override
  String reminderRepeatingValue(int days, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Cada $days días · siguiente $when',
      one: 'Cada día · siguiente $when',
    );
    return '$_temp0';
  }

  @override
  String get reminderBlocked =>
      'Las notificaciones están desactivadas. La captura se guardará igualmente; el recordatorio empezará a funcionar cuando las permitas.';

  @override
  String get editNoteSemantic => 'Editar nota';

  @override
  String get editSheetHeader => 'EDITAR NOTA';

  @override
  String get retentionSelectorTitle => 'Eliminación automática';

  @override
  String get retentionOffNotice =>
      'La eliminación automática está desactivada — esta captura seguirá aquí hasta que la elimines.';

  @override
  String get retentionCustom => 'Personalizado';

  @override
  String get retentionCustomTitle => 'Duración personalizada';

  @override
  String retentionCustomHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count horas',
      one: '1 hora',
    );
    return '$_temp0';
  }

  @override
  String retentionCustomDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String retentionCustomWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semanas',
      one: '1 semana',
    );
    return '$_temp0';
  }

  @override
  String get retentionUnitHours => 'Horas';

  @override
  String get retentionUnitDays => 'Días';

  @override
  String get retentionUnitWeeks => 'Semanas';

  @override
  String get retentionCustomDescription =>
      'La captura se eliminará automáticamente al terminar este tiempo.';

  @override
  String get retentionOff => 'Desactivado';

  @override
  String get retentionThreeDays => '3 días';

  @override
  String get retentionOneWeek => '1 semana';

  @override
  String get retentionOffDescription => 'Desactivado';

  @override
  String get retentionThreeDaysDescription => 'Se elimina a los 3 días';

  @override
  String get retentionOneWeekDescription => 'Se elimina tras 1 semana';

  @override
  String get legalPrivacy => 'Privacidad';

  @override
  String get legalTerms => 'Términos de uso';

  @override
  String get yourDataTitle => 'Latermark y tus datos';

  @override
  String get yourDataSubtitle =>
      'Tu privacidad nos importa. Por eso la tratamos con respeto.';

  @override
  String get yourDataSafetyQuestion => '¿Están seguros mis datos?';

  @override
  String get yourDataSafetyAnswer =>
      'Latermark funciona íntegramente en tu dispositivo. Tus notas y recuerdos no se envían para análisis, informes de fallos ni estadísticas. Solo salen del dispositivo cuando tú decides compartirlos.';

  @override
  String get yourDataLocationQuestion =>
      '¿Por qué se solicita acceso a mi ubicación?';

  @override
  String get yourDataLocationAnswer =>
      'El permiso solo se solicita si decides añadir una ubicación a una nota o recuerdo. Esa ubicación queda asociada únicamente a esa entrada; no hay seguimiento en segundo plano. Solo se envía a tu app de mapas si decides abrir el mapa.';

  @override
  String get yourDataPhotosQuestion =>
      '¿Para qué necesita Latermark acceso a mis fotos?';

  @override
  String get yourDataPhotosAnswer =>
      'Solo para que puedas elegir una imagen de tu fototeca en lugar de tomar una nueva. Latermark incorpora únicamente la imagen seleccionada y no necesita conexión a internet para hacerlo.';

  @override
  String get yourDataRemindersQuestion => '¿Cómo funcionan los recordatorios?';

  @override
  String get yourDataRemindersAnswer =>
      'Se programan y se muestran de forma local en tu dispositivo. Ningún servidor externo los envía ni los activa.';

  @override
  String get yourDataDeletionQuestion => '¿Qué ocurre si elimino la app?';

  @override
  String get yourDataDeletionAnswer =>
      'Las notas, imágenes importadas y ubicaciones guardadas en Latermark se eliminan de forma permanente. Tus fotos de la fototeca y los datos de otras apps no se ven afectados.';

  @override
  String get legalOpenFailed => 'No se pudo abrir el enlace.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get sectionAppearance => 'Apariencia';

  @override
  String get sectionReminder => 'Recordatorios';

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeDescription =>
      'Sigue la apariencia del sistema o elige una para mantener.';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get appColorTitle => 'Color de la app';

  @override
  String get appColorDescription =>
      'Elige el color de acento de los controles y elementos destacados.';

  @override
  String get accentOrange => 'Naranja';

  @override
  String get accentBlue => 'Azul';

  @override
  String get accentViolet => 'Violeta';

  @override
  String get accentPink => 'Rosa';

  @override
  String get accentGreen => 'Verde';

  @override
  String get accentGold => 'Dorado';

  @override
  String get retentionTitle => 'Eliminación automática';

  @override
  String get retentionDescription =>
      'Las nuevas capturas usarán esta duración. Puedes cambiarla en los detalles de cada captura.';

  @override
  String get feedTitle => 'Vista';

  @override
  String get feedDescription =>
      'Muestra capturas grandes o encaja más en una cuadrícula.';

  @override
  String get densityLarge => 'Grande';

  @override
  String get densityGrid => 'Cuadrícula';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageDescription =>
      'Latermark sigue el idioma del dispositivo, aunque puedes elegir otro.';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get remindersTitle => 'Recordatorios';

  @override
  String get remindersDescription =>
      'Solo recibirás avisos de las capturas para las que fijes un plazo al guardar. Las demás permanecerán en silencio.';

  @override
  String get remindersBlockedDescription =>
      'Las notificaciones están desactivadas en los ajustes del sistema. Los recordatorios volverán cuando las permitas.';

  @override
  String get openSystemSettings => 'Abrir ajustes del sistema';

  @override
  String get openSettingsShort => 'Abrir Ajustes';

  @override
  String versionMark(String version, String build) {
    return 'Versión $version ($build)';
  }

  @override
  String get dayToday => 'Hoy';

  @override
  String get dayYesterday => 'Ayer';

  @override
  String get relativeJustNow => 'ahora mismo';

  @override
  String relativeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String relativeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h',
      one: '1 h',
    );
    return '$_temp0';
  }

  @override
  String get relativeYesterday => 'ayer';

  @override
  String relativeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get remainingNow => 'ahora';

  @override
  String remainingShortDays(int count) {
    return '$count d';
  }

  @override
  String remainingShortHours(int count) {
    return '$count h';
  }

  @override
  String remainingShortMinutes(int count) {
    return '$count min';
  }

  @override
  String get remainingShortLessThanMinute => '<1 min';

  @override
  String get remainingSoon => 'Se eliminará en breve';

  @override
  String remainingLongDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Se eliminará en $days días',
      one: 'Se eliminará en 1 día',
    );
    return '$_temp0';
  }

  @override
  String remainingLongDaysHours(int days, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '1 día',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours horas',
      one: '1 hora',
    );
    return 'Se eliminará en $_temp0 y $_temp1';
  }

  @override
  String remainingLongHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Se eliminará en $hours horas',
      one: 'Se eliminará en 1 hora',
    );
    return '$_temp0';
  }

  @override
  String remainingLongHoursMinutes(int hours, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours horas',
      one: '1 hora',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutos',
      one: '1 minuto',
    );
    return 'Se eliminará en $_temp0 y $_temp1';
  }

  @override
  String remainingLongMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Se eliminará en $minutes minutos',
      one: 'Se eliminará en 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String paywallLimitTitle(int limit) {
    return 'Tus $limit espacios están ocupados';
  }

  @override
  String paywallLimitBody(int limit) {
    return 'La versión gratuita conserva hasta $limit capturas a la vez. Pro elimina el límite — o puedes borrar una captura para continuar.';
  }

  @override
  String get paywallLimitDelete => 'Eliminar una captura';

  @override
  String paywallCounter(int count, int limit) {
    return '$count/$limit';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get paywallHeadline => 'Hay capturas que merecen quedarse.';

  @override
  String get paywallSubtitle =>
      'Latermark está hecho para dejar ir. Pro, para aquello que quieres conservar.';

  @override
  String paywallOwnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ahora tienes $count capturas.',
      one: 'Ahora tienes 1 captura.',
    );
    return '$_temp0';
  }

  @override
  String get paywallFeatureUnlimited => 'Capturas ilimitadas';

  @override
  String paywallFeatureUnlimitedDetail(int limit) {
    return 'La versión gratuita conserva hasta $limit.';
  }

  @override
  String get paywallFeatureCustomRetention => 'Elige cualquier duración';

  @override
  String get paywallFeatureCustomRetentionDetail =>
      'Más allá de 3 días o 1 semana.';

  @override
  String get paywallFeatureReminders => 'Recordatorios';

  @override
  String get paywallFeatureRemindersDetail =>
      'Un aviso discreto para lo importante.';

  @override
  String get paywallFeatureWidget => 'Widgets de inicio y pantalla bloqueada';

  @override
  String get paywallFeatureWidgetDetail =>
      'Tu última captura, siempre a la vista.';

  @override
  String paywallPrice(String price) {
    return '$price';
  }

  @override
  String get paywallOneTime => 'Compra única';

  @override
  String get paywallNoSubscription =>
      'Sin suscripción. Paga una vez y conserva Pro.';

  @override
  String get paywallOwned => 'Latermark Pro es tuyo.';

  @override
  String get paywallFeatureNoSubscription => 'Sin suscripción';

  @override
  String get paywallFeatureNoSubscriptionDetail =>
      'La mayoría de apps cobran cada mes. Latermark no.';

  @override
  String get paywallCta => 'Desbloquear Pro';

  @override
  String get paywallRestore => 'Restaurar compras';

  @override
  String get paywallRestoreNotFound =>
      'No se encontró ninguna compra anterior de Latermark Pro.';

  @override
  String get paywallRestoreFailed =>
      'No se pudieron restaurar las compras. Inténtalo de nuevo.';

  @override
  String get paywallClose => 'Cerrar';

  @override
  String get paywallLifeFree => 'Gratis';

  @override
  String get paywallLifePro => 'Pro';

  @override
  String get notificationTitle => 'Recordatorio';

  @override
  String get notificationTitleNoBody => 'Hay una captura esperando';

  @override
  String get notificationBodyNoBody =>
      'Pediste que te recordáramos esta captura.';

  @override
  String get notificationChannelName => 'Recordatorios';

  @override
  String get notificationChannelDescription =>
      'Te avisa de las capturas que hayas programado.';

  @override
  String get reminderActionDone => 'Hecho';

  @override
  String get reminderActionTomorrow => 'Mañana';

  @override
  String get reminderActionNextWeek => 'La próxima semana';

  @override
  String get reminderActionTurnOff => 'Desactivar este recordatorio';

  @override
  String get actionOK => 'Aceptar';

  @override
  String get widgetDescription => 'Muestra tu última captura y su nota.';

  @override
  String get widgetEmptySubtitle => 'Tu primera nota aparecerá aquí';

  @override
  String get widgetPhotoDescription => 'Foto de tu última captura';

  @override
  String get widgetLeaveTrace => 'Deja una nueva huella';

  @override
  String get widgetOpenApp => 'Abrir Latermark';

  @override
  String get widgetCreateNote => 'Crear una nota';

  @override
  String get widgetLeaveFirstTrace => 'Deja tu primera huella';

  @override
  String get widgetProRequired =>
      'Los widgets están disponibles con Latermark Pro.';

  @override
  String get widgetPreviewNote => 'Enviar a Contabilidad';

  @override
  String get widgetPreviewDay => 'HOY';

  @override
  String get shareComposeHint => '¿Por qué quieres guardar esta foto?';

  @override
  String get shareErrorTitle => 'No se pudo añadir la foto';

  @override
  String get shareErrorBody =>
      'No se pudo enviar la foto a Latermark. Inténtalo de nuevo.';

  @override
  String get cameraUsageDescription =>
      'El acceso a la cámara te permite hacer fotos para tus notas.';

  @override
  String get photoLibraryUsageDescription =>
      'El acceso a Fotos te permite añadir imágenes de tu fototeca a las notas.';

  @override
  String get actionShare => 'Compartir';

  @override
  String get shareNoteSemantic => 'Compartir foto y nota';
}
