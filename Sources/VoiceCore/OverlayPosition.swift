import Foundation
import CoreGraphics

public enum OverlayPosition: String, CaseIterable {
    case topLeft, topCenter, topRight, bottomLeft, bottomCenter, bottomRight
    public init(savedValue: String?) { self = savedValue.flatMap(Self.init(rawValue:)) ?? .bottomCenter }
    public var title: String {
        switch self {
        case .topLeft: return "Top left"
        case .topCenter: return "Top center"
        case .topRight: return "Top right"
        case .bottomLeft: return "Bottom left"
        case .bottomCenter: return "Bottom center"
        case .bottomRight: return "Bottom right"
        }
    }
    public func origin(size: CGSize, screen: CGRect, visible: CGRect, topSafeInset: CGFloat = 0) -> CGPoint {
        // Preserve the original bottom-center spacing above the work area/Dock.
        if self == .bottomCenter {
            return CGPoint(x: visible.midX - size.width / 2, y: visible.minY + 24)
        }
        let margin: CGFloat = 6
        let x: CGFloat
        switch self {
        case .topLeft, .bottomLeft: x = screen.minX + margin
        case .topRight, .bottomRight: x = screen.maxX - size.width - margin
        default: x = screen.midX - size.width / 2
        }
        let y: CGFloat
        switch self {
        case .topLeft, .topRight: y = screen.maxY - size.height - margin
        // Avoid the physical camera cutout, not the menu bar.
        case .topCenter: y = screen.maxY - topSafeInset - size.height - margin
        default: y = screen.minY + margin
        }
        return CGPoint(x: x, y: y)
    }
}
