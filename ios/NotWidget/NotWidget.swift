import SwiftUI
import WidgetKit

// MARK: - Ortak parçalar

/// Fotoğrafın üstünde yazıyı okunur kılan, alta doğru koyulaşan perde.
private struct PhotoScrim: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.30),
                .init(color: NotDesign.canvasDeep.opacity(0.62), location: 0.66),
                .init(color: NotDesign.canvasDeep.opacity(0.92), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Kalan ömrü hem bir yay hem de kısa metinle gösteren rozet.
private struct ExpiryPill: View {
    var label: String
    var fraction: Double

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle().stroke(.white.opacity(0.22), lineWidth: 1.6)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(NotDesign.ember, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 11, height: 11)

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NotDesign.ink)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
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
    }
}

/// Hiç kayıt yokken: ortada nefes alan diyafram ve tek satırlık davet.
private struct EmptyState: View {
    var compact: Bool

    var body: some View {
        VStack(spacing: compact ? 12 : 16) {
            ApertureMark(size: compact ? 46 : 58)
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

/// Ömür çizgisinin tek renk hâli.
private struct AccessoryLifeRule: View {
    var fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.22))
                Capsule()
                    .fill(.primary)
                    .frame(width: max(2, geo.size.width * fraction))
            }
        }
        .frame(height: 2.5)
    }
}

/// Saatin üstündeki tek satırlık alan.
private struct AccessoryInlineLayout: View {
    var entry: NotEntry

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Label(
                entry.showsNote ? entry.inlineSummary : NotText.value("widget.leave_trace"),
                systemImage: "camera.aperture"
            )
            Label(
                entry.showsNote
                    ? (entry.body.isEmpty ? NotText.value("widget.note.untitled") : entry.body)
                    : NotText.value("widget.open_app"),
                systemImage: "camera.aperture"
            )
        }
        .lineLimit(1)
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

                // Tek bir değer. Altına "KALAN" gibi 6 punto bir etiket koymak
                // okunmuyor, yalnızca gürültü ekliyordu.
                Text(remaining)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
            } else {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 22, weight: .regular))
            }
        }
        .accessibilityLabel(
            entry.showsNote ? entry.inlineSummary : NotText.value("widget.create_note")
        )
    }
}

/// Saatin altındaki yatay alan.
///
/// Sıralama içerik önce: notun kendisi en büyük yazı, künye altında sessiz,
/// en altta ömür çizgisi. Kullanıcı bir bakışta "ne" ve "ne kadar kaldı"
/// sorularını cevaplıyor.
private struct AccessoryRectangularLayout: View {
    var entry: NotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if entry.showsNote {
                Text(entry.body.isEmpty ? NotText.value("widget.note.untitled") : entry.body)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.3)
                    .lineLimit(entry.expiresAt == nil ? 3 : 2)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 5) {
                    Text(entry.time)
                        .monospacedDigit()
                    if let remaining = entry.remaining {
                        Text("·")
                        Text(remaining).monospacedDigit()
                    }
                    Spacer(minLength: 0)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if entry.expiresAt != nil {
                    AccessoryLifeRule(fraction: entry.lifeFraction)
                        .padding(.top, 1)
                }
            } else {
                Text("Latermark")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.3)
                Text(NotText.value("widget.leave_first_trace"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Boyutlar

/// Küçük: kare tam sayfa, altında ince bir başlık şeridi.
private struct SmallLayout: View {
    var entry: NotEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                PhotoScrim()
            }

            VStack(alignment: .leading, spacing: 4) {
                BodyText(text: entry.body, size: 13, lineLimit: 2)
                Text(entry.time)
                    .font(.system(size: 11))
                    .foregroundStyle(NotDesign.inkSoft)
            }
            .padding(14)

            if let remaining = entry.remaining {
                VStack {
                    HStack {
                        Spacer()
                        ExpiryPill(label: remaining, fraction: entry.lifeFraction)
                    }
                    Spacer()
                }
                .padding(10)
            }
        }
    }
}

/// Orta: solda kare, sağda okunabilir bir metin bloğu.
private struct MediumLayout: View {
    var entry: NotEntry

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if let image = entry.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    NotDesign.canvasDeep
                }
            }
            .frame(width: 108, height: 108)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(entry.day)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(NotDesign.inkFaint)

                BodyText(text: entry.body, size: 15, lineLimit: 3)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Text(entry.time)
                        .font(.system(size: 12))
                        .foregroundStyle(NotDesign.inkSoft)
                    if let remaining = entry.remaining {
                        ExpiryPill(label: remaining, fraction: entry.lifeFraction)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }
}

/// Büyük: kare üstte hâkim, altında tarih ve tam metin.
private struct LargeLayout: View {
    var entry: NotEntry

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                if let image = entry.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    NotDesign.canvasDeep
                }

                if let remaining = entry.remaining {
                    ExpiryPill(label: remaining, fraction: entry.lifeFraction)
                        .padding(12)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 232)
            .clipped()

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(entry.day)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(NotDesign.inkFaint)
                    Spacer()
                    Text(entry.time)
                        .font(.system(size: 12))
                        .foregroundStyle(NotDesign.inkSoft)
                }

                BodyText(text: entry.body, size: 17, lineLimit: 4)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
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
                ApertureMark(size: 44)
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
                LockedState(family: family)
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
                    EmptyState(compact: true)
                }
            case .systemLarge:
                if entry.showsNote {
                    LargeLayout(entry: entry)
                } else {
                    EmptyState(compact: false)
                }
            case .systemMedium:
                if entry.showsNote {
                    MediumLayout(entry: entry)
                } else {
                    EmptyState(compact: false)
                }
            default:
                EmptyState(compact: false)
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
        if entry.showsNote, entry.noteId > 0 {
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
        .configurationDisplayName("Latermark")
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

@main
struct NotWidgetBundle: WidgetBundle {
    var body: some Widget {
        NotWidget()
    }
}
