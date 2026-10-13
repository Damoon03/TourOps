import SwiftUI

// MARK: - Palette

enum Palette {
    // Restrained near-black surfaces with indigo accents, inspired by the reference.
    static let canvas = Color(red: 0.043, green: 0.043, blue: 0.071)       // #0B0B12
    static let surface = Color(red: 0.090, green: 0.090, blue: 0.125)      // #171720
    static let surfaceRaised = Color(red: 0.137, green: 0.133, blue: 0.180)
    static let hairline = Color.white.opacity(0.085)

    static let primaryText = Color(red: 0.96, green: 0.96, blue: 0.98)
    static let secondaryText = Color(red: 0.64, green: 0.63, blue: 0.70)

    static let accent = Color(red: 0.318, green: 0.251, blue: 0.937)       // #5140EF
    static let chipAccent = Color(red: 0.70, green: 0.66, blue: 1.00)
    static let highlight = Color(red: 0.94, green: 0.95, blue: 0.30)

    // Genre-family colors and continent colors deliberately use separate palettes.
    // This prevents adjacent genre/location chips from accidentally matching.
    static let genreRock = Color(red: 0.72, green: 0.62, blue: 1.00)       // lavender
    static let genrePop = Color(red: 1.00, green: 0.48, blue: 0.68)        // rose
    static let genreElectronic = Color(red: 0.35, green: 0.82, blue: 0.98) // cyan
    static let genreHipHop = Color(red: 1.00, green: 0.60, blue: 0.38)    // coral-orange
    static let genreJazz = Color(red: 0.55, green: 0.86, blue: 0.68)      // mint
    static let genreFolk = Color(red: 0.90, green: 0.78, blue: 0.42)      // gold
    static let genreOther = Color(red: 0.88, green: 0.66, blue: 0.96)     // lilac-pink

    // One stable color per continent. These differ from every genre-family color.
    static let africa = Color(red: 0.96, green: 0.68, blue: 0.25)         // amber
    static let asia = Color(red: 0.96, green: 0.38, blue: 0.38)            // red
    static let europe = Color(red: 0.40, green: 0.78, blue: 0.55)          // green
    static let americas = Color(red: 0.34, green: 0.60, blue: 0.96)        // blue
    static let oceania = Color(red: 0.94, green: 0.48, blue: 0.27)        // orange
}

enum GenreColorMapper {
    static func color(for genreName: String) -> Color {
        let value = genreName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).trimmingCharacters(in: .whitespacesAndNewlines)
        // Match more specific families first. Dream pop and electronic pop intentionally
        // share a family color; rock subgenres share the rock color.
        if value.contains("dream pop") || value.contains("electronic pop") || value.contains("synth-pop") || value.contains("synthpop") {
            return Palette.genrePop
        }
        if value.contains("rock") || value.contains("punk") || value.contains("grunge") || value.contains("metal") || value.contains("shoegaze") {
            return Palette.genreRock
        }
        if value.contains("hip-hop") || value.contains("hip hop") || value.contains("rap") || value.contains("trap") || value.contains(" grime") {
            return Palette.genreHipHop
        }
        if value.contains("electronic") || value.contains("techno") || value.contains("house") || value.contains("trance") || value.contains("edm") || value.contains("drum and bass") || value.contains("drum & bass") || value.contains("dubstep") {
            return Palette.genreElectronic
        }
        if value.contains("jazz") || value.contains("blues") || value.contains("soul") || value.contains("funk") || value.contains("r&b") || value.contains("rnb") {
            return Palette.genreJazz
        }
        if value.contains("folk") || value.contains("country") || value.contains("bluegrass") || value.contains("acoustic") || value.contains("americana") {
            return Palette.genreFolk
        }
        if value.contains("pop") || value.contains("indie") || value.contains("alternative") {
            return Palette.genrePop
        }
        return Palette.genreOther
    
    }
}

enum ContinentColorMapper {
    private static let africa: Set<String> = [
        "algeria", "angola", "benin", "botswana", "burkina faso", "burundi", "cameroon",
        "cape verde", "central african republic", "chad", "comoros", "congo", "democratic republic of the congo",
        "djibouti", "egypt", "equatorial guinea", "eritrea", "eswatini", "ethiopia", "gabon", "gambia",
        "ghana", "guinea", "guinea-bissau", "ivory coast", "cote d'ivoire", "kenya", "lesotho", "liberia",
        "libya", "madagascar", "malawi", "mali", "mauritania", "mauritius", "morocco", "mozambique",
        "namibia", "niger", "nigeria", "rwanda", "sao tome and principe", "senegal", "seychelles",
        "sierra leone", "somalia", "south africa", "south sudan", "sudan", "tanzania", "togo", "tunisia",
        "uganda", "zambia", "zimbabwe"
    ]

    private static let asia: Set<String> = [
        "afghanistan", "armenia", "azerbaijan", "bahrain", "bangladesh", "bhutan", "brunei", "cambodia",
        "china", "cyprus", "georgia", "india", "indonesia", "iran", "iraq", "israel", "japan", "jordan",
        "kazakhstan", "kuwait", "kyrgyzstan", "laos", "lebanon", "malaysia", "maldives", "mongolia",
        "myanmar", "nepal", "north korea", "oman", "pakistan", "palestine", "philippines", "qatar",
        "saudi arabia", "singapore", "south korea", "sri lanka", "syria", "taiwan", "tajikistan", "thailand",
        "timor-leste", "turkey", "turkmenistan", "united arab emirates", "uzbekistan", "vietnam", "yemen"
    ]

    private static let europe: Set<String> = [
        "albania", "andorra", "austria", "belarus", "belgium", "bosnia and herzegovina", "bulgaria", "croatia",
        "czechia", "czech republic", "denmark", "estonia", "finland", "france", "germany", "greece", "hungary",
        "iceland", "ireland", "italy", "kosovo", "latvia", "liechtenstein", "lithuania", "luxembourg", "malta",
        "moldova", "monaco", "montenegro", "netherlands", "north macedonia", "norway", "poland", "portugal",
        "romania", "russia", "san marino", "serbia", "slovakia", "slovenia", "spain", "sweden", "switzerland",
        "ukraine", "united kingdom", "uk", "england", "scotland", "wales", "vatican city"
    ]

    private static let americas: Set<String> = [
        "antigua and barbuda", "argentina", "bahamas", "barbados", "belize", "bolivia", "brazil", "canada",
        "chile", "colombia", "costa rica", "cuba", "dominica", "dominican republic", "ecuador", "el salvador",
        "grenada", "guatemala", "guyana", "haiti", "honduras", "jamaica", "mexico", "nicaragua", "panama",
        "paraguay", "peru", "saint kitts and nevis", "saint lucia", "saint vincent and the grenadines", "suriname",
        "trinidad and tobago", "united states", "united states of america", "usa", "uruguay", "venezuela"
    ]

    private static let oceania: Set<String> = [
        "australia", "fiji", "kiribati", "marshall islands", "micronesia", "nauru", "new zealand", "palau",
        "papua new guinea", "samoa", "solomon islands", "tonga", "tuvalu", "vanuatu"
    ]

    static func color(for countryName: String) -> Color {
        let normalized = countryName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)


        if Self.africa.contains(normalized) { return Palette.africa }
        if Self.asia.contains(normalized) { return Palette.asia }
        if Self.europe.contains(normalized) { return Palette.europe }
        if Self.americas.contains(normalized) { return Palette.americas }
        if Self.oceania.contains(normalized) { return Palette.oceania }
        // Unknown/blank countries get a neutral location accent, not a random team color.
        return Palette.secondaryText
    
    }
}
