import SwiftUI
import WidgetKit

// MARK: - Ortak parçalar

/// Fotoğrafın iki kenarındaki küçük kayıt metinlerini okunur kılan perde.
private struct PhotoScrim: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.28), location: 0.0),
                .init(color: .clear, location: 0.27),
                .init(color: NotDesign.canvasDeep.opacity(0.62), location: 0.66),
                .init(color: NotDesign.canvasDeep.opacity(0.92), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Not metni yoksa bile bir şey söylemek gerekir.
private struct BodyText: View {
    var text: String
    var size: CGFloat
    var lineLimit: Int

    var body: some View {
        Text(text.isEmpty ? NotText.value("widget.note.untitled") : text)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(text.isEmpty ? NotDesign.inkFaint : NotDesign.ink)
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .privacySensitive()
    }
}

/// Hiç kayıt yokken: ortada nefes alan diyafram ve tek satırlık davet.
private struct EmptyState: View {
    var compact: Bool
    var accent: Color

    var body: some View {
        VStack(spacing: compact ? 12 : 16) {
            ApertureMark(size: compact ? 46 : 58, accent: accent)
            VStack(spacing: 3) {
                Text(NotText.value("widget.empty.title"))
                    .font(.system(size: compact ? 13 : 15, weight: .medium))
                    .foregroundStyle(NotDesign.ink)
                if !compact {
                    Text(NotText.value("widget.empty.subtitle"))
                        .font(.system(size: 12))
                        .foregroundStyle(NotDesign.inkFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Kilit ekranı boyutları

// Kilit ekranı aksesuarları **tek renk** çizilir: sistem duvar kâğıdına göre
// bir vibrancy uygular ve gönderdiğin renkleri yok sayar. Yani fotoğraf, kor
// rengi ve cam efekti bu ailelerde yok. "Premium" hissi buradaki tek
// kaynaktan gelebilir: hiyerarşi ve tipografi.
//
// Bu yüzden iki karar:
//
// 1. **Uygulama simgesi çizmiyoruz.** Daireye alınmış bir ikon her uygulamanın
//    yaptığı şey ve kilit ekranındaki en kıymetli şeyi — yeri — süse harcıyor.
//    Ayırt edici varlığımız *ömür çizgisi*; tek renkte de okunuyor ve
//    kullanıcı onu uygulamanın içinde zaten öğrendi.
// 2. **Yuvarlak (`.rounded`) yazı tipi kullanmıyoruz.** Uygulamanın dili sıkı
//    aralıklı SF Pro; `.rounded` daha oyuncu bir kişilik ve buraya yabancı.
//    Apple'ın kendi kilit ekranı widget'ları da sistem yazı tipini kullanıyor.

/// Kilit ekranında Latermark'ı uygulama ikonuna indirgemeyen küçük imza.
/// Açıklık, süreli notlarda kalan ömürle birlikte kapanır.
private struct AccessoryApertureGlyph: View {
    var fraction: Double?
    var size: CGFloat

    private var openness: CGFloat {
        guard let fraction else { return 0.72 }
        return 0.22 + (0.50 * CGFloat(max(0, min(1, fraction))))
    }

    var body: some View {
        ZStack {
            ApertureShape(openness: openness)
                .fill(.primary, style: FillStyle(eoFill: true))
            ApertureEdges(openness: openness)
                .stroke(.primary.opacity(0.78), lineWidth: 0.55)
        }
        .frame(width: size, height: size)
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}

/// Ömür çizgisinin kilit ekranındaki tek renk hâli.
/// Yuvarlatılmış bir progress bar değil; ince bir zaman ekseni ve onun
/// üzerindeki elmas biçimli "şimdi" işareti. Uygulamadaki LifeRule'ın
/// dar alandaki karşılığı.
private struct AccessoryLifeRule: View {
    var fraction: Double

    var body: some View {
        GeometryReader { geo in
            let width = max(3, geo.size.width)
            let markerX = max(2, min(width - 2, width * fraction))

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.primary.opacity(0.24))
                    .frame(height: 0.75)

                Rectangle()
                    .fill(.primary)
                    .frame(width: markerX, height: 1.5)

                Rectangle()
                    .fill(.primary)
                    .frame(width: 3.5, height: 3.5)
                    .rotationEffect(.degrees(45))
                    .position(x: markerX, y: 2)
            }
        }
        .frame(height: 4)
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}

/// Süresiz bir not için açık uçlu yaşam çizgisi.
private struct AccessoryOpenRule: View {
    var body: some View {
        HStack(spacing: 5) {
            Rectangle()
                .fill(.primary.opacity(0.28))
                .frame(height: 0.75)
            Image(systemName: "infinity")
                .font(.system(size: 8, weight: .semibold))
        }
        .foregroundStyle(.primary)
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}

/// Saatin üstündeki tek satırlık alan.
private struct AccessoryInlineLayout: View {
    var entry: NotEntry

    var body: some View {
        // Durum başta kaldığı için dar alanda kesilen bölüm notun sonudur;
        // widget bir daha yalnız gövde metnine düşmez.
        Label(
            entry.showsNote ? entry.inlineSummary : NotText.value("widget.leave_trace"),
            systemImage: "camera.aperture"
        )
        .lineLimit(1)
        .privacySensitive(entry.showsNote)
    }
}

/// Saatin altındaki dairesel alan.
///
/// Halkanın kendisi ömür çizgisinin dairesel hâli; süreli notlarda kalan
/// ömrü, süresizlerde uygulamanın diyafram işaretini gösterir.
private struct AccessoryCircularLayout: View {
    var entry: NotEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            if entry.showsNote, let remaining = entry.remaining {
                Circle()
                    .stroke(.primary.opacity(0.22), lineWidth: 3)
                    .padding(4)
                Circle()
                    .trim(from: 0, to: entry.lifeFraction)
                    .stroke(.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(4)

                VStack(spacing: 2) {
                    AccessoryApertureGlyph(
                        fraction: entry.lifeFraction,
                        size: 10
                    )
                    Text(remaining)
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
            } else {
                VStack(spacing: 3) {
                    AccessoryApertureGlyph(
                        fraction: nil,
                        size: entry.showsNote ? 22 : 26
                    )
                    if entry.showsNote, !entry.displayTime.isEmpty {
                        Text(entry.displayTime)
                            .font(.system(size: 9, weight: .semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
            }
        }
        .accessibilityLabel(
            entry.showsNote ? entry.inlineSummary : NotText.value("widget.create_note")
        )
    }
}

/// Saatin altındaki yatay alan.
///
/// Sıralama içerik önce: küçük yayın imzası, not, sonra kayıt damgası ve
/// ömür izi. Marka yalnız bu ailede masthead olur; inline'da notun önüne
/// geçer, circular'da ise okunamayacak kadar sıkışırdı.
/// Tek satırlık bir not bile artık boşlukta duran yalnız bir cümle değil;
/// nerede ve ne kadar zamandır var olduğunu anlatan tamamlanmış bir kayıt.
private struct AccessoryRectangularLayout: View {
    var entry: NotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if entry.showsNote {
                HStack(alignment: .center, spacing: 5) {
                    AccessoryApertureGlyph(
                        fraction: entry.expiresAt == nil ? nil : entry.lifeFraction,
                        size: 9
                    )

                    Text("LATERMARK PRO")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.85)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if let temporal = entry.temporalSummary {
                        Text(temporal)
                            .font(.system(size: 9, weight: .semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.secondary)

                Text(entry.noteText)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.35)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .privacySensitive()

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    if !entry.captureStamp.isEmpty {
                        Text(entry.captureStamp)
                            .font(.system(size: 8, weight: .medium))
                            .tracking(0.35)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }

                    if entry.expiresAt != nil {
                        AccessoryLifeRule(fraction: entry.lifeFraction)
                    } else {
                        AccessoryOpenRule()
                    }
                }
            } else {
                HStack(spacing: 8) {
                    AccessoryApertureGlyph(fraction: nil, size: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Latermark")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(-0.3)
                        Text(NotText.value("widget.leave_first_trace"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        // Tüm widget'ta contentMarginsDisabled kullanıldığı için accessory
        // ailesinin kendi güvenli baskı payını burada açıkça veriyoruz.
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Boyutlar

/// Ana ekran widget'larının ortak imzası. Kilit ekranındaki glifin aksine
/// renk taşıyabilir; seçilen uygulama rengi burada kaydın zaman işaretidir.
private struct HomeApertureGlyph: View {
    var entry: NotEntry
    var size: CGFloat

    private var openness: CGFloat {
        guard entry.expiresAt != nil else { return 0.72 }
        return 0.18 + (0.54 * CGFloat(entry.lifeFraction))
    }

    var body: some View {
        ZStack {
            ApertureShape(openness: openness)
                .fill(entry.accent, style: FillStyle(eoFill: true))
            ApertureEdges(openness: openness)
                .stroke(NotDesign.ink.opacity(0.52), lineWidth: 0.55)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Kaydın üst bilgisi. Rozet yerine tek bir tipografik satır kullanır;
/// fotoğraflı ve fotoğrafsız kare aynı bilgi hiyerarşisini korur.
private struct HomeCaptureStamp: View {
    var entry: NotEntry
    var overPhoto: Bool = false
    var showsBrand: Bool = false

    private var ink: Color {
        overPhoto ? .white.opacity(0.84) : NotDesign.inkSoft
    }

    var body: some View {
        HStack(spacing: 6) {
            HomeApertureGlyph(entry: entry, size: 10)

            Text(showsBrand ? "LATERMARK" : captureLabel)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.25)
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 4)

            if showsBrand, !entry.captureStamp.isEmpty {
                Text(entry.captureStamp)
                    .font(.system(size: 9, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } else if let remaining = entry.remaining {
                Text(remaining)
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(overPhoto ? .white : entry.accent)
                    .lineLimit(1)
            } else {
                Image(systemName: "infinity")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(overPhoto ? .white.opacity(0.84) : entry.accent)
            }
        }
    }

    private var captureLabel: String {
        entry.captureStamp.isEmpty ? "LATERMARK" : entry.captureStamp
    }
}

/// Uygulamadaki LifeRule'ın ana ekran karşılığı. Bir progress bar gibi
/// kalınlaşmaz; ince zaman ekseni ve küçük bir "şimdi" çentiğidir.
private struct HomeLifeRule: View {
    var entry: NotEntry

    var body: some View {
        if entry.expiresAt != nil {
            GeometryReader { geo in
                let width = max(4, geo.size.width)
                let markerX = max(2, min(width - 2, width * entry.lifeFraction))

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(NotDesign.inkFaint.opacity(0.62))
                        .frame(height: 0.75)

                    Rectangle()
                        .fill(entry.accent)
                        .frame(width: markerX, height: 1.25)

                    Rectangle()
                        .fill(entry.accent)
                        .frame(width: 3, height: 3)
                        .rotationEffect(.degrees(45))
                        .position(x: markerX, y: 4)
                }
            }
            .frame(height: 8)
        } else {
            HStack(spacing: 7) {
                Rectangle()
                    .fill(NotDesign.inkFaint.opacity(0.62))
                    .frame(height: 0.75)
                Image(systemName: "infinity")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(entry.accent)
            }
            .frame(height: 8)
        }
    }
}

/// Fotoğrafın henüz paylaşılamadığı ilk timeline karesinde boş siyah bir
/// kutu göstermeyen kayıt alanı. Dev diyafram bir placeholder ikonu değil;
/// fotoğrafın bulunmadığını saklamadan çekim nesnesini temsil eder.
private struct FrameField: View {
    var entry: NotEntry
    var compact: Bool

    var body: some View {
        GeometryReader { geo in
            let shortEdge = min(geo.size.width, geo.size.height)
            let size = shortEdge * (compact ? 0.92 : 0.78)
            let openness = entry.expiresAt == nil
                ? CGFloat(0.72)
                : 0.18 + (0.54 * CGFloat(entry.lifeFraction))

            ZStack(alignment: .topLeading) {
                NotDesign.canvasDeep

                Rectangle()
                    .fill(entry.accent.opacity(0.72))
                    .frame(width: 1.5, height: geo.size.height * 0.34)
                    .offset(x: compact ? 13 : 16, y: geo.size.height * 0.12)

                ZStack {
                    ApertureShape(openness: openness)
                        .fill(NotDesign.ink.opacity(0.055), style: FillStyle(eoFill: true))
                    ApertureEdges(openness: openness)
                        .stroke(entry.accent.opacity(0.32), lineWidth: 0.8)
                    Circle()
                        .strokeBorder(NotDesign.ink.opacity(0.09), lineWidth: 0.75)
                }
                .frame(width: size, height: size)
                .position(
                    x: geo.size.width * (compact ? 0.72 : 0.58),
                    y: geo.size.height * (compact ? 0.34 : 0.47)
                )
            }
        }
        .accessibilityHidden(true)
    }
}

/// Fotoğraf ve fotoğraf-yok alanının ortak davranışı. Alt köşedeki kayıt
/// damgası medyayı salt dekor olmaktan çıkarıp zamana bağlı bir nesne yapar.
private struct HomeMedia: View {
    var entry: NotEntry
    var compactFallback: Bool = false

    var body: some View {
        // Kare burada da arka plan. `aspectRatio(.fill)` verilmiş bir resim
        // kardeşi olduğu yığını kendi boyuna doğru büyütür; küçük boyda bu,
        // not metnini widget'ın dışına itiyordu. `background` ölçüyü içeriğe
        // bırakır ve aynı hata orta/büyük boyda da doğamaz.
        HStack(alignment: .lastTextBaseline, spacing: 5) {
            Text(entry.displayDay)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
            Text(entry.displayTime)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
        }
        .foregroundStyle(NotDesign.ink.opacity(entry.image == nil ? 0.56 : 0.86))
        .lineLimit(1)
        .padding(14)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .bottomLeading
        )
        .background {
            if let image = entry.image {
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    PhotoScrim()
                }
                .clipped()
            } else {
                FrameField(entry: entry, compact: compactFallback)
            }
        }
        .clipped()
    }
}

/// Küçük: tek bir "anı kartı". Metin hiçbir zaman tek başına kalmaz;
/// kayıt damgası, diyafram ve ömür çizgisi aynı karede okunur.
private struct SmallLayout: View {
    var entry: NotEntry

    var body: some View {
        // Kare **arka plan** olarak veriliyor, `ZStack` kardeşi olarak değil.
        // Fark ölçüde: `aspectRatio(.fill)` verilmiş bir resim kendisine
        // önerilen boyu aşar ve kardeşi olduğu `ZStack`'i de büyütür. Yığın
        // büyüyünce üstündeki yazı yığını da o büyümüş kutuya göre yerleşiyor,
        // not metni widget'ın alt kenarından taşıp kırpılıyordu — ekranda
        // yalnızca birkaç pikseli görünüyordu. `background` ise ölçüyü
        // *içeriğe* bırakır: kare arkada doldurur, yerleşime hiç karışmaz.
        VStack(alignment: .leading, spacing: 0) {
            HomeCaptureStamp(entry: entry, overPhoto: entry.image != nil)

            Spacer(minLength: 8)

            BodyText(text: entry.noteText, size: 16, lineLimit: 3)
                .shadow(
                    color: entry.image == nil ? .clear : .black.opacity(0.42),
                    radius: 8,
                    y: 2
                )

            HomeLifeRule(entry: entry)
                .padding(.top, 9)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            if let image = entry.image {
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    PhotoScrim()
                }
                .clipped()
            } else {
                FrameField(entry: entry, compact: true)
            }
        }
        .clipped()
    }
}

/// Orta: fotoğraf bir "kapak" değil, soldaki kayıt karesidir. Sağdaki geniş
/// marj nota ayrılır; bu boyut küçük widget'ın büyütülmüş kopyası değildir.
private struct MediumLayout: View {
    var entry: NotEntry

    var body: some View {
        GeometryReader { geo in
            let mediaWidth = min(132, geo.size.width * 0.39)

            HStack(spacing: 0) {
                HomeMedia(entry: entry)
                    .frame(width: mediaWidth)

                Rectangle()
                    .fill(entry.accent.opacity(0.78))
                    .frame(width: 1)

                VStack(alignment: .leading, spacing: 0) {
                    HomeCaptureStamp(entry: entry, showsBrand: true)

                    BodyText(text: entry.noteText, size: 18, lineLimit: 3)
                        .padding(.top, 12)

                    Spacer(minLength: 8)

                    HStack(alignment: .center, spacing: 8) {
                        HomeLifeRule(entry: entry)

                        if let remaining = entry.remaining {
                            Text(remaining)
                                .font(.system(size: 10, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(entry.accent)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Büyük: fotoğraf için gerçek bir baskı alanı, altında geniş bir yazı marjı.
/// Bilgi yoğunluğu artar ama yeni kartlar/rozetler eklenmez.
private struct LargeLayout: View {
    var entry: NotEntry

    var body: some View {
        GeometryReader { geo in
            let mediaHeight = geo.size.height * 0.59

            VStack(spacing: 0) {
                HomeMedia(entry: entry)
                    .frame(height: mediaHeight)

                Rectangle()
                    .fill(entry.accent.opacity(0.78))
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 0) {
                    HomeCaptureStamp(entry: entry, showsBrand: true)

                    BodyText(text: entry.noteText, size: 20, lineLimit: 4)
                        .padding(.top, 13)

                    Spacer(minLength: 10)

                    HStack(alignment: .center, spacing: 10) {
                        HomeLifeRule(entry: entry)

                        if let remaining = entry.remaining {
                            Text(remaining)
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(entry.accent)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 17)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }
}

/// Ücretsiz kullanıcıdaki hâli.
///
/// Widget bozulmuyor ve **eski veriyi göstermiyor** — kullanıcı Pro'dan
/// düşerse ekranında donmuş bir not kalmasın. Kendi diliyle sessiz bir davet
/// çiziyor; dokunmak uygulamayı açıyor.
private struct LockedState: View {
    var family: WidgetFamily
    var accent: Color

    private var accessory: Bool {
        family == .accessoryInline
            || family == .accessoryCircular
            || family == .accessoryRectangular
    }

    var body: some View {
        if family == .accessoryInline {
            Label("Latermark Pro", systemImage: "lock")
        } else if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "lock")
                    .font(.system(size: 20, weight: .regular))
            }
        } else if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 3) {
                Text("Latermark Pro")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.3)
                Text(NotText.value("widget.pro.required"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 12) {
                ApertureMark(size: 44, accent: accent)
                VStack(spacing: 3) {
                    Text("Latermark Pro")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NotDesign.ink)
                    Text(NotText.value("widget.pro.required"))
                        .font(.system(size: 12))
                        .foregroundStyle(NotDesign.inkFaint)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Widget

struct NotWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NotEntry

    var body: some View {
        Group {
            if !entry.pro {
                LockedState(family: family, accent: entry.accent)
            } else {
            switch family {
            case .accessoryInline:
                AccessoryInlineLayout(entry: entry)
            case .accessoryCircular:
                AccessoryCircularLayout(entry: entry)
            case .accessoryRectangular:
                AccessoryRectangularLayout(entry: entry)
            case .systemSmall:
                if entry.showsNote {
                    SmallLayout(entry: entry)
                } else {
                    EmptyState(compact: true, accent: entry.accent)
                }
            case .systemLarge:
                if entry.showsNote {
                    LargeLayout(entry: entry)
                } else {
                    EmptyState(compact: false, accent: entry.accent)
                }
            case .systemMedium:
                if entry.showsNote {
                    MediumLayout(entry: entry)
                } else {
                    EmptyState(compact: false, accent: entry.accent)
                }
            default:
                EmptyState(compact: false, accent: entry.accent)
            }
            }
        }
        .widgetURL(widgetURL)
        // Kilit ekranı aksesuarları duvar kâğıdını ve sistemin
        // vibrancy stilini korur; ana ekran aileleri kendi tuvalini kullanır.
        .containerBackground(for: .widget) {
            switch family {
            case .accessoryInline, .accessoryCircular, .accessoryRectangular:
                Color.clear
            default:
                NotDesign.canvas
            }
        }
    }

    private var widgetURL: URL? {
        if entry.pro, entry.showsNote, entry.noteId > 0 {
            return URL(string: "latermark://note/\(entry.noteId)?homeWidget")
        }
        return URL(string: "latermark://home?homeWidget")
    }
}

struct NotWidget: Widget {
    let kind = "NotWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NotProvider()) { entry in
            NotWidgetView(entry: entry)
        }
        .configurationDisplayName("Latermark Pro")
        .description(Text(NotText.value("widget.description")))
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular,
        ])
        .contentMarginsDisabled()
    }
}

// MARK: - Kilit ekranından hızlı çekim

/// Hazır bekleyen bir deklanşör: sistem kamera ikonunun bir başka kopyası
/// değil, Latermark'ın yedi kanatlı diyaframı ile "şimdi" elmasının birleşimi.
/// Kilit ekranı renkleri vibrancy ile yeniden çizdiği için karakterini renkten
/// değil, silüetten ve hassas çizgi hiyerarşisinden alır.
private struct CaptureReadyGlyph: View {
    var size: CGFloat
    var openness: CGFloat = 0.78

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(
                    .primary.opacity(0.72),
                    style: StrokeStyle(lineWidth: 0.9, lineCap: .square)
                )
                .rotationEffect(.degrees(45))

            // Halkanın bilinçli boşluğu ve elmas, uygulamadaki ömür çizgisinin
            // "yeni kayıt şimdi başlıyor" karşılığıdır.
            Rectangle()
                .fill(.primary)
                .frame(width: 4, height: 4)
                .rotationEffect(.degrees(45))
                .offset(x: size * 0.335, y: size * 0.335)

            ApertureShape(openness: openness)
                .fill(.primary, style: FillStyle(eoFill: true))
                .frame(width: size * 0.56, height: size * 0.56)

            ApertureEdges(openness: openness)
                .stroke(.primary.opacity(0.72), lineWidth: 0.55)
                .frame(width: size * 0.56, height: size * 0.56)

            Circle()
                .stroke(.primary.opacity(0.24), lineWidth: 0.65)
                .frame(width: size * 0.67, height: size * 0.67)
        }
        .frame(width: size, height: size)
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}

private struct CaptureCircularLayout: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            CaptureReadyGlyph(size: 43)
        }
    }
}

private struct CaptureRectangularLayout: View {
    var body: some View {
        HStack(spacing: 11) {
            CaptureReadyGlyph(size: 43)

            VStack(alignment: .leading, spacing: 3) {
                // Tek satırlık künye. Yanına ikinci bir etiket konduğunda dar
                // dillerde alt satıra kayıyor ve kilit ekranındaki iki satırlık
                // alanı yiyordu; marka adı tek başına zaten yeterli.
                Text("LATERMARK")
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(0.85)
                    .lineLimit(1)

                Text(NotText.value("widget.capture.action"))
                    .font(.system(size: 15.5, weight: .semibold))
                    .tracking(-0.35)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                AccessoryLifeRule(fraction: 0.72)
                    .padding(.trailing, 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}

/// Pro hakkı geri alındığında yerleşmiş kestirme işlevini ve eski durumunu
/// birlikte bırakır. Açık diyafram yerine kapalı optik iz gösterilir.
private struct CaptureLockedLayout: View {
    var family: WidgetFamily

    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                CaptureReadyGlyph(size: 41, openness: 0.12)
                Image(systemName: "lock.fill")
                    .font(.system(size: 8, weight: .bold))
            }
        } else {
            HStack(spacing: 11) {
                CaptureReadyGlyph(size: 41, openness: 0.12)
                VStack(alignment: .leading, spacing: 3) {
                    Text("LATERMARK PRO")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.75)
                    Text(NotText.value("widget.pro.required"))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
    }
}

private struct CaptureWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NotEntry

    var body: some View {
        Group {
            if !entry.pro {
                CaptureLockedLayout(family: family)
            } else if family == .accessoryCircular {
                CaptureCircularLayout()
            } else {
                CaptureRectangularLayout()
            }
        }
        .widgetURL(widgetURL)
        .containerBackground(for: .widget) { Color.clear }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            entry.pro
                ? Text(NotText.value("widget.capture.accessibility"))
                : Text("Latermark Pro")
        )
        .accessibilityHint(
            Text(
                entry.pro
                    ? NotText.value("widget.capture.hint")
                    : NotText.value("widget.pro.required")
            )
        )
        .accessibilityAddTraits(.isButton)
    }

    private var widgetURL: URL? {
        // Kilitli görünüm de aynı kapıya gider; Flutter güncel mağaza hakkını
        // doğrular ve Free kullanıcıya bağlamı kaybetmeden widget paywall'unu
        // gösterir. Stale bir timeline bu kontrolü aşamaz.
        URL(string: "latermark://capture?homeWidget")
    }
}

/// Mevcut not widget'ından bağımsız ikinci tür. Inline aile özellikle yok:
/// o alan tek satırlık bir etikete mecbur bırakır ve bu kestirmenin optik
/// kimliğini taşıyamaz.
struct LatermarkCaptureWidget: Widget {
    let kind = "LatermarkCaptureWidget"

    var body: some WidgetConfiguration {
        // Kare olmadan: bu görünüm fotoğrafı hiç çizmiyor ve kilit ekranı
        // aksesuarlarının bellek bütçesi en dar olan.
        StaticConfiguration(kind: kind, provider: NotProvider(withPhoto: false)) { entry in
            CaptureWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(NotText.value("widget.capture.name")))
        .description(Text(NotText.value("widget.capture.description")))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

@main
struct NotWidgetBundle: WidgetBundle {
    var body: some Widget {
        NotWidget()
        LatermarkCaptureWidget()
    }
}
