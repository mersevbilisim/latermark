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
        Text(text.isEmpty ? "Notsuz kayıt" : text)
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
                Text("Dokun ve çek")
                    .font(.system(size: compact ? 13 : 15, weight: .medium))
                    .foregroundStyle(NotDesign.ink)
                if !compact {
                    Text("İlk notun burada görünecek")
                        .font(.system(size: 12))
                        .foregroundStyle(NotDesign.inkFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - Widget

struct NotWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NotEntry

    var body: some View {
        Group {
            if entry.hasNote {
                switch family {
                case .systemSmall: SmallLayout(entry: entry)
                case .systemLarge: LargeLayout(entry: entry)
                default: MediumLayout(entry: entry)
                }
            } else {
                EmptyState(compact: family == .systemSmall)
            }
        }
        .widgetURL(URL(string: "notapp://note/\(entry.noteId)"))
        // Eklentinin dağıtım hedefi iOS 17 olduğu için doğrudan kullanılabilir.
        .containerBackground(for: .widget) { NotDesign.canvas }
    }
}

struct NotWidget: Widget {
    let kind = "NotWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NotProvider()) { entry in
            NotWidgetView(entry: entry)
        }
        .configurationDisplayName("Latermark")
        .description("En son çektiğin kareyi ve notunu gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct NotWidgetBundle: WidgetBundle {
    var body: some Widget {
        NotWidget()
    }
}
