import SwiftUI
import PrayerKit
import UniformTypeIdentifiers

/// Month-at-a-glance timetable with CSV export.
struct TimetableView: View {
    @Environment(AppModel.self) private var model
    @State private var monthOffset = 0

    private var monthDays: [CalendarDay] {
        let today = model.todayDay
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = model.timeZone
        let first = cal.date(from: DateComponents(year: today.year, month: today.month, day: 1))!
        let target = cal.date(byAdding: .month, value: monthOffset, to: first)!
        let range = cal.range(of: .day, in: .month, for: target)!
        let c = cal.dateComponents([.year, .month], from: target)
        return range.map { CalendarDay(year: c.year!, month: c.month!, day: $0) }
    }

    var body: some View {
        let L = model.L
        let fmt = model.fmt
        let days = monthDays
        let today = model.todayDay
        let columns = Prayer.allCases

        VStack(spacing: 0) {
            HStack {
                Button { monthOffset -= 1 } label: { Image(systemName: "chevron.backward") }
                Spacer()
                VStack(spacing: 2) {
                    Text(fmt.monthYear(days[0].startDate(in: model.timeZone).addingTimeInterval(43200)))
                        .font(.title2.bold())
                    Text("\(model.settings.location?.displayName ?? "") · \(L.t("method.\(model.settings.method.rawValue)"))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { monthOffset += 1 } label: { Image(systemName: "chevron.forward") }
            }
            .buttonStyle(.borderless)
            .padding()

            ScrollViewReader { proxy in
                ScrollView {
                    Grid(alignment: .center, horizontalSpacing: 0, verticalSpacing: 0) {
                        GridRow {
                            Text(L.t("timetable.date")).gridColumnAlignment(.leading)
                            ForEach(columns) { Text(L.t("prayer.\($0.rawValue)")) }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)

                        ForEach(days, id: \.self) { day in
                            let t = model.times(for: day)
                            let noon = day.startDate(in: model.timeZone).addingTimeInterval(43200)
                            let isToday = day == today
                            GridRow {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(fmt.shortDate(noon)).font(.system(size: 12, weight: isToday ? .bold : .medium))
                                    Text(fmt.hijri(noon, offsetDays: model.settings.hijriOffset, includeYear: false))
                                        .font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                                .frame(width: 130, alignment: .leading)
                                ForEach(columns) { p in
                                    Text(fmt.time(t.time(for: p)))
                                        .font(.system(size: 12, weight: isToday ? .bold : .regular, design: .rounded))
                                        .monospacedDigit()
                                        .frame(width: 78)
                                        .foregroundStyle(fmt.isFriday(noon) && p == .dhuhr ? Color.accentColor : .primary)
                                }
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                            .background(isToday ? Color.accentColor.opacity(0.15)
                                        : (day.day % 2 == 0 ? Color.primary.opacity(0.03) : .clear))
                            .id(day)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .onAppear { proxy.scrollTo(today, anchor: .center) }
            }

            Divider()
            HStack {
                Text(L.t("timetable.fridayNote")).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(L.t("timetable.export")) { exportCSV(days) }
            }
            .padding(10)
        }
        .frame(width: 640, height: 600)
        .navigationTitle(L.t("footer.timetable"))
    }

    private func exportCSV(_ days: [CalendarDay]) {
        var f = model.fmt
        f = Fmt(arabic: false, easternDigits: false, clock: .twentyFourHour, timeZone: model.timeZone)
        var csv = "Date,Fajr,Sunrise,Dhuhr,Asr,Maghrib,Isha\n"
        for d in days {
            let t = model.times(for: d)
            let cols = Prayer.allCases.map { f.time(t.time(for: $0)) }
            csv += String(format: "%04d-%02d-%02d,", d.year, d.month, d.day) + cols.joined(separator: ",") + "\n"
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = String(format: "prayer-times-%04d-%02d.csv", days[0].year, days[0].month)
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
