import UIKit
import SwiftUI

enum DS {
    // MARK: - Spacing (4pt grid)

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Typography

    static let caption = Font.system(size: 11, weight: .medium, design: .rounded)
    static let captionBold = Font.system(size: 11, weight: .semibold, design: .rounded)
    static let small = Font.system(size: 13, weight: .medium, design: .rounded)
    static let smallBold = Font.system(size: 13, weight: .bold, design: .rounded)
    static let body = Font.system(size: 15, weight: .regular, design: .rounded)
    static let bodyBold = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let display = Font.system(size: 22, weight: .bold, design: .rounded)

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
    }

    // MARK: - Animation (respects Reduce Motion)

    static var spring: Animation {
        UIAccessibility.isReduceMotionEnabled ? .default : .spring(response: 0.35, dampingFraction: 0.7)
    }

    static var springHeavy: Animation {
        UIAccessibility.isReduceMotionEnabled ? .default : .spring(response: 0.4, dampingFraction: 0.8)
    }

    // MARK: - Sizes

    enum Size {
        static let minTapTarget: CGFloat = 44
        static let annotationBadge: CGFloat = 44
        static let detailBadge: CGFloat = 72
        static let lineCircle: CGFloat = 38
    }
}
