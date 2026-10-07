import Foundation

struct AzanSound: Identifiable, Hashable {
    let id: String
    let nameEN: String
    let nameAR: String
    let fileName: String?
    let credit: String
    let license: String
    let sourceURL: String?

    static let defaultID = "fakhry"
    static let customID = "custom"
    static let chimeID = "chime"

    static let builtIn: [AzanSound] = [
        AzanSound(id: "fakhry", nameEN: "Sabah Fakhri — Aleppo", nameAR: "صباح فخري — حلب",
                  fileName: "fakhry.mp3", credit: "Sabah Fakhri", license: "Public domain",
                  sourceURL: "https://commons.wikimedia.org/wiki/File:Call_to_prayer_by_Sabah_Fakhry.mp3"),
        AzanSound(id: "azeez", nameEN: "Aaqib Azeez", nameAR: "عاقب عزيز",
                  fileName: "azeez.mp3", credit: "Atcovi / Aaqib Azeez", license: "CC BY-SA 4.0",
                  sourceURL: "https://commons.wikimedia.org/wiki/File:The_Adhan_-_Muslim_Call_to_Prayer_-_Aaqib_Azeez.mp3"),
        AzanSound(id: "beautiful", nameEN: "Serene", nameAR: "هادئ",
                  fileName: "beautiful.mp3", credit: "Adam-synagda", license: "CC0",
                  sourceURL: "https://commons.wikimedia.org/wiki/File:Beautiful_adhan.ogg"),
        AzanSound(id: "andrewler", nameEN: "Classic", nameAR: "كلاسيكي",
                  fileName: "andrewler.mp3", credit: "Andrewler", license: "CC BY-SA 4.0",
                  sourceURL: "https://commons.wikimedia.org/wiki/File:Azan.ogg"),
        AzanSound(id: "hassan2", nameEN: "Hassan II Mosque — Casablanca (ambient)",
                  nameAR: "مسجد الحسن الثاني — الدار البيضاء (أجواء)",
                  fileName: "hassan2.m4a", credit: "Fraguando", license: "CC BY-SA 4.0",
                  sourceURL: "https://commons.wikimedia.org/wiki/File:Llamada_a_oraci%C3%B3n_Mezquita_Hassan_II.wav"),
        AzanSound(id: chimeID, nameEN: "Gentle chime", nameAR: "تنبيه لطيف",
                  fileName: nil, credit: "macOS", license: "", sourceURL: nil),
    ]

    static func sound(id: String) -> AzanSound? { builtIn.first { $0.id == id } }

    func name(arabic: Bool) -> String { arabic ? nameAR : nameEN }

    var url: URL? {
        guard let fileName else { return nil }
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        return Bundle.main.url(forResource: base, withExtension: ext, subdirectory: "Audio")
            ?? Bundle.main.url(forResource: base, withExtension: ext)
    }
}
