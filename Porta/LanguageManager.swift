import Foundation

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    static let supportedLanguages = ["en", "zh-Hans"]

    @Published var language: String {
        didSet {
            UserDefaults.standard.set(language, forKey: "appLanguage")
        }
    }

    var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let b = Bundle(path: path) else { return .main }
        return b
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           Self.supportedLanguages.contains(saved) {
            language = saved
        } else {
            let preferred = Locale.preferredLanguages.first ?? "en"
            language = preferred.hasPrefix("zh") ? "zh-Hans" : "en"
        }
    }
}

func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: LanguageManager.shared.bundle, comment: "")
}

func Lf(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}
