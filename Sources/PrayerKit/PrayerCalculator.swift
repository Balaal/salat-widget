import Foundation

/// Computes daily prayer times for a location.
///
/// All internal math happens in "hours after 0h UTC of the requested day", so results are
/// absolute instants and the caller only needs a time zone for *display*.
public struct PrayerCalculator: Sendable {
    public var coordinates: Coordinates
    public var parameters: CalculationParameters
    public var madhab: Madhab
    public var highLatitudeRule: HighLatitudeRule
    public var adjustments: PrayerAdjustments
    public var imsakMinutes: Double

    /// Latitude used as a fallback when the sun never rises or sets (polar day/night).
    static let polarFallbackLatitude = 65.0

    public init(
        coordinates: Coordinates,
        parameters: CalculationParameters,
        madhab: Madhab = .standard,
        highLatitudeRule: HighLatitudeRule = .automatic,
        adjustments: PrayerAdjustments = PrayerAdjustments(),
        imsakMinutes: Double = 10
    ) {
        self.coordinates = coordinates
        self.parameters = parameters
        self.madhab = madhab
        self.highLatitudeRule = highLatitudeRule
        self.adjustments = adjustments
        self.imsakMinutes = imsakMinutes
    }

    public func times(for day: CalendarDay) -> PrayerTimes {
        var raw = rawTimes(for: day, latitude: coordinates.latitude)
        if raw.hasMissingValues {
            let lat = coordinates.latitude >= 0 ? Self.polarFallbackLatitude : -Self.polarFallbackLatitude
            raw = rawTimes(for: day, latitude: lat)
        }
        return finalize(raw, day: day)
    }

    // MARK: - Raw computation (hours, UTC)

    struct RawTimes {
        var fajr, sunrise, dhuhr, asr, sunset, maghrib, isha: Double
        var hasMissingValues: Bool {
            [fajr, sunrise, dhuhr, asr, sunset, maghrib, isha].contains { $0.isNaN }
        }
    }

    func rawTimes(for day: CalendarDay, latitude lat: Double) -> RawTimes {
        let lng = coordinates.longitude
        let jDate = Astronomy.julianDate(year: day.year, month: day.month, day: day.day) - lng / (15 * 24)

        func midDay(_ t: Double) -> Double {
            Astronomy.fixHour(12 - Astronomy.sunPosition(julianDate: jDate + t).equationOfTime)
        }
        func sunAngleTime(_ angle: Double, _ t: Double, ccw: Bool = false) -> Double {
            let decl = Astronomy.sunPosition(julianDate: jDate + t).declination
            let noon = midDay(t)
            let cosH = (-Astronomy.dsin(angle) - Astronomy.dsin(decl) * Astronomy.dsin(lat))
                / (Astronomy.dcos(decl) * Astronomy.dcos(lat))
            guard cosH >= -1, cosH <= 1 else { return .nan }
            let h = Astronomy.darccos(cosH) / 15
            return noon + (ccw ? -h : h)
        }
        func asrTime(_ factor: Double, _ t: Double) -> Double {
            let decl = Astronomy.sunPosition(julianDate: jDate + t).declination
            let angle = -Astronomy.darccot(factor + Astronomy.dtan(abs(lat - decl)))
            return sunAngleTime(angle, t)
        }
        func portion(_ h: Double, _ fallback: Double) -> Double { (h.isNaN ? fallback : h) / 24 }

        let riseSet = 0.833 + 0.0347 * sqrt(max(0, coordinates.elevation))
        var t = RawTimes(fajr: 5, sunrise: 6, dhuhr: 12, asr: 13, sunset: 18, maghrib: 18, isha: 18)

        // Two refinement passes: each pass evaluates the sun's position at the previous estimate.
        for _ in 0..<2 {
            let fajr = sunAngleTime(parameters.fajrAngle, portion(t.fajr, 5), ccw: true)
            let sunrise = sunAngleTime(riseSet, portion(t.sunrise, 6), ccw: true)
            let dhuhr = midDay(portion(t.dhuhr, 12))
            let asr = asrTime(madhab.shadowFactor, portion(t.asr, 13))
            let sunset = sunAngleTime(riseSet, portion(t.sunset, 18))
            var maghrib = sunset
            if case .angle(let a) = parameters.maghrib { maghrib = sunAngleTime(a, portion(t.maghrib, 18)) }
            var isha = Double.nan
            if case .angle(let a) = parameters.isha { isha = sunAngleTime(a, portion(t.isha, 18)) }
            t = RawTimes(fajr: fajr, sunrise: sunrise, dhuhr: dhuhr, asr: asr, sunset: sunset, maghrib: maghrib, isha: isha)
        }

        // Local solar time -> UTC.
        let shift = -lng / 15
        t.fajr += shift; t.sunrise += shift; t.dhuhr += shift; t.asr += shift
        t.sunset += shift; t.maghrib += shift; t.isha += shift

        let night = Astronomy.fixHour(t.sunrise - t.sunset)

        if case .minutes(let m) = parameters.maghrib { t.maghrib = t.sunset + m / 60 }

        if parameters.seasonalTwilight {
            applySeasonalTwilight(&t, day: day, latitude: lat, night: night)
        } else {
            applyHighLatitudeRule(&t, latitude: lat, night: night)
        }

        if case .minutes(var m) = parameters.isha {
            if let ramadan = parameters.ishaRamadanMinutes, Self.isRamadan(day) { m = ramadan }
            t.isha = t.maghrib + m / 60
        }
        return t
    }

    func applyHighLatitudeRule(_ t: inout RawTimes, latitude: Double, night: Double) {
        let rule = highLatitudeRule.resolved(for: latitude)
        guard rule != .none, !night.isNaN else { return }

        func nightPortion(_ angle: Double) -> Double {
            switch rule {
            case .angleBased: return angle / 60 * night
            case .seventhOfNight: return night / 7
            default: return night / 2
            }
        }

        let fajrPortion = nightPortion(parameters.fajrAngle)
        if t.fajr.isNaN || Astronomy.fixHour(t.sunrise - t.fajr) > fajrPortion {
            t.fajr = t.sunrise - fajrPortion
        }
        if case .angle(let a) = parameters.isha {
            let p = nightPortion(a)
            if t.isha.isNaN || Astronomy.fixHour(t.isha - t.sunset) > p { t.isha = t.sunset + p }
        }
        if case .angle(let a) = parameters.maghrib {
            let p = nightPortion(a)
            if t.maghrib.isNaN || Astronomy.fixHour(t.maghrib - t.sunset) > p { t.maghrib = t.sunset + p }
        }
    }

    /// Moonsighting Committee (Khalid Shaukat) seasonal model for Fajr and Isha.
    func applySeasonalTwilight(_ t: inout RawTimes, day: CalendarDay, latitude: Double, night: Double) {
        if abs(latitude) >= 55 {
            t.fajr = t.sunrise - night / 7
            t.isha = t.sunset + night / 7
            return
        }
        let dyy = Double(Self.daysSinceSolstice(day: day, latitude: latitude))
        let absLat = abs(latitude)

        let safeFajr = t.sunrise - Self.seasonalAdjustment(
            dyy: dyy,
            a: 75 + 28.65 / 55 * absLat, b: 75 + 19.44 / 55 * absLat,
            c: 75 + 32.74 / 55 * absLat, d: 75 + 48.10 / 55 * absLat) / 60
        if t.fajr.isNaN || safeFajr > t.fajr { t.fajr = safeFajr }

        if case .angle = parameters.isha {
            let safeIsha = t.sunset + Self.seasonalAdjustment(
                dyy: dyy,
                a: 75 + 25.60 / 55 * absLat, b: 75 + 2.050 / 55 * absLat,
                c: 75 - 9.210 / 55 * absLat, d: 75 + 6.140 / 55 * absLat) / 60
            if t.isha.isNaN || safeIsha < t.isha { t.isha = safeIsha }
        }
    }

    static func seasonalAdjustment(dyy: Double, a: Double, b: Double, c: Double, d: Double) -> Double {
        switch dyy {
        case ..<91: return a + (b - a) / 91 * dyy
        case ..<137: return b + (c - b) / 46 * (dyy - 91)
        case ..<183: return c + (d - c) / 46 * (dyy - 137)
        case ..<229: return d + (c - d) / 46 * (dyy - 183)
        case ..<275: return c + (b - c) / 46 * (dyy - 229)
        default: return b + (a - b) / 91 * (dyy - 275)
        }
    }

    static func daysSinceSolstice(day: CalendarDay, latitude: Double) -> Int {
        let daysInYear = day.isLeapYear ? 366 : 365
        if latitude >= 0 {
            var d = day.dayOfYear + 10
            if d >= daysInYear { d -= daysInYear }
            return d
        } else {
            var d = day.dayOfYear - (day.isLeapYear ? 173 : 172)
            if d < 0 { d += daysInYear }
            return d
        }
    }

    static func isRamadan(_ day: CalendarDay) -> Bool {
        var greg = Calendar(identifier: .gregorian)
        greg.timeZone = TimeZone(identifier: "UTC")!
        guard let date = greg.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)) else {
            return false
        }
        var hijri = Calendar(identifier: .islamicUmmAlQura)
        hijri.timeZone = greg.timeZone
        return hijri.component(.month, from: date) == 9
    }

    // MARK: - Finalize

    func finalize(_ t: RawTimes, day: CalendarDay) -> PrayerTimes {
        let utc = TimeZone(identifier: "UTC")!
        let base = day.startDate(in: utc)
        let adj = parameters.methodAdjustments + adjustments

        func date(_ hours: Double, _ minutes: Int = 0) -> Date {
            let seconds = hours * 3600 + Double(minutes) * 60
            // Round to the nearest minute, like printed timetables.
            return base.addingTimeInterval((seconds / 60).rounded() * 60)
        }

        let night = Astronomy.fixHour(t.sunrise - t.sunset)
        let midnightNight = parameters.midnight == .jafari ? Astronomy.fixHour(t.fajr - t.sunset) : night
        let fajr = date(t.fajr, adj.fajr)

        return PrayerTimes(
            day: day,
            imsak: fajr.addingTimeInterval(-imsakMinutes * 60),
            fajr: fajr,
            sunrise: date(t.sunrise, adj.sunrise),
            dhuhr: date(t.dhuhr, adj.dhuhr),
            asr: date(t.asr, adj.asr),
            maghrib: date(t.maghrib, adj.maghrib),
            isha: date(t.isha, adj.isha),
            midnight: date(t.sunset + midnightNight / 2),
            lastThird: date(t.sunset + night * 2 / 3)
        )
    }
}

public enum Qibla {
    public static let kaaba = Coordinates(latitude: 21.4224779, longitude: 39.8251832)

    /// Bearing to the Kaaba in degrees clockwise from true north.
    public static func direction(from c: Coordinates) -> Double {
        let dLng = kaaba.longitude - c.longitude
        let y = Astronomy.dsin(dLng)
        let x = Astronomy.dcos(c.latitude) * Astronomy.dtan(kaaba.latitude)
            - Astronomy.dsin(c.latitude) * Astronomy.dcos(dLng)
        return Astronomy.fixAngle(Astronomy.darctan2(y, x))
    }

    /// Great-circle distance to the Kaaba in kilometres.
    public static func distance(from c: Coordinates) -> Double {
        let dLat = (kaaba.latitude - c.latitude) * .pi / 180
        let dLng = (kaaba.longitude - c.longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(c.latitude * .pi / 180) * cos(kaaba.latitude * .pi / 180) * sin(dLng / 2) * sin(dLng / 2)
        return 6371 * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
