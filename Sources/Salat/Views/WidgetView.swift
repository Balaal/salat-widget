import SwiftUI
import PrayerKit

/// The desktop widget. Renders in three sizes and two styles (dynamic sky, or translucent glass).
struct WidgetView: View {
    @Environment(AppModel.self) private var model
    let size: WidgetSize
    let style: WidgetStyle

    private var dimensions: CGSize {
        switch size {
        case .small: return CGSize(width: 170, height: 170)
        case .medium: return CGSize(width: 344, height: 170)
        case .large: return CGSize(width: 344, height: 400)
        }
    }

    private var onSky: Bool { style == .sky }

    var body: some View {
        content
            .padding(16)
            .frame(width: dimensions.width, height: dimensions.height)
            .foregroundStyle(onSky ? Color.white : Color.primary)
            .background {
                if onSky {
                    SkyBackground(phase: SkyPhase.at(model.now, today: model.today))
                } else {
                    VisualEffectBackground()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(onSky ? 0.12 : 0.18), lineWidth: 0.5))
            .localized(model)
    }

    @ViewBuilder private var content: some View {
        switch size {
        case .small: smallContent
        case .medium:
            HStack(spacing: 14) {
                smallContent
                Rectangle().fill(.white.opacity(onSky ? 0.18 : 0)).frame(width: 0.5)
                    .background(Color.primary.opacity(onSky ? 0 : 0.12))
                compactList
            }
        case .large:
            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    smallContent
                    Spacer()
                }
                CelestialArc(now: model.now, today: model.today, tomorrow: model.tomorrow, yesterday: model.yesterday)
                    .frame(height: 34)
                    .opacity(onSky ? 1 : 0.8)
                compactList
            }
        }
    }

    private var smallContent: some View {
        let next = model.nextEvent
        let fmt = model.fmt
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: next.prayer.fillSymbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(onSky ? Color.salatGold : Color.accentColor)
                Text(model.settings.location?.name ?? "—")
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .opacity(0.85)
            }
            Spacer(minLength: 0)
            Text(model.L.t("hero.next"))
                .font(.system(size: 10, weight: .semibold))
                .opacity(0.7)
            Text(model.displayName(next.prayer, on: next.date))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(fmt.clockCountdown(next.date.timeIntervalSince(model.now)))
                .font(.system(size: 22, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
            Text(fmt.time(next.date))
                .font(.system(size: 11, weight: .medium))
                .opacity(0.75)
        }
        .frame(maxWidth: size == .small ? .infinity : 140, alignment: .leading)
        .frame(height: size == .large ? 128 : nil)
    }

    private var compactList: some View {
        let next = model.nextEvent
        // After Isha, show tomorrow's schedule so the highlighted row is the upcoming Fajr.
        let times = next.day == model.today.day ? model.today : model.times(for: next.day)
        let current = model.currentEvent
        return VStack(spacing: size == .large ? 6 : 3) {
            ForEach(Prayer.allCases) { p in
                let date = times.time(for: p)
                let isNext = next.prayer == p && next.day == times.day
                let isCurrent = current?.prayer == p && current?.day == times.day
                HStack(spacing: 6) {
                    Image(systemName: p.symbol)
                        .font(.system(size: 10))
                        .frame(width: 14)
                        .opacity(0.8)
                    Text(model.displayName(p, on: date))
                        .font(.system(size: size == .large ? 13 : 11.5, weight: isNext ? .bold : .regular))
                    Spacer(minLength: 2)
                    Text(model.fmt.time(date))
                        .font(.system(size: size == .large ? 13 : 11.5, weight: isNext ? .bold : .regular, design: .rounded))
                        .monospacedDigit()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, size == .large ? 3 : 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isNext ? (onSky ? Color.white.opacity(0.2) : Color.accentColor.opacity(0.18)) : .clear)
                )
                .opacity(date < model.now && !isCurrent ? 0.55 : 1)
            }
            if size == .large {
                Spacer(minLength: 0)
                Text(model.fmt.hijri(model.now, offsetDays: model.settings.hijriOffset))
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.75)
            }
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
