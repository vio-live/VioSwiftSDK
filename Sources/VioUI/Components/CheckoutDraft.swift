import Combine
import Foundation

// MARK: - Helpers NO aislados al MainActor (evitan el error de aislamiento)

private func normalizeKey(_ s: String) -> String {
    let lowered = s.trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        .lowercased()
    let cleaned = lowered.replacingOccurrences(
        of: "[^a-z0-9\\s\\.-]", with: "", options: .regularExpression)
    return cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
}

extension String {
    fileprivate var nonEmpty: String? { isEmpty ? nil : self }
    fileprivate func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Non-isolated Geographic Catalog (mappers and tables)

private enum GeoMaps {

    // ISO-2 -> Canonical country name (to fill in if name is missing)
    static let countryNameByISO2: [String: String] = [
        "US": "United States", "CA": "Canada", "GB": "United Kingdom", "IE": "Ireland",
        "NO": "Norway", "SE": "Sweden", "DK": "Denmark", "FI": "Finland",
        "DE": "Germany", "FR": "France", "IT": "Italy", "ES": "Spain", "PT": "Portugal",
        "NL": "Netherlands", "BE": "Belgium", "CH": "Switzerland", "AT": "Austria",
        "PL": "Poland", "CZ": "Czech Republic", "HU": "Hungary", "RO": "Romania",
        "GR": "Greece", "TR": "Turkey",
        "MX": "Mexico", "AR": "Argentina", "BR": "Brazil", "CL": "Chile",
        "CO": "Colombia", "PE": "Peru", "UY": "Uruguay", "EC": "Ecuador",
        "VE": "Venezuela", "BO": "Bolivia", "PY": "Paraguay",
        "CR": "Costa Rica", "PA": "Panama", "DO": "Dominican Republic",
        "GT": "Guatemala", "HN": "Honduras", "SV": "El Salvador", "NI": "Nicaragua",
        "AU": "Australia", "NZ": "New Zealand", "JP": "Japan", "KR": "South Korea", "CN": "China",
        "IN": "India",
    ]

    // Synonyms -> ISO-2 (with EN/ES variants)
    static let countryISO2ByName: [String: String] = {
        var m: [String: String] = [:]
        func add(_ names: [String], _ iso2: String) {
            for n in names { m[normalizeKey(n)] = iso2 }
        }

        add(["United States", "USA", "US", "Estados Unidos", "EEUU", "EE.UU."], "US")
        add(["United Kingdom", "UK", "Great Britain", "Britain", "Inglaterra"], "GB")
        add(["Ireland", "Irlanda"], "IE")

        add(["Norway", "Norge", "Noruega"], "NO")
        add(["Sweden", "Sverige", "Suecia"], "SE")
        add(["Denmark", "Danmark", "Dinamarca"], "DK")
        add(["Finland", "Suomi", "Finlandia"], "FI")

        add(["Germany", "Deutschland", "Alemania"], "DE")
        add(["France", "Francia"], "FR")
        add(["Italy", "Italia"], "IT")
        add(["Spain", "España"], "ES")
        add(["Portugal"], "PT")
        add(["Netherlands", "Holland", "Países Bajos", "Paises Bajos"], "NL")
        add(["Belgium", "België", "Belgie", "Bélgica"], "BE")
        add(["Switzerland", "Schweiz", "Suisse", "Svizzera", "Suiza"], "CH")
        add(["Austria", "Österreich"], "AT")
        add(["Poland", "Polska", "Polonia"], "PL")
        add(["Czech Republic", "Czechia", "Chequia"], "CZ")
        add(["Hungary", "Magyarország", "Hungría"], "HU")
        add(["Romania", "România", "Rumania"], "RO")
        add(["Greece", "Hellas", "Grecia"], "GR")
        add(["Turkey", "Türkiye", "Turquía"], "TR")

        add(["Canada", "Canadá"], "CA")
        add(["Mexico", "México"], "MX")
        add(["Argentina"], "AR")
        add(["Brazil", "Brasil"], "BR")
        add(["Chile"], "CL")
        add(["Colombia"], "CO")
        add(["Peru", "Perú"], "PE")
        add(["Uruguay"], "UY")
        add(["Ecuador"], "EC")
        add(["Venezuela"], "VE")
        add(["Bolivia"], "BO")
        add(["Paraguay"], "PY")
        add(["Costa Rica"], "CR")
        add(["Panama", "Panamá"], "PA")
        add(["Dominican Republic", "República Dominicana"], "DO")
        add(["Guatemala"], "GT")
        add(["Honduras"], "HN")
        add(["El Salvador"], "SV")
        add(["Nicaragua"], "NI")

        add(["Australia"], "AU")
        add(["New Zealand", "Nueva Zelanda"], "NZ")
        add(["Japan", "Japón"], "JP")
        add(["South Korea", "Korea, Republic of", "Corea del Sur"], "KR")
        add(["China", "PRC"], "CN")
        add(["India"], "IN")

        return m
    }()

    // ISO-2 -> International phone code (without '+')
    static let phoneCodeByISO2: [String: String] = [
        "US": "1", "CA": "1", "GB": "44", "IE": "353",
        "NO": "47", "SE": "46", "DK": "45", "FI": "358",
        "DE": "49", "FR": "33", "IT": "39", "ES": "34", "PT": "351",
        "NL": "31", "BE": "32", "CH": "41", "AT": "43",
        "PL": "48", "CZ": "420", "HU": "36", "RO": "40", "GR": "30",
        "TR": "90",
        "MX": "52", "AR": "54", "BR": "55", "CL": "56",
        "CO": "57", "PE": "51", "UY": "598", "EC": "593", "VE": "58",
        "BO": "591", "PY": "595",
        "CR": "506", "PA": "507", "DO": "1", "GT": "502", "HN": "504",
        "SV": "503", "NI": "505",
        "AU": "61", "NZ": "64", "JP": "81", "KR": "82", "CN": "86", "IN": "91",
    ]

    // ISO-2 -> (normalized province name -> code)
    static let provinceCodeByCountry: [String: [String: String]] = {
        var map: [String: [String: String]] = [:]

        // US (50 + DC)
        map["US"] = [
            "alabama": "AL", "alaska": "AK", "arizona": "AZ", "arkansas": "AR", "california": "CA",
            "colorado": "CO", "connecticut": "CT", "delaware": "DE", "district of columbia": "DC",
            "florida": "FL", "georgia": "GA", "hawaii": "HI", "idaho": "ID", "illinois": "IL",
            "indiana": "IN", "iowa": "IA", "kansas": "KS", "kentucky": "KY", "louisiana": "LA",
            "maine": "ME", "maryland": "MD", "massachusetts": "MA", "michigan": "MI",
            "minnesota": "MN",
            "mississippi": "MS", "missouri": "MO", "montana": "MT", "nebraska": "NE",
            "nevada": "NV",
            "new hampshire": "NH", "new jersey": "NJ", "new mexico": "NM", "new york": "NY",
            "north carolina": "NC", "north dakota": "ND", "ohio": "OH", "oklahoma": "OK",
            "oregon": "OR",
            "pennsylvania": "PA", "rhode island": "RI", "south carolina": "SC",
            "south dakota": "SD",
            "tennessee": "TN", "texas": "TX", "utah": "UT", "vermont": "VT", "virginia": "VA",
            "washington": "WA", "west virginia": "WV", "wisconsin": "WI", "wyoming": "WY",
        ]

        // CA (provincias + territorios)
        map["CA"] = [
            "alberta": "AB", "british columbia": "BC", "manitoba": "MB", "new brunswick": "NB",
            "newfoundland and labrador": "NL", "nova scotia": "NS", "ontario": "ON",
            "prince edward island": "PE",
            "quebec": "QC", "saskatchewan": "SK", "northwest territories": "NT", "nunavut": "NU",
            "yukon": "YT",
        ]

        // MX (amplio)
        map["MX"] = [
            "ciudad de mexico": "CDMX", "cdmx": "CDMX", "estado de mexico": "MEX", "méxico": "MEX",
            "mexico": "MEX",
            "nuevo leon": "NL", "jalisco": "JAL", "puebla": "PUE", "guanajuato": "GTO",
            "queretaro": "QRO",
            "quintana roo": "ROO", "veracruz": "VER", "yucatan": "YUC", "baja california": "BCN",
            "baja california sur": "BCS", "chihuahua": "CHH", "coahuila": "COA", "sonora": "SON",
            "sinaloa": "SIN",
            "tamaulipas": "TAM", "michoacan": "MIC", "oaxaca": "OAX", "chiapas": "CHP",
            "hidalgo": "HID",
            "san luis potosi": "SLP", "morelos": "MOR", "tlaxcala": "TLA", "nayarit": "NAY",
            "durango": "DUR",
            "zacatecas": "ZAC", "aguascalientes": "AGU", "colima": "COL", "campeche": "CAM",
        ]

        // BR (recurrentes)
        map["BR"] = [
            "sao paulo": "SP", "rio de janeiro": "RJ", "minas gerais": "MG",
            "rio grande do sul": "RS",
            "parana": "PR", "santa catarina": "SC", "bahia": "BA", "pernambuco": "PE",
            "ceara": "CE",
            "distrito federal": "DF", "goias": "GO", "espirito santo": "ES", "mato grosso": "MT",
            "mato grosso do sul": "MS",
            "para": "PA", "amazonas": "AM",
        ]

        // AR (recurrentes)
        map["AR"] = [
            "ciudad autonoma de buenos aires": "C", "caba": "C", "buenos aires": "B",
            "cordoba": "X",
            "santa fe": "S", "mendoza": "M", "tucuman": "T",
        ]

        // CL (recurrente)
        map["CL"] = [
            "region metropolitana": "RM", "región metropolitana": "RM", "santiago": "RM",
        ]

        // CO (recurrentes)
        map["CO"] = [
            "bogota d.c.": "DC", "bogota": "DC", "antioquia": "ANT", "valle del cauca": "VAC",
            "cundinamarca": "CUN", "atlantico": "ATL",
        ]

        // PE (recurrentes)
        map["PE"] = [
            "lima": "LIM", "arequipa": "ARE", "cusco": "CUS", "la libertad": "LAL", "piura": "PIU",
            "loreto": "LOR", "ancash": "ANC",
        ]

        return map
    }()
}

// MARK: - CheckoutDraft (MainActor) SOLO estado y helpers de negocio

@MainActor
public final class CheckoutDraft: ObservableObject {

    // Contact
    @Published public var email: String = ""
    @Published public var phone: String = ""
    /// May come with +; normalized when used
    @Published public var phoneCountryCode: String = ""

    // Address
    @Published public var firstName: String = ""
    @Published public var lastName: String = ""
    @Published public var address1: String = ""
    @Published public var address2: String = ""
    @Published public var city: String = ""
    @Published public var province: String = ""
    @Published public var countryName: String = "United States"
    @Published public var countryCode: String = ""  // ISO-2 if already available
    @Published public var zip: String = ""
    @Published public var company: String = ""

    // Selections and flags
    @Published public var shippingOptionRaw: String = "standard"  // "standard"|"express"
    @Published public var paymentMethodRaw: String = "stripe"  // "stripe"|"klarna"
    @Published public var acceptsTerms: Bool = false
    @Published public var acceptsPurchaseConditions: Bool = false
    @Published public var appliedDiscount: Double = 0.0

    // URLs (can be overridden from context)
    @Published public var successUrl: String = "reachu-demo://checkout/success"
    @Published public var cancelUrl: String = "reachu-demo://checkout/cancel"

    public init() {}

    // MARK: Payloads (snake_case)

    public func addressPayload(fallbackCountryISO2: String) -> [String: Any] {
        let iso2 = resolveISO2(fallback: fallbackCountryISO2)
        let phoneCode = resolvePhoneCode(effectiveISO2: iso2)
        let provCode = resolveProvinceCode(effectiveISO2: iso2, provinceName: province)

        return [
            "address1": address1,
            "address2": address2,
            "city": city,
            "company": company,
            "country": resolveCountryName(defaultName: countryName, iso2: iso2),
            "country_code": iso2,
            "email": email,
            "first_name": firstName,
            "last_name": lastName,
            "phone": phone,
            "phone_code": phoneCode,
            "province": province,
            "province_code": provCode,
            "zip": zip,
        ]
    }

    public func shippingAddressPayload(fallbackCountryISO2: String) -> [String: Any] {
        addressPayload(fallbackCountryISO2: fallbackCountryISO2)
    }

    public func billingAddressPayload(fallbackCountryISO2: String) -> [String: Any] {
        addressPayload(fallbackCountryISO2: fallbackCountryISO2)
    }

    // MARK: Resolution and Normalization

    /// Effective ISO-2 (prioritizes `countryCode`, otherwise resolves by `countryName`, otherwise fallback)
    public func resolveISO2(fallback: String) -> String {
        if let code = countryCode.nonEmpty?.uppercased(), code.count == 2 { return code }
        if let fromName = GeoMaps.countryISO2ByName[normalizeKey(countryName)] { return fromName }
        return fallback.uppercased()
    }

    /// Consistent country name (if missing, fills in by ISO-2)
    private func resolveCountryName(defaultName: String, iso2: String) -> String {
        if let name = defaultName.nonEmpty { return name }
        return GeoMaps.countryNameByISO2[iso2] ?? defaultName
    }

    /// International phone code (without '+')
    public func resolvePhoneCode(effectiveISO2 iso2: String) -> String {
        if let raw = phoneCountryCode.nonEmpty {
            return raw.replacingOccurrences(of: "+", with: "").trimmed()
        }
        return GeoMaps.phoneCodeByISO2[iso2] ?? ""
    }

    public func resolveProvinceCode(effectiveISO2 iso2: String, provinceName: String) -> String {
        let trimmed = provinceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        guard let map = GeoMaps.provinceCodeByCountry[iso2] else {
            let upper = trimmed.uppercased()
            return upper
        }

        let upper = trimmed.uppercased()
        if map.values.contains(upper) {
            return upper
        }

        let key = normalizeKey(trimmed)
        if let exact = map[key] {
            return exact
        }

        let simplified = normalizeKey(
            trimmed
                .replacingOccurrences(of: "state", with: "")
                .replacingOccurrences(of: "province", with: "")
                .replacingOccurrences(of: "provincia", with: "")
                .replacingOccurrences(of: "departamento", with: "")
                .replacingOccurrences(of: "region", with: "")
                .replacingOccurrences(of: "región", with: "")
        )
        if let fromSimplified = map[simplified] {
            return fromSimplified
        }

        if (2...5).contains(upper.count),
            upper.range(of: "^[A-Z]{2,5}$", options: .regularExpression) != nil
        {
            return upper
        }

        return ""
    }

}
