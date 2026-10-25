//
//  SwiftUIView.swift
//  Outivity
//
//  Created by Wafiq on 1/1/26.
//

import SwiftUI

struct ActivityPhotoGalleryHeroKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        // Keep the first anchor we saw for a given key.
        // This avoids anchors from other tabs (still in the view hierarchy) overriding the
        // currently visible tab's anchors and causing hero animations to start from the wrong place.
        value.merge(nextValue(), uniquingKeysWith: { current, _ in current })
    }
}
