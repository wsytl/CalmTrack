//
//  L10n.swift
//  CalmTrack
//

import Foundation

/// 应用内本地化（`Localizable.xcstrings`，表名 `Localizable`）。
enum L10n {

    static func tr(_ key: String, comment: String = "") -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: key, comment: comment)
    }

    static func trf(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), locale: .current, arguments: Array(arguments))
    }
}
