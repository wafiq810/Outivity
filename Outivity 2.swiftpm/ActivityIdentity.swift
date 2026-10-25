
import Foundation
import SwiftUI

/// Unified activity identity for both built-in and custom activities.
public struct ActivityIdentity: Identifiable, Hashable, Equatable {
    public let id: String
    public let displayName: String
    public let symbolName: String
    
    public enum Kind: Hashable {
        case builtIn(Activity)
        case custom(UUID)
    }
    public let kind: Kind
    
    public var colorHue: Double {
        switch kind {
        case .builtIn(let activity):
             return Double(abs(activity.id.hashValue) % 256) / 255.0
        case .custom(let uuid):
             return Double(abs(uuid.hashValue) % 256) / 255.0
        }
    }
    
    public init(activity: Activity) {
        self.kind = .builtIn(activity)
        self.id = activity.id
        self.displayName = activity.displayName
        self.symbolName = activity.symbolName
    }
    
    public init(custom: CustomActivity) {
        self.kind = .custom(custom.id)
        self.id = custom.id.uuidString
        self.displayName = custom.name
        self.symbolName = custom.symbolName
    }
}
