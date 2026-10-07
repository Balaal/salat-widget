import Foundation

/// Low-level solar math (degree-based trigonometry, Julian dates, sun position).
/// Formulas follow the U.S. Naval Observatory approximations used by PrayTimes.org.
enum Astronomy {
    static func dsin(_ d: Double) -> Double { sin(d * .pi / 180) }
    static func dcos(_ d: Double) -> Double { cos(d * .pi / 180) }
    static func dtan(_ d: Double) -> Double { tan(d * .pi / 180) }
    static func darcsin(_ x: Double) -> Double { asin(x) * 180 / .pi }
    static func darccos(_ x: Double) -> Double { acos(x) * 180 / .pi }
    static func darctan2(_ y: Double, _ x: Double) -> Double { atan2(y, x) * 180 / .pi }
    static func darccot(_ x: Double) -> Double { atan(1 / x) * 180 / .pi }

    static func fix(_ a: Double, _ mode: Double) -> Double {
        let r = a - mode * floor(a / mode)
        return r < 0 ? r + mode : r
    }
    static func fixAngle(_ a: Double) -> Double { fix(a, 360) }
    static func fixHour(_ a: Double) -> Double { fix(a, 24) }

    /// Julian date at 0h UT of the given Gregorian calendar day.
    static func julianDate(year: Int, month: Int, day: Int) -> Double {
        var y = Double(year), m = Double(month)
        if m <= 2 { y -= 1; m += 12 }
        let a = floor(y / 100)
        let b = 2 - a + floor(a / 4)
        return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + Double(day) + b - 1524.5
    }

    struct SunPosition {
        let declination: Double
        let equationOfTime: Double // hours
    }

    static func sunPosition(julianDate jd: Double) -> SunPosition {
        let d = jd - 2451545.0
        let g = fixAngle(357.529 + 0.98560028 * d)
        let q = fixAngle(280.459 + 0.98564736 * d)
        let l = fixAngle(q + 1.915 * dsin(g) + 0.020 * dsin(2 * g))
        let e = 23.439 - 0.00000036 * d
        let ra = darctan2(dcos(e) * dsin(l), dcos(l)) / 15
        let eqt = q / 15 - fixHour(ra)
        let decl = darcsin(dsin(e) * dsin(l))
        return SunPosition(declination: decl, equationOfTime: eqt)
    }
}
