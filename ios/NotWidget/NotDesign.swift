import SwiftUI

/// Uygulamanın tasarım dilinin widget'taki karşılığı.
///
/// Renkler ve ölçüler Flutter tarafındaki `AppColors` / `AppType` ile birebir
/// aynı; ikisi birlikte değişmeli.
enum NotDesign {
    static let canvas = Color(red: 0.039, green: 0.039, blue: 0.047)
    static let canvasDeep = Color(red: 0.020, green: 0.020, blue: 0.024)
    static let ink = Color(red: 0.953, green: 0.945, blue: 0.929)
    static let inkSoft = Color(red: 0.953, green: 0.945, blue: 0.929, opacity: 0.55)
    static let inkFaint = Color(red: 0.953, green: 0.945, blue: 0.929, opacity: 0.32)

    /// Flutter'ın paylaştığı sekiz haneli ARGB rengini SwiftUI rengine çevirir.
    /// Eski/boş widget verisi varsayılan Latermark turuncusuna düşer.
    static func accent(_ argb: String) -> Color {
        let value = UInt64(argb, radix: 16) ?? 0xFFFF7A55
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        return Color(red: red, green: green, blue: blue)
    }

    static let cornerRadius: CGFloat = 22
}

/// Gerçek bir objektif diyaframı.
///
/// Geometri Flutter'daki `Aperture` ile aynıdır: açıklık, `bladeCount` kenarlı
/// düzgün bir çokgendir; bıçak kenarları bu çokgenin kenarlarının dış çembere
/// uzatılmasıyla elde edilir.
struct ApertureShape: Shape {
    /// 0 = kapalı, 1 = açık.
    var openness: CGFloat = 1
    var bladeCount: Int = 7

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inradius = (0.045 + (0.63 - 0.045) * openness) * outer
        let n = max(3, bladeCount)

        var path = Path()
        path.addEllipse(in: CGRect(
            x: center.x - outer, y: center.y - outer,
            width: outer * 2, height: outer * 2
        ))

        // Açıklık: iç yarıçapı `inradius` olan düzgün çokgen. Köşeleri
        // kenarların orta noktalarının açıortayında durur.
        let circumradius = inradius / cos(.pi / CGFloat(n))
        var hole = Path()
        for k in 0..<n {
            let angle = (2 * CGFloat(k) + 1) * .pi / CGFloat(n)
            let point = CGPoint(
                x: center.x + cos(angle) * circumradius,
                y: center.y + sin(angle) * circumradius
            )
            if k == 0 { hole.move(to: point) } else { hole.addLine(to: point) }
        }
        hole.closeSubpath()

        path.addPath(hole)
        return path
    }
}

/// Bıçakları birbirinden ayıran, köşeden dış çembere uzanan ince kenarlar.
struct ApertureEdges: Shape {
    var openness: CGFloat = 1
    var bladeCount: Int = 7

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inradius = (0.045 + (0.63 - 0.045) * openness) * outer
        let n = max(3, bladeCount)
        let halfSide = inradius * tan(.pi / CGFloat(n))
        let reach = sqrt(max(0, outer * outer - inradius * inradius))

        var path = Path()
        guard reach > halfSide else { return path }

        for k in 0..<n {
            let angle = 2 * .pi * CGFloat(k) / CGFloat(n)
            let normal = CGPoint(x: cos(angle), y: sin(angle))
            let tangent = CGPoint(x: -sin(angle), y: cos(angle))
            let touch = CGPoint(
                x: center.x + normal.x * inradius,
                y: center.y + normal.y * inradius
            )
            path.move(to: CGPoint(
                x: touch.x + tangent.x * halfSide,
                y: touch.y + tangent.y * halfSide
            ))
            path.addLine(to: CGPoint(
                x: touch.x + tangent.x * reach,
                y: touch.y + tangent.y * reach
            ))
        }
        return path
    }
}

/// Boş durumda görünen, kor rengiyle içten aydınlatılmış diyafram.
struct ApertureMark: View {
    var size: CGFloat
    var accent: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.30), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.62
                    )
                )
                .frame(width: size * 1.7, height: size * 1.7)

            ApertureShape()
                .fill(style: FillStyle(eoFill: true))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.24), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ApertureEdges()
                .stroke(.white.opacity(0.22), lineWidth: 1)

            Circle()
                .strokeBorder(.white.opacity(0.34), lineWidth: 1)
        }
        .frame(width: size, height: size)
    }
}
