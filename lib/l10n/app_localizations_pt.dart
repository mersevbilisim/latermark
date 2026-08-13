// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class L10nPt extends L10n {
  L10nPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Latermark';

  @override
  String get actionSave => 'Guardar';

  @override
  String get composeSaving => 'A guardar';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionClose => 'Fechar';

  @override
  String get actionBack => 'Voltar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionMore => 'Mais';

  @override
  String get openPhotoSemantic => 'Abrir a foto em ecrã inteiro';

  @override
  String get actionRetry => 'Tentar novamente';

  @override
  String get actionGoBack => 'Voltar';

  @override
  String get actionOpen => 'Abrir';

  @override
  String get settingsAction => 'Definições';

  @override
  String get shutterSemantic => 'Tirar uma fotografia';

  @override
  String get searchHint => 'Pesquisar';

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
  String get dateGroupToday => 'Hoje';

  @override
  String get dateGroupYesterday => 'Ontem';

  @override
  String get dateGroupPastWeek => 'Últimos 7 dias';

  @override
  String get dateGroupPastMonth => 'Último mês';

  @override
  String get dateGroupPastThreeMonths => 'Últimos 3 meses';

  @override
  String get dateGroupPastYear => 'Último ano';

  @override
  String get dateGroupOlder => 'Há mais de um ano';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas',
      one: '1 nota',
      zero: 'Sem notas',
    );
    return '$_temp0';
  }

  @override
  String get noteWithoutBody => 'Sem nota';

  @override
  String get inviteTitle => 'Toque para fotografar';

  @override
  String get inviteBody =>
      'Um recibo, o lugar onde estacionou, um detalhe…\nFotografe, acrescente algumas palavras e siga.';

  @override
  String get pickFromGallery => 'Escolher de Fotografias';

  @override
  String get pickFromGallerySemantic => 'Escolher uma fotografia da biblioteca';

  @override
  String get galleryPickerOpening => 'A abrir o seletor de fotografias';

  @override
  String get manifestoFirst => 'Simples';

  @override
  String get manifestoSecond => 'Privado';

  @override
  String get manifestoThird => 'Seu';

  @override
  String get switchToLargeView => 'Mudar para vista grande';

  @override
  String get switchToGridView => 'Mudar para grelha';

  @override
  String get toastPhotoPickFailed =>
      'Não foi possível selecionar essa fotografia. Tente novamente.';

  @override
  String get toastPendingPickFailed =>
      'Não foi possível recuperar a seleção interrompida.';

  @override
  String get toastSharedPhotoAdded => 'Fotografia partilhada adicionada.';

  @override
  String get toastSharedPhotoFailed =>
      'Não foi possível adicionar a fotografia partilhada. Voltaremos a tentar.';

  @override
  String get toastDeleteFailed => 'Não foi possível eliminar. Tente novamente.';

  @override
  String get toastSaveFailed => 'Não foi possível guardar. Tente novamente.';

  @override
  String get toastEditFailed => 'Não foi possível guardar as alterações.';

  @override
  String get toastPermissionDenied =>
      'As notificações estão desativadas. Os lembretes ficarão em silêncio.';

  @override
  String get deleteConfirmTitle => 'Eliminar esta captura?';

  @override
  String get deleteConfirmCaption =>
      'A fotografia e a nota serão eliminadas em conjunto.';

  @override
  String get holdToDelete => 'Mantenha premido para eliminar';

  @override
  String get holdStageAlmost => 'Quase';

  @override
  String get holdStageRelease => 'Continue a premir…';

  @override
  String get holdStageGone => 'Eliminada';

  @override
  String get cameraNotFoundTitle => 'Câmara indisponível';

  @override
  String get cameraNotFoundBody =>
      'Não existe uma câmara disponível neste dispositivo.';

  @override
  String get cameraDeniedTitle => 'Acesso à câmara desativado';

  @override
  String get cameraDeniedBody =>
      'Permita o acesso em Definições › Latermark para tirar fotografias aqui.';

  @override
  String get cameraFailedTitle => 'Não foi possível abrir a câmara';

  @override
  String get cameraFailedBody => 'Ocorreu algo inesperado.';

  @override
  String get switchLens => 'Mudar de câmara';

  @override
  String flashSemantic(String state) {
    return 'Flash: $state';
  }

  @override
  String get flashOff => 'desativado';

  @override
  String get flashAuto => 'automático';

  @override
  String get flashOn => 'ativado';

  @override
  String get composeHint => 'Porque tirou esta fotografia?';

  @override
  String get composeReminderDescription =>
      'Recupere esta captura no dia que escolher.';

  @override
  String get composeLocationDescription =>
      'Associa a sua localização atual apenas a esta captura.';

  @override
  String get composeLocationResolving => 'A obter a sua localização…';

  @override
  String get composeLocationReady =>
      'A localização está pronta para esta captura.';

  @override
  String get composeLocationPermissionRequired =>
      'É necessária permissão de localização.';

  @override
  String get composeAnotherPhoto => 'Escolher outra fotografia';

  @override
  String get composeRetake => 'Repetir';

  @override
  String get sourceGallery => 'FOTOGRAFIAS';

  @override
  String get sourceShared => 'PARTILHADA';

  @override
  String get reminderLabel => 'Lembrar-me';

  @override
  String get addedLabel => 'Data de adição';

  @override
  String get lastUpdatedLabel => 'Última atualização';

  @override
  String get locationLabel => 'Localização';

  @override
  String get locationAddLabel => 'Adicionar localização';

  @override
  String get locationBlocked =>
      'Adicionar a localização depende da sua permissão. Permita o acesso à localização para registar onde a foto foi tirada.';

  @override
  String get compassNorth => 'N';

  @override
  String get compassSouth => 'S';

  @override
  String get compassEast => 'E';

  @override
  String get compassWest => 'O';

  @override
  String get toastMapFailed => 'Não foi possível abrir o Mapas';

  @override
  String get reminderSuffixActive => 'dias depois';

  @override
  String get reminderSuffixOff => 'dias — desativado';

  @override
  String get backupSectionTitle => 'Cópia de segurança';

  @override
  String get backupManageTitle => 'Gerir cópias';

  @override
  String get backupManageDescription =>
      'Cria uma cópia encriptada ou repõe uma cópia existente.';

  @override
  String get backupCreateTitle => 'Criar uma cópia';

  @override
  String get backupCreateDescription =>
      'Tudo o que está neste dispositivo, selado num ficheiro encriptado.';

  @override
  String get backupRestoreTitle => 'Restaurar uma cópia';

  @override
  String get backupRestoreDescription =>
      'Substituir tudo aqui por um ficheiro de cópia.';

  @override
  String get backupPasswordTitle => 'Escolhe uma palavra-passe';

  @override
  String get backupPasswordSubtitle =>
      'Esta palavra-passe é a única chave da tua cópia.';

  @override
  String get backupPasswordLabel => 'Palavra-passe';

  @override
  String get backupPasswordRepeat => 'Repete a palavra-passe';

  @override
  String get backupPasswordMismatch => 'As duas palavras-passe não coincidem.';

  @override
  String backupPasswordShort(int count) {
    return 'Usa pelo menos $count caracteres.';
  }

  @override
  String get backupStrengthWeak => 'Fraca';

  @override
  String get backupStrengthFair => 'Média';

  @override
  String get backupStrengthStrong => 'Forte';

  @override
  String get backupLossWarning =>
      'Compreendo que, se perder esta palavra-passe, esta cópia nunca mais poderá ser aberta.';

  @override
  String get backupActionCreate => 'Criar cópia';

  @override
  String get backupPhasePreparing => 'A preparar';

  @override
  String get backupPhaseKey => 'A derivar a chave';

  @override
  String get backupPhaseWriting => 'A encriptar';

  @override
  String get backupPhaseReading => 'A desencriptar';

  @override
  String get backupPhaseVerifying => 'A verificar';

  @override
  String get backupPhaseApplying => 'A restaurar';

  @override
  String backupItems(int done, int total) {
    return '$done de $total';
  }

  @override
  String get backupReadyTitle => 'A tua cópia está pronta';

  @override
  String backupReadySubtitle(int notes, int photos) {
    return '$notes notas e $photos fotos, encriptadas.';
  }

  @override
  String get backupActionSave => 'Guardar ou partilhar';

  @override
  String get backupPickFile => 'Escolher um ficheiro';

  @override
  String get backupUnlockTitle => 'Introduz a palavra-passe';

  @override
  String get backupUnlockSubtitle =>
      'A palavra-passe que escolheste ao criar esta cópia.';

  @override
  String get backupFoundTitle => 'Cópia encontrada';

  @override
  String backupFoundCounts(int notes, int photos) {
    return '$notes notas, $photos fotos';
  }

  @override
  String backupFoundDate(String when) {
    return 'Criada a $when';
  }

  @override
  String get backupReplaceWarning =>
      'Restaurar substitui todas as notas e fotos deste dispositivo. Não é reversível.';

  @override
  String get backupReplaceAcknowledge =>
      'Compreendo que os meus dados atuais serão apagados.';

  @override
  String get backupActionRestore => 'Restaurar';

  @override
  String get backupRestoredTitle => 'Está tudo de volta.';

  @override
  String get backupErrorWrongPassword => 'Palavra-passe incorreta.';

  @override
  String get backupErrorNotABackup => 'Isto não é uma cópia do Latermark.';

  @override
  String get backupErrorCorrupt =>
      'Este ficheiro está danificado ou incompleto.';

  @override
  String get backupErrorUnsupported =>
      'Esta cópia foi criada por uma versão mais recente do Latermark.';

  @override
  String get backupErrorGeneric => 'Algo correu mal. Tenta novamente.';

  @override
  String get paywallFeatureBackup => 'Cópia encriptada';

  @override
  String get paywallFeatureBackupDetail =>
      'Leva as tuas notas e fotos para um telemóvel novo.';

  @override
  String get reminderSuffixRepeating => 'dias · repetindo';

  @override
  String get reminderRepeatToggle => 'Repetir lembrete';

  @override
  String get reminderRepeatOnce => 'Lembra uma vez.';

  @override
  String get reminderRepeatNeedsInterval =>
      'Introduza primeiro o número de dias.';

  @override
  String reminderRepeatSummary(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Lembra a cada $days dias.',
      one: 'Lembra todos os dias.',
    );
    return '$_temp0';
  }

  @override
  String reminderRepeatingValue(int days, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'A cada $days dias · próximo $when',
      one: 'Todos os dias · próximo $when',
    );
    return '$_temp0';
  }

  @override
  String get reminderBlocked =>
      'As notificações estão desativadas. A captura será guardada na mesma; o lembrete começará a funcionar quando as permitir.';

  @override
  String get editNoteSemantic => 'Editar nota';

  @override
  String get editSheetHeader => 'EDITAR NOTA';

  @override
  String get retentionSelectorTitle => 'Eliminação automática';

  @override
  String get retentionOffNotice =>
      'A eliminação automática está desativada — esta captura ficará até ser eliminada por si.';

  @override
  String get retentionCustom => 'Personalizado';

  @override
  String get retentionCustomTitle => 'Duração personalizada';

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
      other: '$count dias',
      one: '1 dia',
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
  String get retentionUnitDays => 'Dias';

  @override
  String get retentionUnitWeeks => 'Semanas';

  @override
  String get retentionCustomDescription =>
      'A captura será eliminada automaticamente no fim deste período.';

  @override
  String get retentionOff => 'Desativado';

  @override
  String get retentionThreeDays => '3 dias';

  @override
  String get retentionOneWeek => '1 semana';

  @override
  String get retentionOffDescription => 'Desativado';

  @override
  String get retentionThreeDaysDescription => 'É eliminada após 3 dias';

  @override
  String get retentionOneWeekDescription => 'É eliminada após 1 semana';

  @override
  String get legalPrivacy => 'Privacidade';

  @override
  String get legalTerms => 'Termos de utilização';

  @override
  String get yourDataTitle => 'Latermark e os seus dados';

  @override
  String get yourDataSubtitle =>
      'A sua privacidade importa-nos — e tratamo-la com o respeito que merece.';

  @override
  String get yourDataSafetyQuestion => 'Os meus dados estão seguros?';

  @override
  String get yourDataSafetyAnswer =>
      'O Latermark funciona inteiramente no seu dispositivo. As suas notas e memórias não são enviadas para análise, relatórios de erros ou estatísticas. Só saem do dispositivo quando decide partilhá-las.';

  @override
  String get yourDataLocationQuestion =>
      'Porque é pedido acesso à minha localização?';

  @override
  String get yourDataLocationAnswer =>
      'Esta permissão só é pedida se decidir adicionar uma localização a uma nota ou memória. A localização fica associada apenas a esse registo, sem seguimento em segundo plano. Só é enviada para a app de mapas se decidir abrir o mapa.';

  @override
  String get yourDataPhotosQuestion =>
      'Para que serve o acesso às minhas fotografias?';

  @override
  String get yourDataPhotosAnswer =>
      'Apenas para poder escolher uma imagem da fototeca em vez de tirar uma nova fotografia. O Latermark importa apenas a imagem escolhida e não necessita de ligação à internet.';

  @override
  String get yourDataRemindersQuestion => 'Como funcionam os lembretes?';

  @override
  String get yourDataRemindersAnswer =>
      'São agendados e apresentados localmente no seu dispositivo. Nenhum servidor externo os envia ou aciona.';

  @override
  String get yourDataDeletionQuestion =>
      'O que acontece se apagar a aplicação?';

  @override
  String get yourDataDeletionAnswer =>
      'As notas, imagens importadas e localizações guardadas no Latermark são eliminadas de forma permanente. As fotografias da sua fototeca e os dados de outras aplicações não são afetados.';

  @override
  String get legalOpenFailed => 'Não foi possível abrir a ligação.';

  @override
  String get settingsTitle => 'Definições';

  @override
  String get sectionAppearance => 'Aspeto';

  @override
  String get sectionReminder => 'Lembretes';

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeDescription =>
      'Siga o aspeto do sistema ou escolha um para manter.';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get appColorTitle => 'Cor da aplicação';

  @override
  String get appColorDescription =>
      'Escolha a cor de destaque dos controlos e elementos realçados.';

  @override
  String get accentOrange => 'Laranja';

  @override
  String get accentBlue => 'Azul';

  @override
  String get accentViolet => 'Violeta';

  @override
  String get accentPink => 'Rosa';

  @override
  String get accentGreen => 'Verde';

  @override
  String get accentGold => 'Dourado';

  @override
  String get retentionTitle => 'Eliminação automática';

  @override
  String get retentionDescription =>
      'As novas capturas usam esta duração. Pode alterá-la nos detalhes de cada captura.';

  @override
  String get feedTitle => 'Vista';

  @override
  String get feedDescription =>
      'Mostre capturas maiores ou veja mais numa grelha.';

  @override
  String get densityLarge => 'Grande';

  @override
  String get densityGrid => 'Grelha';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageDescription =>
      'O Latermark segue o idioma do dispositivo, mas pode escolher outro.';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get remindersTitle => 'Lembretes';

  @override
  String get remindersDescription =>
      'Só as capturas a que atribuir um prazo ao guardar enviam uma notificação. As restantes ficam em silêncio.';

  @override
  String get remindersBlockedDescription =>
      'As notificações estão desativadas nas definições do sistema. Os lembretes regressam quando as permitir.';

  @override
  String get openSystemSettings => 'Abrir definições do sistema';

  @override
  String get openSettingsShort => 'Abrir Definições';

  @override
  String versionMark(String version, String build) {
    return 'Versão $version ($build)';
  }

  @override
  String get dayToday => 'Hoje';

  @override
  String get dayYesterday => 'Ontem';

  @override
  String get relativeJustNow => 'agora mesmo';

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
  String get relativeYesterday => 'ontem';

  @override
  String relativeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '1 dia',
    );
    return '$_temp0';
  }

  @override
  String get remainingNow => 'agora';

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
  String get remainingSoon => 'Será eliminada em breve';

  @override
  String remainingLongDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Será eliminada dentro de $days dias',
      one: 'Será eliminada dentro de 1 dia',
    );
    return '$_temp0';
  }

  @override
  String remainingLongDaysHours(int days, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dias',
      one: '1 dia',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours horas',
      one: '1 hora',
    );
    return 'Será eliminada dentro de $_temp0 e $_temp1';
  }

  @override
  String remainingLongHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Será eliminada dentro de $hours horas',
      one: 'Será eliminada dentro de 1 hora',
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
    return 'Será eliminada dentro de $_temp0 e $_temp1';
  }

  @override
  String remainingLongMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Será eliminada dentro de $minutes minutos',
      one: 'Será eliminada dentro de 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get paywallLimitTitle => 'Os seus 10 lugares estão ocupados';

  @override
  String paywallLimitBody(int limit) {
    return 'A versão gratuita mantém até $limit capturas de cada vez. O Pro remove o limite — ou pode eliminar uma captura para continuar.';
  }

  @override
  String get paywallLimitDelete => 'Eliminar uma captura';

  @override
  String paywallCounter(int count, int limit) {
    return '$count/$limit';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get paywallHeadline => 'Há imagens que merecem ficar.';

  @override
  String get paywallSubtitle =>
      'O Latermark foi feito para deixar ir. O Pro é para aquilo que quer guardar.';

  @override
  String paywallOwnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tem atualmente $count capturas.',
      one: 'Tem atualmente 1 captura.',
    );
    return '$_temp0';
  }

  @override
  String get paywallFeatureUnlimited => 'Capturas ilimitadas';

  @override
  String paywallFeatureUnlimitedDetail(int limit) {
    return 'A versão gratuita mantém até $limit.';
  }

  @override
  String get paywallFeatureCustomRetention => 'Escolha qualquer duração';

  @override
  String get paywallFeatureCustomRetentionDetail =>
      'Mais do que 3 dias ou 1 semana.';

  @override
  String get paywallFeatureReminders => 'Lembretes';

  @override
  String get paywallFeatureRemindersDetail =>
      'Um aviso discreto para o que importa.';

  @override
  String get paywallFeatureWidget => 'Widgets do ecrã principal e bloqueado';

  @override
  String get paywallFeatureWidgetDetail =>
      'A captura mais recente, sempre à vista.';

  @override
  String paywallPrice(String price) {
    return '$price';
  }

  @override
  String get paywallOneTime => 'Compra única';

  @override
  String get paywallNoSubscription =>
      'Sem subscrição. Pague uma vez e mantenha o Pro.';

  @override
  String get paywallOwned => 'O Latermark Pro é seu.';

  @override
  String get paywallFeatureNoSubscription => 'Sem subscrição';

  @override
  String get paywallFeatureNoSubscriptionDetail =>
      'A maioria das aplicações cobra todos os meses. O Latermark não.';

  @override
  String get paywallCta => 'Desbloquear Pro';

  @override
  String get paywallRestore => 'Restaurar compras';

  @override
  String get paywallClose => 'Fechar';

  @override
  String get paywallLifeFree => 'Gratuito';

  @override
  String get paywallLifePro => 'Pro';

  @override
  String get notificationTitle => 'Lembrete';

  @override
  String get notificationTitleNoBody => 'Há uma captura à espera';

  @override
  String get notificationBodyNoBody => 'Pediu para ser lembrado desta captura.';

  @override
  String get notificationChannelName => 'Lembretes';

  @override
  String get notificationChannelDescription =>
      'Lembra as capturas que programou.';

  @override
  String get actionOK => 'OK';

  @override
  String get widgetDescription =>
      'Mostra a captura mais recente e a respetiva nota.';

  @override
  String get widgetEmptySubtitle => 'A sua primeira nota aparecerá aqui';

  @override
  String get widgetPhotoDescription => 'Fotografia da captura mais recente';

  @override
  String get widgetLeaveTrace => 'Deixar um novo vestígio';

  @override
  String get widgetOpenApp => 'Abrir o Latermark';

  @override
  String get widgetCreateNote => 'Criar uma nova nota';

  @override
  String get widgetLeaveFirstTrace => 'Deixe o seu primeiro vestígio';

  @override
  String get widgetProRequired =>
      'Os widgets estão disponíveis com o Latermark Pro.';

  @override
  String get widgetPreviewNote => 'Enviar para a Contabilidade';

  @override
  String get widgetPreviewDay => 'HOJE';

  @override
  String get shareComposeHint => 'Porque quer guardar esta fotografia?';

  @override
  String get shareErrorTitle => 'Não foi possível adicionar a fotografia';

  @override
  String get shareErrorBody =>
      'Não foi possível enviar a fotografia para o Latermark. Tente novamente.';

  @override
  String get cameraUsageDescription =>
      'O acesso à câmara permite tirar fotografias para as suas notas.';

  @override
  String get photoLibraryUsageDescription =>
      'O acesso às fotografias permite adicionar imagens da biblioteca às suas notas.';

  @override
  String get actionShare => 'Partilhar';

  @override
  String get shareNoteSemantic => 'Partilhar foto e nota';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class L10nPtBr extends L10nPt {
  L10nPtBr() : super('pt_BR');

  @override
  String get appTitle => 'Latermark';

  @override
  String get actionSave => 'Salvar';

  @override
  String get composeSaving => 'Salvando';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionClose => 'Fechar';

  @override
  String get actionBack => 'Voltar';

  @override
  String get actionDelete => 'Apagar';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionMore => 'Mais';

  @override
  String get openPhotoSemantic => 'Abrir a foto em tela cheia';

  @override
  String get actionRetry => 'Tentar novamente';

  @override
  String get actionGoBack => 'Voltar';

  @override
  String get actionOpen => 'Abrir';

  @override
  String get settingsAction => 'Ajustes';

  @override
  String get shutterSemantic => 'Tirar uma foto';

  @override
  String get searchHint => 'Pesquisar';

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
  String get dateGroupToday => 'Hoje';

  @override
  String get dateGroupYesterday => 'Ontem';

  @override
  String get dateGroupPastWeek => 'Últimos 7 dias';

  @override
  String get dateGroupPastMonth => 'Último mês';

  @override
  String get dateGroupPastThreeMonths => 'Últimos 3 meses';

  @override
  String get dateGroupPastYear => 'Último ano';

  @override
  String get dateGroupOlder => 'Há mais de um ano';

  @override
  String noteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas',
      one: '1 nota',
      zero: 'Sem notas',
    );
    return '$_temp0';
  }

  @override
  String get noteWithoutBody => 'Sem nota';

  @override
  String get inviteTitle => 'Toque para fotografar';

  @override
  String get inviteBody =>
      'Um recibo, onde você estacionou, um detalhe…\nFotografe, acrescente algumas palavras e siga em frente.';

  @override
  String get pickFromGallery => 'Escolher nas Fotos';

  @override
  String get pickFromGallerySemantic => 'Escolher uma foto da galeria';

  @override
  String get galleryPickerOpening => 'Abrindo o seletor de fotos';

  @override
  String get manifestoFirst => 'Simples';

  @override
  String get manifestoSecond => 'Privado';

  @override
  String get manifestoThird => 'Seu';

  @override
  String get switchToLargeView => 'Mudar para visualização grande';

  @override
  String get switchToGridView => 'Mudar para grade';

  @override
  String get toastPhotoPickFailed =>
      'Não foi possível selecionar essa foto. Tente novamente.';

  @override
  String get toastPendingPickFailed =>
      'Não foi possível recuperar a seleção interrompida.';

  @override
  String get toastSharedPhotoAdded => 'Foto compartilhada adicionada.';

  @override
  String get toastSharedPhotoFailed =>
      'Não foi possível adicionar a foto compartilhada. Vamos tentar de novo.';

  @override
  String get toastDeleteFailed => 'Não foi possível apagar. Tente novamente.';

  @override
  String get toastSaveFailed => 'Não foi possível salvar. Tente novamente.';

  @override
  String get toastEditFailed => 'Não foi possível salvar as alterações.';

  @override
  String get toastPermissionDenied =>
      'As notificações estão desativadas. Os lembretes ficarão em silêncio.';

  @override
  String get deleteConfirmTitle => 'Apagar este registro?';

  @override
  String get deleteConfirmCaption => 'A foto e a nota serão apagadas juntas.';

  @override
  String get holdToDelete => 'Mantenha pressionado para apagar';

  @override
  String get holdStageAlmost => 'Quase';

  @override
  String get holdStageRelease => 'Continue pressionando…';

  @override
  String get holdStageGone => 'Apagado';

  @override
  String get cameraNotFoundTitle => 'Câmera indisponível';

  @override
  String get cameraNotFoundBody =>
      'Não há uma câmera disponível neste aparelho.';

  @override
  String get cameraDeniedTitle => 'Acesso à câmera desativado';

  @override
  String get cameraDeniedBody =>
      'Permita o acesso em Ajustes › Latermark para tirar fotos aqui.';

  @override
  String get cameraFailedTitle => 'Não foi possível abrir a câmera';

  @override
  String get cameraFailedBody => 'Ocorreu algo inesperado.';

  @override
  String get switchLens => 'Trocar de câmera';

  @override
  String flashSemantic(String state) {
    return 'Flash: $state';
  }

  @override
  String get flashOff => 'desativado';

  @override
  String get flashAuto => 'automático';

  @override
  String get flashOn => 'ativado';

  @override
  String get composeHint => 'Por que você tirou esta foto?';

  @override
  String get composeReminderDescription =>
      'Reencontre este registro no dia que escolher.';

  @override
  String get composeLocationDescription =>
      'Vincula sua localização atual somente a este registro.';

  @override
  String get composeLocationResolving => 'Obtendo sua localização…';

  @override
  String get composeLocationReady =>
      'A localização está pronta para este registro.';

  @override
  String get composeLocationPermissionRequired =>
      'A permissão de localização é necessária.';

  @override
  String get composeAnotherPhoto => 'Escolher outra foto';

  @override
  String get composeRetake => 'Repetir';

  @override
  String get sourceGallery => 'FOTOS';

  @override
  String get sourceShared => 'COMPARTILHADA';

  @override
  String get reminderLabel => 'Lembrar-me';

  @override
  String get addedLabel => 'Data de adição';

  @override
  String get lastUpdatedLabel => 'Última atualização';

  @override
  String get locationLabel => 'Localização';

  @override
  String get locationAddLabel => 'Adicionar localização';

  @override
  String get locationBlocked =>
      'Adicionar a localização depende da sua permissão. Permita o acesso à localização para registrar onde a foto foi tirada.';

  @override
  String get compassNorth => 'N';

  @override
  String get compassSouth => 'S';

  @override
  String get compassEast => 'L';

  @override
  String get compassWest => 'O';

  @override
  String get toastMapFailed => 'Não foi possível abrir o Mapas';

  @override
  String get reminderSuffixActive => 'dias depois';

  @override
  String get reminderSuffixOff => 'dias — desativado';

  @override
  String get backupSectionTitle => 'Backup';

  @override
  String get backupManageTitle => 'Gerenciar backups';

  @override
  String get backupManageDescription =>
      'Crie uma cópia criptografada ou restaure um backup existente.';

  @override
  String get backupCreateTitle => 'Criar um backup';

  @override
  String get backupCreateDescription =>
      'Tudo neste aparelho, selado em um arquivo criptografado.';

  @override
  String get backupRestoreTitle => 'Restaurar um backup';

  @override
  String get backupRestoreDescription =>
      'Substituir tudo aqui por um arquivo de backup.';

  @override
  String get backupPasswordTitle => 'Escolha uma senha';

  @override
  String get backupPasswordSubtitle =>
      'Esta senha é a única chave do seu backup.';

  @override
  String get backupPasswordLabel => 'Senha';

  @override
  String get backupPasswordRepeat => 'Repita a senha';

  @override
  String get backupPasswordMismatch => 'As duas senhas não coincidem.';

  @override
  String backupPasswordShort(int count) {
    return 'Use pelo menos $count caracteres.';
  }

  @override
  String get backupStrengthWeak => 'Fraca';

  @override
  String get backupStrengthFair => 'Média';

  @override
  String get backupStrengthStrong => 'Forte';

  @override
  String get backupLossWarning =>
      'Entendo que, se eu perder esta senha, este backup nunca mais poderá ser aberto.';

  @override
  String get backupActionCreate => 'Criar backup';

  @override
  String get backupPhasePreparing => 'Preparando';

  @override
  String get backupPhaseKey => 'Derivando a chave';

  @override
  String get backupPhaseWriting => 'Criptografando';

  @override
  String get backupPhaseReading => 'Descriptografando';

  @override
  String get backupPhaseVerifying => 'Verificando';

  @override
  String get backupPhaseApplying => 'Restaurando';

  @override
  String backupItems(int done, int total) {
    return '$done de $total';
  }

  @override
  String get backupReadyTitle => 'Seu backup está pronto';

  @override
  String backupReadySubtitle(int notes, int photos) {
    return '$notes notas e $photos fotos, criptografadas.';
  }

  @override
  String get backupActionSave => 'Salvar ou compartilhar';

  @override
  String get backupPickFile => 'Escolher um arquivo';

  @override
  String get backupUnlockTitle => 'Digite a senha';

  @override
  String get backupUnlockSubtitle =>
      'A senha que você escolheu ao criar este backup.';

  @override
  String get backupFoundTitle => 'Backup encontrado';

  @override
  String backupFoundCounts(int notes, int photos) {
    return '$notes notas, $photos fotos';
  }

  @override
  String backupFoundDate(String when) {
    return 'Criado em $when';
  }

  @override
  String get backupReplaceWarning =>
      'Restaurar substitui todas as notas e fotos deste aparelho. Não dá para desfazer.';

  @override
  String get backupReplaceAcknowledge =>
      'Entendo que meus dados atuais serão apagados.';

  @override
  String get backupActionRestore => 'Restaurar';

  @override
  String get backupRestoredTitle => 'Está tudo de volta.';

  @override
  String get backupErrorWrongPassword => 'Senha incorreta.';

  @override
  String get backupErrorNotABackup => 'Isto não é um backup do Latermark.';

  @override
  String get backupErrorCorrupt =>
      'Este arquivo está danificado ou incompleto.';

  @override
  String get backupErrorUnsupported =>
      'Este backup foi feito por uma versão mais recente do Latermark.';

  @override
  String get backupErrorGeneric => 'Algo deu errado. Tente de novo.';

  @override
  String get paywallFeatureBackup => 'Backup criptografado';

  @override
  String get paywallFeatureBackupDetail =>
      'Leve suas notas e fotos para um celular novo.';

  @override
  String get reminderSuffixRepeating => 'dias · repetindo';

  @override
  String get reminderRepeatToggle => 'Repetir lembrete';

  @override
  String get reminderRepeatOnce => 'Lembra uma vez.';

  @override
  String get reminderRepeatNeedsInterval => 'Digite primeiro o número de dias.';

  @override
  String reminderRepeatSummary(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Lembra a cada $days dias.',
      one: 'Lembra todos os dias.',
    );
    return '$_temp0';
  }

  @override
  String reminderRepeatingValue(int days, String when) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'A cada $days dias · próximo $when',
      one: 'Todos os dias · próximo $when',
    );
    return '$_temp0';
  }

  @override
  String get reminderBlocked =>
      'As notificações estão desativadas. O registro será salvo mesmo assim; o lembrete começará a funcionar quando você permitir.';

  @override
  String get editNoteSemantic => 'Editar nota';

  @override
  String get editSheetHeader => 'EDITAR NOTA';

  @override
  String get retentionSelectorTitle => 'Apagar automaticamente';

  @override
  String get retentionOffNotice =>
      'A exclusão automática está desativada — este registro ficará aqui até você apagá-lo.';

  @override
  String get retentionCustom => 'Personalizado';

  @override
  String get retentionCustomTitle => 'Duração personalizada';

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
      other: '$count dias',
      one: '1 dia',
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
  String get retentionUnitDays => 'Dias';

  @override
  String get retentionUnitWeeks => 'Semanas';

  @override
  String get retentionCustomDescription =>
      'O registro será apagado automaticamente ao fim deste período.';

  @override
  String get retentionOff => 'Desativado';

  @override
  String get retentionThreeDays => '3 dias';

  @override
  String get retentionOneWeek => '1 semana';

  @override
  String get retentionOffDescription => 'Desativado';

  @override
  String get retentionThreeDaysDescription => 'É apagado após 3 dias';

  @override
  String get retentionOneWeekDescription => 'É apagado após 1 semana';

  @override
  String get legalPrivacy => 'Privacidade';

  @override
  String get legalTerms => 'Termos de uso';

  @override
  String get yourDataTitle => 'Latermark e seus dados';

  @override
  String get yourDataSubtitle =>
      'Sua privacidade importa — e é tratada com o respeito que merece.';

  @override
  String get yourDataSafetyQuestion => 'Meus dados estão seguros?';

  @override
  String get yourDataSafetyAnswer =>
      'O Latermark funciona totalmente no seu dispositivo. Suas notas e memórias não são enviadas para análises, relatórios de erros ou estatísticas. Elas só saem do dispositivo quando você decide compartilhá-las.';

  @override
  String get yourDataLocationQuestion =>
      'Por que o Latermark pede acesso à minha localização?';

  @override
  String get yourDataLocationAnswer =>
      'Essa permissão só é solicitada se você decidir adicionar uma localização a uma nota ou memória. A localização fica vinculada apenas àquele registro, sem rastreamento em segundo plano. Ela só é enviada ao app de mapas se você decidir abrir o mapa.';

  @override
  String get yourDataPhotosQuestion => 'Como o acesso às minhas fotos é usado?';

  @override
  String get yourDataPhotosAnswer =>
      'Ele serve apenas para você escolher uma imagem da galeria em vez de tirar uma nova foto. O Latermark importa somente a imagem escolhida e não precisa de conexão com a internet.';

  @override
  String get yourDataRemindersQuestion => 'Como funcionam os lembretes?';

  @override
  String get yourDataRemindersAnswer =>
      'Eles são agendados e exibidos localmente no seu dispositivo. Nenhum servidor externo os envia ou dispara.';

  @override
  String get yourDataDeletionQuestion =>
      'O que acontece se eu desinstalar o app?';

  @override
  String get yourDataDeletionAnswer =>
      'As notas, imagens importadas e localizações salvas no Latermark são apagadas permanentemente. As fotos da sua galeria e os dados de outros apps não são afetados.';

  @override
  String get legalOpenFailed => 'Não foi possível abrir o link.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get sectionAppearance => 'Aparência';

  @override
  String get sectionReminder => 'Lembretes';

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeDescription =>
      'Siga a aparência do sistema ou escolha uma para manter.';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get appColorTitle => 'Cor do app';

  @override
  String get appColorDescription =>
      'Escolha a cor de destaque dos controles e elementos realçados.';

  @override
  String get accentOrange => 'Laranja';

  @override
  String get accentBlue => 'Azul';

  @override
  String get accentViolet => 'Violeta';

  @override
  String get accentPink => 'Rosa';

  @override
  String get accentGreen => 'Verde';

  @override
  String get accentGold => 'Dourado';

  @override
  String get retentionTitle => 'Apagar automaticamente';

  @override
  String get retentionDescription =>
      'Novos registros usam esta duração. Você pode alterá-la nos detalhes de cada registro.';

  @override
  String get feedTitle => 'Visualização';

  @override
  String get feedDescription =>
      'Mostre registros maiores ou veja mais em uma grade.';

  @override
  String get densityLarge => 'Grande';

  @override
  String get densityGrid => 'Grade';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageDescription =>
      'O Latermark segue o idioma do aparelho, mas você pode escolher outro.';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get remindersTitle => 'Lembretes';

  @override
  String get remindersDescription =>
      'Somente os registros agendados ao salvar enviam uma notificação. Os demais ficam em silêncio.';

  @override
  String get remindersBlockedDescription =>
      'As notificações estão desativadas nos ajustes do sistema. Os lembretes voltarão quando você permitir.';

  @override
  String get openSystemSettings => 'Abrir ajustes do sistema';

  @override
  String get openSettingsShort => 'Abrir Ajustes';

  @override
  String versionMark(String version, String build) {
    return 'Versão $version ($build)';
  }

  @override
  String get dayToday => 'Hoje';

  @override
  String get dayYesterday => 'Ontem';

  @override
  String get relativeJustNow => 'agora mesmo';

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
  String get relativeYesterday => 'ontem';

  @override
  String relativeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '1 dia',
    );
    return '$_temp0';
  }

  @override
  String get remainingNow => 'agora';

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
  String get remainingSoon => 'Será apagado em breve';

  @override
  String remainingLongDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Será apagado em $days dias',
      one: 'Será apagado em 1 dia',
    );
    return '$_temp0';
  }

  @override
  String remainingLongDaysHours(int days, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dias',
      one: '1 dia',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours horas',
      one: '1 hora',
    );
    return 'Será apagado em $_temp0 e $_temp1';
  }

  @override
  String remainingLongHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Será apagado em $hours horas',
      one: 'Será apagado em 1 hora',
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
    return 'Será apagado em $_temp0 e $_temp1';
  }

  @override
  String remainingLongMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Será apagado em $minutes minutos',
      one: 'Será apagado em 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get paywallLimitTitle => 'Seus 10 espaços estão ocupados';

  @override
  String paywallLimitBody(int limit) {
    return 'A versão gratuita mantém até $limit registros por vez. O Pro remove o limite — ou você pode apagar um registro para continuar.';
  }

  @override
  String get paywallLimitDelete => 'Apagar um registro';

  @override
  String paywallCounter(int count, int limit) {
    return '$count/$limit';
  }

  @override
  String get proBadge => 'PRO';

  @override
  String get paywallHeadline => 'Há imagens que merecem ficar.';

  @override
  String get paywallSubtitle =>
      'O Latermark foi feito para deixar ir. O Pro é para aquilo que você quer guardar.';

  @override
  String paywallOwnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Você tem $count registros agora.',
      one: 'Você tem 1 registro agora.',
    );
    return '$_temp0';
  }

  @override
  String get paywallFeatureUnlimited => 'Registros ilimitados';

  @override
  String paywallFeatureUnlimitedDetail(int limit) {
    return 'A versão gratuita mantém até $limit.';
  }

  @override
  String get paywallFeatureCustomRetention => 'Escolha qualquer duração';

  @override
  String get paywallFeatureCustomRetentionDetail =>
      'Mais do que 3 dias ou 1 semana.';

  @override
  String get paywallFeatureReminders => 'Lembretes';

  @override
  String get paywallFeatureRemindersDetail =>
      'Um aviso discreto para o que importa.';

  @override
  String get paywallFeatureWidget => 'Widgets da Tela de Início e Bloqueio';

  @override
  String get paywallFeatureWidgetDetail =>
      'Seu registro mais recente, sempre à vista.';

  @override
  String paywallPrice(String price) {
    return '$price';
  }

  @override
  String get paywallOneTime => 'Compra única';

  @override
  String get paywallNoSubscription =>
      'Sem assinatura. Pague uma vez e fique com o Pro.';

  @override
  String get paywallOwned => 'O Latermark Pro é seu.';

  @override
  String get paywallFeatureNoSubscription => 'Sem assinatura';

  @override
  String get paywallFeatureNoSubscriptionDetail =>
      'A maioria dos apps cobra todo mês. O Latermark não.';

  @override
  String get paywallCta => 'Desbloquear Pro';

  @override
  String get paywallRestore => 'Restaurar compras';

  @override
  String get paywallClose => 'Fechar';

  @override
  String get paywallLifeFree => 'Gratuito';

  @override
  String get paywallLifePro => 'Pro';

  @override
  String get notificationTitle => 'Lembrete';

  @override
  String get notificationTitleNoBody => 'Há um registro esperando';

  @override
  String get notificationBodyNoBody =>
      'Você pediu para lembrar deste registro.';

  @override
  String get notificationChannelName => 'Lembretes';

  @override
  String get notificationChannelDescription =>
      'Lembra você dos registros agendados.';

  @override
  String get actionOK => 'OK';

  @override
  String get widgetDescription => 'Mostra seu registro mais recente e a nota.';

  @override
  String get widgetEmptySubtitle => 'Sua primeira nota aparecerá aqui';

  @override
  String get widgetPhotoDescription => 'Foto do registro mais recente';

  @override
  String get widgetLeaveTrace => 'Deixar um novo vestígio';

  @override
  String get widgetOpenApp => 'Abrir o Latermark';

  @override
  String get widgetCreateNote => 'Criar uma nova nota';

  @override
  String get widgetLeaveFirstTrace => 'Deixe seu primeiro vestígio';

  @override
  String get widgetProRequired =>
      'Os widgets estão disponíveis com o Latermark Pro.';

  @override
  String get widgetPreviewNote => 'Enviar para a Contabilidade';

  @override
  String get widgetPreviewDay => 'HOJE';

  @override
  String get shareComposeHint => 'Por que você quer guardar esta foto?';

  @override
  String get shareErrorTitle => 'Não foi possível adicionar a foto';

  @override
  String get shareErrorBody =>
      'Não foi possível enviar a foto para o Latermark. Tente novamente.';

  @override
  String get cameraUsageDescription =>
      'O acesso à câmera permite tirar fotos para as suas notas.';

  @override
  String get photoLibraryUsageDescription =>
      'O acesso às fotos permite adicionar imagens da galeria às suas notas.';

  @override
  String get actionShare => 'Compartilhar';

  @override
  String get shareNoteSemantic => 'Compartilhar foto e nota';
}
