//
//  Haptics.swift
//  Lightweight wrapper around UIKit feedback generators.
//

import UIKit

enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func tap()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func select()  { UISelectionFeedbackGenerator().selectionChanged() }
}
