//
//  SwiftUIView.swift
//  Outivity
//
//  Created by Wafiq on 1/1/26.
//

import SwiftUI

struct ActivityPhotoGalleryHeroLayer: View {
    @Environment(ActivityPhotoGalleryCoordinator.self) private var activityPhotoGalleryCoordinator
    var activityPhoto: ActivityPhoto
    var sAnchor: Anchor<CGRect>
    var dAnchor: Anchor<CGRect>
    var body: some View {
        GeometryReader{ proxy in
            let sRect = proxy[sAnchor]
            let dRect = proxy[dAnchor]
            let animateView = activityPhotoGalleryCoordinator.animateView
            
            let viewSize: CGSize = .init(
                width: animateView ? dRect.width : sRect.width,
                height: animateView ? dRect.height : sRect.height
            )
            
            let viewPosition: CGSize = .init(
                width: animateView ? dRect.minX : sRect.minX,
                height: animateView ? dRect.minY : sRect.minY
            )
            
            if let image = activityPhoto.getImage(), !activityPhotoGalleryCoordinator.showDetailView {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: animateView ? .fit : .fill)
                    .frame(width: viewSize.width, height: viewSize.height, alignment: .center)
                    .frame(width: viewSize.width, height: viewSize.height)
                    .offset(viewPosition)
                    .opacity(animateView ? 1 : 0)
                    .animation(.smooth(duration: 0.17), value: animateView)
            }
        }
    }
}
