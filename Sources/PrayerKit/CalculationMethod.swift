import Foundation

public enum CalculationMethod: String, CaseIterable, Codable, Sendable, Identifiable {
    case muslimWorldLeague
    case isna
    case egyptian
    case ummAlQura
    case karachi
    case dubai
    case gulf
    case kuwait
    case qatar
    case moonsightingCommittee
    case singapore
    case jakim
    case kemenag
    case turkey
    case tehran
    case jafari
    case france
    case russia
    case morocco
    case algeria
    case tunisia
    case custom

    public var id: String { rawValue }

    /// Parameters for the built-in methods. `.custom` returns MWL as a starting point.
    public var parameters: CalculationParameters {
        switch self {
        case .muslimWorldLeague, .custom:
            return .init(fajrAngle: 18, isha: .angle(17))
        case .isna:
            return .init(fajrAngle: 15, isha: .angle(15))
        case .egyptian:
            return .init(fajrAngle: 19.5, isha: .angle(17.5))
        case .ummAlQura:
            return .init(fajrAngle: 18.5, isha: .minutes(90), ishaRamadanMinutes: 120)
        case .karachi:
            return .init(fajrAngle: 18, isha: .angle(18))
        case .dubai:
            return .init(fajrAngle: 18.2, isha: .angle(18.2),
                         methodAdjustments: .init(sunrise: -3, dhuhr: 3, asr: 3, maghrib: 3))
        case .gulf:
            return .init(fajrAngle: 19.5, isha: .minutes(90))
        case .kuwait:
            return .init(fajrAngle: 18, isha: .angle(17.5))
        case .qatar:
            return .init(fajrAngle: 18, isha: .minutes(90))
        case .moonsightingCommittee:
            return .init(fajrAngle: 18, isha: .angle(18),
                         methodAdjustments: .init(dhuhr: 5, maghrib: 3),
                         seasonalTwilight: true)
        case .singapore:
            return .init(fajrAngle: 20, isha: .angle(18), methodAdjustments: .init(dhuhr: 1))
        case .jakim:
            return .init(fajrAngle: 20, isha: .angle(18))
        case .kemenag:
            return .init(fajrAngle: 20, isha: .angle(18))
        case .turkey:
            return .init(fajrAngle: 18, isha: .angle(17),
                         methodAdjustments: .init(sunrise: -7, dhuhr: 5, asr: 4, maghrib: 7))
        case .tehran:
            return .init(fajrAngle: 17.7, isha: .angle(14), maghrib: .angle(4.5), midnight: .jafari)
        case .jafari:
            return .init(fajrAngle: 16, isha: .angle(14), maghrib: .angle(4), midnight: .jafari)
        case .france:
            return .init(fajrAngle: 12, isha: .angle(12))
        case .russia:
            return .init(fajrAngle: 16, isha: .angle(15))
        case .morocco:
            return .init(fajrAngle: 19, isha: .angle(17),
                         methodAdjustments: .init(sunrise: -3, dhuhr: 5, maghrib: 5))
        case .algeria:
            return .init(fajrAngle: 18, isha: .angle(17))
        case .tunisia:
            return .init(fajrAngle: 18, isha: .angle(18))
        }
    }

    /// A sensible default method for an ISO 3166-1 alpha-2 country code.
    public static func recommended(forCountryCode code: String?) -> CalculationMethod {
        guard let code = code?.uppercased() else { return .muslimWorldLeague }
        switch code {
        case "SA", "YE": return .ummAlQura
        case "AE": return .dubai
        case "KW": return .kuwait
        case "QA": return .qatar
        case "BH", "OM": return .gulf
        case "EG", "SD", "LY", "SY", "LB", "IQ", "JO", "PS": return .egyptian
        case "PK", "IN", "BD", "AF": return .karachi
        case "US", "CA": return .isna
        case "GB", "IE": return .moonsightingCommittee
        case "SG", "BN": return .singapore
        case "MY": return .jakim
        case "ID": return .kemenag
        case "TR", "AZ": return .turkey
        case "IR": return .tehran
        case "FR", "BE": return .france
        case "RU": return .russia
        case "MA": return .morocco
        case "DZ": return .algeria
        case "TN": return .tunisia
        default: return .muslimWorldLeague
        }
    }
}
