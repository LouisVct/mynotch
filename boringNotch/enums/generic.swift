//
//  generic.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Foundation
import SwiftUI
import Defaults

public enum Style {
    case notch
    case floating
}

public enum ContentType: Int, Codable, Hashable, Equatable {
    case normal
    case menu
    case settings
}

public enum NotchState {
    case closed
    case open
}

public enum NotchViews {
    case home
    case shelf
    case timer
}

enum SettingsEnum {
    case general
    case about
    case charge
    case download
    case mediaPlayback
    case hud
    case shelf
    case extensions
}

enum DownloadIndicatorStyle: String, Defaults.Serializable {
    case progress = "Progress"
    case percentage = "Percentage"
}

enum DownloadIconStyle: String, Defaults.Serializable {
    case onlyAppIcon = "Only app icon"
    case onlyIcon = "Only download icon"
    case iconAndAppIcon = "Icon and app icon"
}

enum MirrorShapeEnum: String, Defaults.Serializable {
    case rectangle = "Rectangular"
    case circle = "Circular"
}

enum WindowHeightMode: String, Defaults.Serializable {
    case matchMenuBar = "Match menubar height"
    case matchRealNotchSize = "Match real notch height"
    case custom = "Custom height"
}

enum SliderColorEnum: String, CaseIterable, Defaults.Serializable {
    case white = "White"
    case albumArt = "Match album art"
    case accent = "Accent color"
}

/// Language of the app's interface. `system` follows macOS.
enum AppLanguage: String, CaseIterable, Identifiable, Defaults.Serializable {
    case system
    case english = "en"
    case french = "fr"
    case swedish = "sv"
    case arabic = "ar"

    var id: String { rawValue }

    /// Names are shown in their own language so they stay recognisable whatever the current one is.
    var nativeName: String? {
        switch self {
        case .system: return nil
        case .english: return "English"
        case .french: return "Français"
        case .swedish: return "Svenska"
        case .arabic: return "العربية"
        }
    }

    var locale: Locale {
        self == .system ? .autoupdatingCurrent : Locale(identifier: rawValue)
    }

    var layoutDirection: LayoutDirection {
        switch self {
        case .arabic: return .rightToLeft
        case .system: return Locale.Language(identifier: Locale.preferredLanguages.first ?? "en").characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
        default: return .leftToRight
        }
    }

    /// Lets AppKit pieces (menus, system panels) follow the choice after the next launch.
    func persistForSystem() {
        if self == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
    }
}

/// Applies the chosen language to a SwiftUI hierarchy hosted in AppKit.
/// The notch itself always stays left-to-right so it remains symmetric around the cutout.
struct LanguageEnvironment<Content: View>: View {
    @Default(.appLanguage) private var language
    let mirrorsLayout: Bool
    let content: Content

    init(mirrorsLayout: Bool = true, @ViewBuilder content: () -> Content) {
        self.mirrorsLayout = mirrorsLayout
        self.content = content()
    }

    var body: some View {
        content
            .environment(\.locale, language.locale)
            .environment(\.layoutDirection, mirrorsLayout ? language.layoutDirection : .leftToRight)
    }
}
