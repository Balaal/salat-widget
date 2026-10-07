import SwiftUI
import PrayerKit

struct PopoverView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @State private var dayOffset = 0

    var body: some View {
        VStack(spacing: 0) {
            HeroHeader()
            if model.azan.isPlaying && !model.azan.isPreview {
                AzanBanner()
            }
            DayNavigator(offset: $dayOffset)
            PrayerList(day: model.todayDay.adding(days: dayOffset), isToday: dayOffset == 0)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            Divider().opacity(0.5)
            FooterBar()
        }
        .frame(width: 360)
        .localized(model)
        .onAppear { model.windowOpener = { openWindow(id: $0) } }
    }
}

// MARK: - Header

struct HeroHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let next = model.nextEvent
        let fmt = model.fmt
        let L = model.L
        let phase = SkyPhase.at(model.now, today: model.today)
        let remaining = next.date.timeIntervalSince(model.now)

        ZStack(alignment: .top) {
            SkyBackground(phase: phase)

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    Button { model.open("settings") } label: {
                        Label(model.settings.location?.name ?? L.t("location.none"), systemImage: model.settings.locationMode == .automatic ? "location.fill" : "mappin.and.ellipse")
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(fmt.hijri(model.now, offsetDays: model.settings.hijriOffset))
                            .font(.system(size: 11.5, weight: .semibold))
                        Text(fmt.weekdayDate(model.now))
                            .font(.system(size: 10.5))
                            .opacity(0.8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                VStack(spacing: 2) {
                    Text(L.t("hero.next").uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(model.isArabic ? 0 : 2)
                        .opacity(0.75)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(model.displayName(next.prayer, on: next.date))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        if !model.isArabic {
                            Text(model.arabicName(next.prayer, on: next.date))
                                .font(.system(size: 22, weight: .medium))
                                .opacity(0.75)
                        }
                    }
                    Text(fmt.clockCountdown(remaining))
                        .font(.system(size: 30, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                    Text(L.t("hero.at").replacingOccurrences(of: "{time}", with: fmt.time(next.date)))
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.8)
                }
                .padding(.top, 6)

                CelestialArc(now: model.now, today: model.today, tomorrow: model.tomorrow, yesterday: model.yesterday)
                    .frame(height: 44)
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        }
        .frame(height: 232)
        .clipped()
    }
}

struct AzanBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.wave.2.fill")
                .symbolEffect(.variableColor.iterative, isActive: true)
                .foregroundStyle(Color.salatGold)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.L.t("azan.playing"))
                    .font(.system(size: 12, weight: .semibold))
                if let p = model.azan.playingPrayer {
                    Text(model.displayName(p, on: model.now))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(model.L.t("azan.stop")) { model.azan.stop() }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.thinMaterial)
    }
}

// MARK: - Day navigation

struct DayNavigator: View {
    @Environment(AppModel.self) private var model
    @Binding var offset: Int

    var body: some View {
        let date = model.now.addingTimeInterval(Double(offset) * 86400)
        HStack {
            Button { offset -= 1 } label: { Image(systemName: "chevron.backward") }
                .buttonStyle(.borderless)
            Spacer()
            Button {
                offset = 0
            } label: {
                VStack(spacing: 0) {
                    Text(offset == 0 ? model.L.t("day.today") : model.fmt.shortDate(date))
                        .font(.system(size: 12, weight: .semibold))
                    if offset != 0 {
                        Text(model.fmt.hijri(date, offsetDays: model.settings.hijriOffset, includeYear: false))
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .help(model.L.t("day.backToToday"))
            Spacer()
            Button { offset += 1 } label: { Image(systemName: "chevron.forward") }
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }
}

// MARK: - Prayer list

struct PrayerList: View {
    @Environment(AppModel.self) private var model
    let day: CalendarDay
    let isToday: Bool

    var body: some View {
        let times = model.times(for: day)
        let current = isToday ? model.currentEvent : nil
        let next = isToday ? model.nextEvent : nil
        VStack(spacing: 2) {
            if model.settings.showImsak {
                ExtraRow(title: model.L.t("extra.imsak"), date: times.imsak, symbol: "fork.knife")
            }
            ForEach(Prayer.allCases) { prayer in
                let date = times.time(for: prayer)
                PrayerRow(prayer: prayer, date: date,
                          isCurrent: current?.prayer == prayer && current?.day == day,
                          isNext: next?.prayer == prayer && next?.day == day,
                          isPast: isToday && date <= model.now && !(current?.prayer == prayer && current?.day == day))
            }
            if model.settings.showMidnight {
                ExtraRow(title: model.L.t("extra.midnight"), date: times.midnight, symbol: "moon.haze")
            }
            if model.settings.showLastThird {
                ExtraRow(title: model.L.t("extra.lastThird"), date: times.lastThird, symbol: "sparkles")
            }
        }
    }
}

struct PrayerRow: View {
    @Environment(AppModel.self) private var model
    let prayer: Prayer
    let date: Date
    let isCurrent: Bool
    let isNext: Bool
    let isPast: Bool
    @State private var hovering = false

    var body: some View {
        let pref = model.settings.preference(for: prayer)
        let fmt = model.fmt
        let L = model.L
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isCurrent ? Color.accentColor.opacity(0.9) : Color.primary.opacity(0.07))
                Image(systemName: isCurrent ? prayer.fillSymbol : prayer.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isCurrent ? Color.white : Color.primary.opacity(0.8))
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text(model.displayName(prayer, on: date))
                        .font(.system(size: 13.5, weight: isCurrent || isNext ? .semibold : .regular))
                    if !model.isArabic {
                        Text(model.arabicName(prayer, on: date))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    if isCurrent {
                        Text(L.t("row.now"))
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                if isNext {
                    Text(L.t("row.in").replacingOccurrences(of: "{d}", with: fmt.shortCountdown(date.timeIntervalSince(model.now))))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 4)

            Text(fmt.time(date))
                .font(.system(size: 14, weight: isCurrent || isNext ? .semibold : .regular, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 2) {
                ToggleIcon(on: pref.notify, onSymbol: "bell.fill", offSymbol: "bell.slash",
                           help: L.t(pref.notify ? "row.notifyOn" : "row.notifyOff")) {
                    var p = pref; p.notify.toggle()
                    model.settings.setPreference(p, for: prayer)
                }
                if prayer.isObligatory {
                    ToggleIcon(on: pref.azan, onSymbol: "speaker.wave.2.fill", offSymbol: "speaker.slash",
                               help: L.t(pref.azan ? "row.azanOn" : "row.azanOff")) {
                        var p = pref; p.azan.toggle()
                        model.settings.setPreference(p, for: prayer)
                    }
                } else {
                    Color.clear.frame(width: 24, height: 24)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isCurrent ? Color.accentColor.opacity(0.12)
                      : (hovering ? Color.primary.opacity(0.05) : .clear))
        )
        .opacity(isPast ? 0.5 : 1)
        .onHover { hovering = $0 }
    }
}

struct ToggleIcon: View {
    let on: Bool
    let onSymbol: String
    let offSymbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: on ? onSymbol : offSymbol)
                .font(.system(size: 11.5))
                .foregroundStyle(on ? Color.accentColor : Color.secondary.opacity(0.6))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct ExtraRow: View {
    @Environment(AppModel.self) private var model
    let title: String
    let date: Date
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .frame(width: 28)
                .foregroundStyle(.secondary)
            Text(title).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Text(model.fmt.time(date))
                .font(.system(size: 12, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Color.clear.frame(width: 50, height: 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
}

// MARK: - Footer

struct FooterBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let L = model.L
        HStack(spacing: 4) {
            if let loc = model.settings.location {
                let q = Qibla.direction(from: loc.coordinates)
                HStack(spacing: 4) {
                    Image(systemName: "location.north.line.fill")
                        .rotationEffect(.degrees(q))
                        .foregroundStyle(Color.accentColor)
                        .environment(\.layoutDirection, .leftToRight) // compass bearings never mirror
                    Text("\(L.t("qibla")) \(model.fmt.degrees(q))")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .help(L.t("qibla.help"))
            }
            Spacer()
            FooterButton(symbol: "calendar", help: L.t("footer.timetable")) { model.open("timetable") }
            FooterButton(symbol: model.settings.widgetEnabled ? "rectangle.inset.filled.on.rectangle" : "rectangle.on.rectangle",
                         help: L.t("footer.widget")) {
                model.settings.widgetEnabled.toggle()
            }
            FooterButton(symbol: "gearshape", help: L.t("footer.settings")) { model.open("settings") }
            FooterButton(symbol: "power", help: L.t("footer.quit")) { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

struct FooterButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .frame(width: 28, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Color.primary.opacity(0.08) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
    }
}

// MARK: - Localization environment

extension View {
    func localized(_ model: AppModel) -> some View {
        environment(\.layoutDirection, model.isArabic ? .rightToLeft : .leftToRight)
            .environment(\.locale, model.fmt.locale)
    }
}
