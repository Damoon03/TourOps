import SwiftUI

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
