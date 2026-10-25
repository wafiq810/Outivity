//
//  SwiftUIView.swift
//  Outivity
//
//  Created by Wafiq on 1/5/26.
//

import SwiftUI
struct ActivityPhotoGallerySurface: View {

    enum Mode: Equatable {
        case strip(height: CGFloat = 72, itemWidth: CGFloat = 72, cornerRadius: CGFloat = 12, spacing: CGFloat = 8)
        case grid(columns: Int = 3, itemHeight: CGFloat = 130, spacing: CGFloat = 3)
    }

    let photos: [ActivityPhoto]
    let mode: Mode

    var selectedPhotoID: String? = nil

    var isHeroAnimating: Bool = false

    let onTap: (ActivityPhoto) -> Void

    var isDeleteMode: Bool = false
    var onDeleteTapped: ((ActivityPhoto) -> Void)? = nil

    var body: some View {
        switch mode {
        case let .strip(height, itemWidth, cornerRadius, spacing):
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: spacing) {
                    ForEach(photos) { photo in
                        cell(photo, cornerRadius: cornerRadius)
                            .frame(width: itemWidth, height: height)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }

        case let .grid(columns, itemHeight, spacing):
            let cols = Array(repeating: GridItem(.flexible(), spacing: spacing), count: max(1, columns))
            ScrollView(.vertical) {
                LazyVGrid(columns: cols, spacing: spacing) {
                    ForEach(photos) { photo in
                        cell(photo, cornerRadius: 0)
                            .frame(height: itemHeight)
                    }
                }
                .padding(.vertical, 15)
            }
        }
    }

    // MARK: - Cell

    @ViewBuilder
    private func cell(_ photo: ActivityPhoto, cornerRadius: CGFloat) -> some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.clear)
                    .anchorPreference(key: ActivityPhotoGalleryHeroKey.self, value: .bounds) { anchor in
                        [photo.id.uuidString + "SOURCE": anchor]
                    }

                if let preview = photo.getPreviewImage() {
                    Image(uiImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        // Use a clip shape instead of `.clipped()`.
                        .clipShape(
                            cornerRadius > 0
                            ? AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                            : AnyShape(Rectangle())
                        )
                        .opacity((selectedPhotoID == photo.id.uuidString && isHeroAnimating) ? 0 : 1)
                } else {
                    RoundedRectangle(cornerRadius: max(0, cornerRadius))
                        .fill(.secondary.opacity(0.15))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                }
                
                // Attribution overlay for demo photos
                if let demoPhoto = photo as? DemoActivityPhoto,
                   let attribution = demoPhoto.getAttribution() {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(attribution)
                                .font(.system(size: 7))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 2)
                                .background(
                                    Color.black.opacity(0.7)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                        }
                        .padding(.horizontal, 3)
                        .padding(.bottom, 3)
                    }
                }

                if isDeleteMode, let onDeleteTapped {
                    Button { onDeleteTapped(photo) } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white, .black.opacity(0.35))
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentShape(.rect)
        .onTapGesture { onTap(photo) }
        // The image already clips to the correct bounds above.
    }

    private struct ConditionalClip: ViewModifier {
        let cornerRadius: CGFloat
        func body(content: Content) -> some View {
            if cornerRadius > 0 {
                content.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                content // no clip needed
            }
        }
    }

}
