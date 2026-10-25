//
//  SwiftUIView.swift
//  Outivity
//
//  Created by Wafiq on 1/5/26.
//

import SwiftUI

struct ActivityPhotoGalleryDestAnchor<Content: View>: View {
    let photo: ActivityPhoto
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .anchorPreference(key: ActivityPhotoGalleryHeroKey.self, value: .bounds) { anchor in
                [photo.id.uuidString + "DEST": anchor]
            }
    }
}

