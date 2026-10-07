import Foundation
import PrayerKit

// Prints prayer times as JSON lines so they can be diffed against a reference timetable.
// Usage: prayerkit-check <lat> <lng> <tz> <method> <yyyy-mm-dd> [hanafi]
let args = CommandLine.arguments
guard args.count >= 6,
      let lat = Double(args[1]), let lng = Double(args[2]),
      let tz = TimeZone(identifier: args[3]),
      let method = CalculationMethod(rawValue: args[4]) else {
    print("usage: prayerkit-check <lat> <lng> <tz> <method> <yyyy-mm-dd> [hanafi]")
    exit(1)
}
let parts = args[5].split(separator: "-").compactMap { Int($0) }
let day = CalendarDay(year: parts[0], month: parts[1], day: parts[2])
let calc = PrayerCalculator(
    coordinates: Coordinates(latitude: lat, longitude: lng),
    parameters: method.parameters,
    madhab: args.count > 6 && args[6] == "hanafi" ? .hanafi : .standard
)
let t = calc.times(for: day)
let f = DateFormatter()
f.timeZone = tz
f.dateFormat = "HH:mm"
let out: [String: String] = [
    "Fajr": f.string(from: t.fajr), "Sunrise": f.string(from: t.sunrise), "Dhuhr": f.string(from: t.dhuhr),
    "Asr": f.string(from: t.asr), "Maghrib": f.string(from: t.maghrib), "Isha": f.string(from: t.isha),
    "Midnight": f.string(from: t.midnight),
]
let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
print(String(data: data, encoding: .utf8)!)
