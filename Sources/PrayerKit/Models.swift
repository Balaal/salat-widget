import Foundation

public struct Coordinates: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var elevation: Double

    public init(latitude: Double, longitude: Double, elevation: Double = 0) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
    }
}

/// Everything shown in the day's timeline. Only five of these are obligatory prayers;
/// sunrise marks the end of Fajr time.
public enum Prayer: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha

    public var id: String { rawValue }
    public var isObligatory: Bool { self != .sunrise }
}

/// Juristic method for Asr: the shadow-length factor.
public enum Madhab: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Shafi'i, Maliki, Hanbali (shadow = 1x object length).
    case standard
    /// Hanafi (shadow = 2x object length).
    case hanafi

    public var id: String { rawValue }
    var shadowFactor: Double { self == .hanafi ? 2 : 1 }
}

public enum HighLatitudeRule: String, CaseIterable, Codable, Sendable, Identifiable {
    case automatic, none, middleOfNight, seventhOfNight, angleBased

    public var id: String { rawValue }

    func resolved(for latitude: Double) -> HighLatitudeRule {
        guard self == .automatic else { return self }
        return abs(latitude) > 48 ? .seventhOfNight : .middleOfNight
    }
}

public enum MidnightMode: String, Codable, Sendable {
    /// Midpoint of sunset and sunrise.
    case standard
    /// Midpoint of sunset and Fajr (Shia).
    case jafari
}

/// Per-prayer minute offsets.
public struct PrayerAdjustments: Codable, Hashable, Sendable {
    public var fajr: Int = 0
    public var sunrise: Int = 0
    public var dhuhr: Int = 0
    public var asr: Int = 0
    public var maghrib: Int = 0
    public var isha: Int = 0

    public init(fajr: Int = 0, sunrise: Int = 0, dhuhr: Int = 0, asr: Int = 0, maghrib: Int = 0, isha: Int = 0) {
        self.fajr = fajr; self.sunrise = sunrise; self.dhuhr = dhuhr
        self.asr = asr; self.maghrib = maghrib; self.isha = isha
    }

    public subscript(prayer: Prayer) -> Int {
        get {
            switch prayer {
            case .fajr: fajr
            case .sunrise: sunrise
            case .dhuhr: dhuhr
            case .asr: asr
            case .maghrib: maghrib
            case .isha: isha
            }
        }
        set {
            switch prayer {
            case .fajr: fajr = newValue
            case .sunrise: sunrise = newValue
            case .dhuhr: dhuhr = newValue
            case .asr: asr = newValue
            case .maghrib: maghrib = newValue
            case .isha: isha = newValue
            }
        }
    }

    static func + (lhs: PrayerAdjustments, rhs: PrayerAdjustments) -> PrayerAdjustments {
        var out = PrayerAdjustments()
        for p in Prayer.allCases { out[p] = lhs[p] + rhs[p] }
        return out
    }
}

/// How Isha (or Maghrib) is defined: by a sun depression angle or by minutes after sunset/maghrib.
public enum TwilightRule: Codable, Hashable, Sendable {
    case angle(Double)
    case minutes(Double)
}

public struct CalculationParameters: Codable, Hashable, Sendable {
    public var fajrAngle: Double
    public var isha: TwilightRule
    /// Isha interval used during Ramadan (Umm al-Qura uses 120 minutes instead of 90).
    public var ishaRamadanMinutes: Double?
    /// Maghrib after sunset; `.minutes(0)` means at sunset.
    public var maghrib: TwilightRule
    public var midnight: MidnightMode
    /// Offsets baked into the method (e.g. Diyanet's temkin).
    public var methodAdjustments: PrayerAdjustments
    /// Moonsighting Committee seasonal twilight model.
    public var seasonalTwilight: Bool

    public init(
        fajrAngle: Double,
        isha: TwilightRule,
        ishaRamadanMinutes: Double? = nil,
        maghrib: TwilightRule = .minutes(0),
        midnight: MidnightMode = .standard,
        methodAdjustments: PrayerAdjustments = PrayerAdjustments(),
        seasonalTwilight: Bool = false
    ) {
        self.fajrAngle = fajrAngle
        self.isha = isha
        self.ishaRamadanMinutes = ishaRamadanMinutes
        self.maghrib = maghrib
        self.midnight = midnight
        self.methodAdjustments = methodAdjustments
        self.seasonalTwilight = seasonalTwilight
    }
}

/// A Gregorian calendar day, independent of time zone.
public struct CalendarDay: Codable, Hashable, Sendable, Comparable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
    }

    public init(date: Date, timeZone: TimeZone) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    /// Midnight at the start of this day in the given time zone.
    public func startDate(in timeZone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public func adding(days: Int) -> CalendarDay {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let base = cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        let next = cal.date(byAdding: .day, value: days, to: base)!
        return CalendarDay(date: next, timeZone: cal.timeZone)
    }

    var dayOfYear: Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let d = cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        return cal.ordinality(of: .day, in: .year, for: d)!
    }

    var isLeapYear: Bool { (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 }

    public static func < (a: CalendarDay, b: CalendarDay) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }
}

public struct PrayerTimes: Hashable, Sendable {
    public let day: CalendarDay
    public let imsak: Date
    public let fajr: Date
    public let sunrise: Date
    public let dhuhr: Date
    public let asr: Date
    public let maghrib: Date
    public let isha: Date
    public let midnight: Date
    public let lastThird: Date

    public func time(for prayer: Prayer) -> Date {
        switch prayer {
        case .fajr: fajr
        case .sunrise: sunrise
        case .dhuhr: dhuhr
        case .asr: asr
        case .maghrib: maghrib
        case .isha: isha
        }
    }
}
