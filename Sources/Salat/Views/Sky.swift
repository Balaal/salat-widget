import SwiftUI
import PrayerKit

enum SkyPhase {
    case night, dawn, morning, midday, afternoon, sunset, dusk

    static func at(_ now: Date, today t: PrayerTimes) -> SkyPhase {
        let sunsetWindow: TimeInterval = 35 * 60
        switch now {
        case ..<t.fajr: return .night
        case ..<t.sunrise: return .dawn
        case ..<t.dhuhr.addingTimeInterval(-90 * 60): return .morning
        case ..<t.asr: return .midday
        case ..<t.maghrib.addingTimeInterval(-sunsetWindow): return .afternoon
        case ..<t.maghrib.addingTimeInterval(sunsetWindow / 2): return .sunset
        case ..<t.isha.addingTimeInterval(20 * 60): return .dusk
        default: return .night
        }
    }

    var colors: [Color] {
        switch self {
        case .night: return [Color(hex: 0x070B1F), Color(hex: 0x111A3D), Color(hex: 0x23305E)]
        case .dawn: return [Color(hex: 0x1F2350), Color(hex: 0x5B4B8A), Color(hex: 0xE58E73)]
        case .morning: return [Color(hex: 0x2F6FC0), Color(hex: 0x5D9BE0), Color(hex: 0xA9D1F5)]
        case .midday: return [Color(hex: 0x1F63C6), Color(hex: 0x3F8BE6), Color(hex: 0x86C1F6)]
        case .afternoon: return [Color(hex: 0x2C5FA8), Color(hex: 0x6E93C6), Color(hex: 0xE9C48A)]
        case .sunset: return [Color(hex: 0x27306A), Color(hex: 0xA4467A), Color(hex: 0xF39A55)]
        case .dusk: return [Color(hex: 0x0E1438), Color(hex: 0x2E2862), Color(hex: 0x6A3F7E)]
        }
    }

    var showsStars: Bool { self == .night || self == .dusk || self == .dawn }
    var starOpacity: Double { self == .night ? 1 : (self == .dusk ? 0.6 : 0.3) }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    static let salatGold = Color(hex: 0xF5C76B)
}

struct SkyBackground: View {
    let phase: SkyPhase

    var body: some View {
        ZStack {
            LinearGradient(colors: phase.colors, startPoint: .top, endPoint: .bottom)
            if phase.showsStars {
                StarField().opacity(phase.starOpacity)
            }
            // Soft glow near the horizon.
            RadialGradient(colors: [.white.opacity(0.12), .clear], center: .bottom, startRadius: 0, endRadius: 260)
        }
        .animation(.easeInOut(duration: 1.2), value: phase)
    }
}

struct StarField: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: 7)
            for _ in 0..<70 {
                let x = rng.next() * size.width
                let y = rng.next() * size.height * 0.75
                let r = 0.4 + rng.next() * 1.2
                let o = 0.25 + rng.next() * 0.75
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(o)))
            }
        }
        .allowsHitTesting(false)
    }
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Double(state % 10_000) / 10_000
    }
}

/// The sun (or moon) travelling along its arc, with prayer markers.
struct CelestialArc: View {
    let now: Date
    let today: PrayerTimes
    let tomorrow: PrayerTimes
    let yesterday: PrayerTimes

    private var isDay: Bool { now >= today.sunrise && now < today.maghrib }

    /// Night runs from the relevant Maghrib to the next Fajr.
    private var nightBounds: (start: Date, end: Date) {
        now < today.fajr ? (yesterday.maghrib, today.fajr) : (today.maghrib, tomorrow.fajr)
    }

    private func fraction(_ date: Date, from a: Date, to b: Date) -> Double {
        let total = b.timeIntervalSince(a)
        guard total > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(a) / total))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let inset: CGFloat = 14
            let rect = CGRect(x: inset, y: 6, width: w - inset * 2, height: (h - 10) * 2)
            let f = isDay ? fraction(now, from: today.sunrise, to: today.maghrib)
                          : fraction(now, from: nightBounds.start, to: nightBounds.end)

            ZStack {
                // Horizon
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h - 4))
                    p.addLine(to: CGPoint(x: w, y: h - 4))
                }
                .stroke(.white.opacity(0.25), lineWidth: 1)

                // Full arc (dashed) and travelled arc (solid)
                ArcShape(rect: rect, from: 0, to: 1)
                    .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
                ArcShape(rect: rect, from: 0, to: f)
                    .stroke(LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.9)],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))

                if isDay {
                    ForEach([today.dhuhr, today.asr], id: \.self) { d in
                        Circle().fill(.white.opacity(0.8)).frame(width: 5, height: 5)
                            .position(ArcShape.point(in: rect, t: fraction(d, from: today.sunrise, to: today.maghrib)))
                    }
                } else {
                    ForEach([today.isha < nightBounds.end && today.isha > nightBounds.start ? today.isha : yesterday.isha], id: \.self) { d in
                        Circle().fill(.white.opacity(0.6)).frame(width: 4, height: 4)
                            .position(ArcShape.point(in: rect, t: fraction(d, from: nightBounds.start, to: nightBounds.end)))
                    }
                }

                let body = ArcShape.point(in: rect, t: f)
                if isDay {
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: 0xFFF6D5), Color.salatGold],
                                             center: .center, startRadius: 0, endRadius: 8))
                        .frame(width: 14, height: 14)
                        .shadow(color: Color.salatGold.opacity(0.9), radius: 10)
                        .position(body)
                } else {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0xF4F1E1))
                        .shadow(color: .white.opacity(0.7), radius: 6)
                        .position(body)
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight) // the sun always rises in the east (left on the arc)
    }
}

struct ArcShape: Shape {
    let rect: CGRect
    let from: Double
    let to: Double

    static func point(in rect: CGRect, t: Double) -> CGPoint {
        let angle = Double.pi * (1 - t)
        return CGPoint(x: rect.midX + cos(angle) * rect.width / 2,
                       y: rect.midY - sin(angle) * rect.height / 2)
    }

    func path(in _: CGRect) -> Path {
        var p = Path()
        let steps = 60
        guard to > from else { return p }
        for i in 0...steps {
            let t = from + (to - from) * Double(i) / Double(steps)
            let pt = Self.point(in: rect, t: t)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

extension Prayer {
    var symbol: String {
        switch self {
        case .fajr: return "sun.horizon"
        case .sunrise: return "sunrise"
        case .dhuhr: return "sun.max"
        case .asr: return "sun.min"
        case .maghrib: return "sunset"
        case .isha: return "moon.stars"
        }
    }

    var fillSymbol: String {
        switch self {
        case .fajr: return "sun.horizon.fill"
        case .sunrise: return "sunrise.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.min.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        }
    }
}
