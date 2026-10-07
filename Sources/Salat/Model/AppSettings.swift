import Foundation
import PrayerKit

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system, english, arabic
    var id: String { rawValue }

    var resolved: AppLanguage {
        guard self == .system else { return self }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("ar") ? .arabic : .english
    }
}

enum ClockStyle: String, Codable, CaseIterable, Identifiable {
    case system, twelveHour, twentyFourHour
    var id: String { rawValue }
}

enum MenuBarStyle: String, Codable, CaseIterable, Identifiable {
    case iconOnly, nameAndCountdown, nameAndTime, countdownOnly
    var id: String { rawValue }
}

enum LocationMode: String, Codable, CaseIterable, Identifiable {
    case automatic, manual
    var id: String { rawValue }
}

enum WidgetSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
}

enum WidgetStyle: String, Codable, CaseIterable, Identifiable {
    case sky, glass
    var id: String { rawValue }
}

enum CustomIshaMode: String, Codable, CaseIterable, Identifiable {
    case angle, minutes
    var id: String { rawValue }
}

struct SavedLocation: Codable, Hashable {
    var name: String
    var country: String?
    var countryCode: String?
    var coordinates: Coordinates
    var timeZoneID: String

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
    var displayName: String {
        [name, country].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: ", ")
    }
}

struct PrayerPreference: Codable, Hashable {
    var notify: Bool
    var azan: Bool
    var reminder: Bool
}

struct AppSettings: Codable, Equatable {
    // General
    var language: AppLanguage = .system
    var easternArabicNumerals = true
    var clockStyle: ClockStyle = .system
    var menuBarStyle: MenuBarStyle = .nameAndCountdown
    var menuBarSeconds = false
    var hijriOffset = 0
    var showImsak = false
    var showMidnight = false
    var showLastThird = false

    // Location
    var locationMode: LocationMode = .automatic
    var location: SavedLocation?

    // Calculation
    var method: CalculationMethod = .muslimWorldLeague
    var autoMethod = true
    var madhab: Madhab = .standard
    var highLatitudeRule: HighLatitudeRule = .automatic
    var adjustments = PrayerAdjustments()
    var customFajrAngle = 18.0
    var customIshaMode: CustomIshaMode = .angle
    var customIshaAngle = 17.0
    var customIshaMinutes = 90.0

    // Alerts
    var preferences: [String: PrayerPreference] = AppSettings.defaultPreferences
    var reminderMinutes = 10

    // Azan
    var azanSound = AzanSound.defaultID
    var fajrAzanSound = AzanSound.defaultID
    var customAzanPath: String?
    var azanVolume = 0.8
    var azanFadeIn = true
    var shortAzan = false

    // Desktop widget
    var widgetEnabled = false
    var widgetFloating = false
    var widgetSize: WidgetSize = .medium
    var widgetStyle: WidgetStyle = .sky
    var widgetOriginX: Double?
    var widgetOriginY: Double?

    // Onboarding
    var hasCompletedOnboarding = false

    static let defaultPreferences: [String: PrayerPreference] = {
        var d: [String: PrayerPreference] = [:]
        for p in Prayer.allCases {
            d[p.rawValue] = p == .sunrise
                ? PrayerPreference(notify: false, azan: false, reminder: false)
                : PrayerPreference(notify: true, azan: true, reminder: false)
        }
        return d
    }()

    func preference(for prayer: Prayer) -> PrayerPreference {
        preferences[prayer.rawValue] ?? AppSettings.defaultPreferences[prayer.rawValue]!
    }

    mutating func setPreference(_ pref: PrayerPreference, for prayer: Prayer) {
        preferences[prayer.rawValue] = pref
    }

    var calculationParameters: CalculationParameters {
        guard method == .custom else { return method.parameters }
        return CalculationParameters(
            fajrAngle: customFajrAngle,
            isha: customIshaMode == .angle ? .angle(customIshaAngle) : .minutes(customIshaMinutes)
        )
    }

    init() {}

    // Tolerant decoding: any missing or renamed key falls back to its default,
    // so adding settings never wipes a user's existing configuration.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        func v<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        language = v(.language, d.language)
        easternArabicNumerals = v(.easternArabicNumerals, d.easternArabicNumerals)
        clockStyle = v(.clockStyle, d.clockStyle)
        menuBarStyle = v(.menuBarStyle, d.menuBarStyle)
        menuBarSeconds = v(.menuBarSeconds, d.menuBarSeconds)
        hijriOffset = v(.hijriOffset, d.hijriOffset)
        showImsak = v(.showImsak, d.showImsak)
        showMidnight = v(.showMidnight, d.showMidnight)
        showLastThird = v(.showLastThird, d.showLastThird)
        locationMode = v(.locationMode, d.locationMode)
        location = v(.location, d.location)
        method = v(.method, d.method)
        autoMethod = v(.autoMethod, d.autoMethod)
        madhab = v(.madhab, d.madhab)
        highLatitudeRule = v(.highLatitudeRule, d.highLatitudeRule)
        adjustments = v(.adjustments, d.adjustments)
        customFajrAngle = v(.customFajrAngle, d.customFajrAngle)
        customIshaMode = v(.customIshaMode, d.customIshaMode)
        customIshaAngle = v(.customIshaAngle, d.customIshaAngle)
        customIshaMinutes = v(.customIshaMinutes, d.customIshaMinutes)
        preferences = v(.preferences, d.preferences)
        reminderMinutes = v(.reminderMinutes, d.reminderMinutes)
        azanSound = v(.azanSound, d.azanSound)
        fajrAzanSound = v(.fajrAzanSound, d.fajrAzanSound)
        customAzanPath = v(.customAzanPath, d.customAzanPath)
        azanVolume = v(.azanVolume, d.azanVolume)
        azanFadeIn = v(.azanFadeIn, d.azanFadeIn)
        shortAzan = v(.shortAzan, d.shortAzan)
        widgetEnabled = v(.widgetEnabled, d.widgetEnabled)
        widgetFloating = v(.widgetFloating, d.widgetFloating)
        widgetSize = v(.widgetSize, d.widgetSize)
        widgetStyle = v(.widgetStyle, d.widgetStyle)
        widgetOriginX = v(.widgetOriginX, d.widgetOriginX)
        widgetOriginY = v(.widgetOriginY, d.widgetOriginY)
        hasCompletedOnboarding = v(.hasCompletedOnboarding, d.hasCompletedOnboarding)
    }
}

enum SettingsPersistence {
    private static let key = "settings.v1"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
        return s
    }

    static func save(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
