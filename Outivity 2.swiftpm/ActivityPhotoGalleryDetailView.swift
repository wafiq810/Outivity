//
//  SwiftUIView.swift
//  Outivity
//
//  Created by Wafiq on 1/1/26.
//

import SwiftUI
import SwiftData

struct ActivityPhotoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ActivityPhotoGalleryCoordinator.self) private var activityPhotoGalleryCoordinator
    @Environment(\.verticalSizeClass) var verticalSizeClass
    private let dismissDominance: CGFloat = 1.8   // how much more vertical than horizontal
    private let dismissDragDivisor: CGFloat = 240  // how quickly background fades
    private let dismissThreshold: CGFloat = 0.35   // % of screen height to dismiss
    @State private var isDismissing = false
    @State private var isCurrentImageZoomed = false
    @State private var isShowingInfoSheet = false
    @State private var isShowingDeleteAlert = false
    @State private var isRotating = false
    @State private var isChromeVisible = true

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            let pageID: Binding<String?> = Binding(
                get: { activityPhotoGalleryCoordinator.detailScrollPosition },
                set: { val in
                    if !isRotating {
                        activityPhotoGalleryCoordinator.detailScrollPosition = val
                    }
                }
            )

            ZStack {
                // MARK: - CONTENT (always full screen)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 0) {
                            ForEach(activityPhotoGalleryCoordinator.currentPhotos) { activityPhoto in
                                ZStack {
                                    ZoomableImageView(
                                        image: activityPhoto.getImage(),
                                        isZoomed: $isCurrentImageZoomed,
                                        isDismissing: $isDismissing,
                                        onDismissInterruptedByPinch: { settleDismiss(using: size) } // NEW
                                    )
                                    .containerRelativeFrame([.horizontal, .vertical])
                                    .onTapGesture {
                                        withAnimation {
                                            isChromeVisible.toggle()
                                        }
                                    }
                                    .contentShape(.rect)
                                    
                                    if let demoPhoto = activityPhoto as? DemoActivityPhoto,
                                       let attribution = demoPhoto.getAttribution() {
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Text(attribution)
                                                    .font(.caption2)
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(
                                                        Color.black.opacity(0.5)
                                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                                    )
                                                    .opacity(isChromeVisible ? 1 : 0)
                                                    .animation(.easeInOut(duration: 0.2), value: isChromeVisible)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.bottom, 40)
                                        }
                                    }
                                }
                                .id(activityPhoto.id.uuidString)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .animation(nil, value: activityPhotoGalleryCoordinator.detailIndicatorPosition)
                    .overlay {
                        if isDismissing {
                            TouchDownCatcher {
                                settleDismiss(using: size)
                            }
                            .ignoresSafeArea()
                        }
                    }
                    .scrollDisabled(isDismissing || isCurrentImageZoomed)
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: pageID)
                    .onChange(of: activityPhotoGalleryCoordinator.detailScrollPosition) { _, _ in
                        if !isRotating {
                            activityPhotoGalleryCoordinator.didDetailPageChange()
                        }
                    }
                    .background {
                        if let selectedImage = activityPhotoGalleryCoordinator.selectedImage {
                            Rectangle()
                                .fill(.clear)
                                .anchorPreference(key: ActivityPhotoGalleryHeroKey.self, value: .bounds) { anchor in
                                    [selectedImage.id.uuidString + "DEST": anchor]
                                }
                        }
                    }
                    .offset(activityPhotoGalleryCoordinator.offset)
                    .scaleEffect(1 - 0.06 * activityPhotoGalleryCoordinator.dragProcess)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 8, coordinateSpace: .local)
                            .onChanged { value in
                                guard !isCurrentImageZoomed else { return }

                                let t = value.translation

                                if !isDismissing {
                                    guard abs(t.height) > 24 else { return }
                                    guard abs(t.height) > abs(t.width) * dismissDominance else { return }
                                    isDismissing = true
                                }

                                guard isDismissing else { return }

                                activityPhotoGalleryCoordinator.offset = t

                                let down = max(t.height, 0)
                                activityPhotoGalleryCoordinator.dragProcess = max(min(down / dismissDragDivisor, 1), 0)
                            }
                            .onEnded { value in
                                guard !isCurrentImageZoomed else { return }
                                defer { isDismissing = false }
                                
                                guard isDismissing else { return }

                                let t = value.translation
                                let v = value.velocity
                                let projectedDown = t.height + (v.height / 6)

                                if projectedDown > (size.height * dismissThreshold) {
                                    activityPhotoGalleryCoordinator.toggleView(show: false)
                                } else {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        activityPhotoGalleryCoordinator.offset = .zero
                                        activityPhotoGalleryCoordinator.dragProcess = 0
                                    }
                                }
                            }
                    )
                    .opacity(activityPhotoGalleryCoordinator.showDetailView ? 1 : 0)
                    .onChange(of: size) { oldSize, newSize in
                        guard oldSize != newSize else { return }
                        isRotating = true
                        
                        if let selected = activityPhotoGalleryCoordinator.selectedImage {
                            let id = selected.id.uuidString
                            // Ensure binding is correct before display update
                            if activityPhotoGalleryCoordinator.detailScrollPosition != id {
                                activityPhotoGalleryCoordinator.detailScrollPosition = id
                            }
                            
                            DispatchQueue.main.async {
                                proxy.scrollTo(id, anchor: .center)
                                isRotating = false
                            }
                        } else {
                            isRotating = false
                        }
                    }
                    .onChange(of: activityPhotoGalleryCoordinator.showDetailView) { _, show in
                        if show {
                            if activityPhotoGalleryCoordinator.showInfoSheetOnPresentation {
                                isShowingInfoSheet = true
                                activityPhotoGalleryCoordinator.showInfoSheetOnPresentation = false
                            }
                        }
                    }
                }

                // MARK: - CHROME (overlay, does not affect layout)
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 24){
                        
                        // Bottom indicator pinned to bottom
                        BottomIndicatorView(
                            photos: activityPhotoGalleryCoordinator.currentPhotos,
                            selectedID: activityPhotoGalleryCoordinator.selectedImage?.id,
                            showDetailView: activityPhotoGalleryCoordinator.showDetailView,
                            dragProcess: activityPhotoGalleryCoordinator.dragProcess,
                            isZoomed: $isCurrentImageZoomed,
                            detailIndicatorPosition: Binding(
                                get: { activityPhotoGalleryCoordinator.detailIndicatorPosition },
                                set: { activityPhotoGalleryCoordinator.detailIndicatorPosition = $0 }
                            ),
                            onSelect: { photo in
                                activityPhotoGalleryCoordinator.selectedImage = photo
                                activityPhotoGalleryCoordinator.detailScrollPosition = photo.id.uuidString
                            },
                            onIndicatorPositionChanged: {
                                activityPhotoGalleryCoordinator.didDetailIndicatorPageChange()
                            }
                        )
                        .opacity(isChromeVisible ? 1 : 0)
                        .allowsHitTesting(isChromeVisible)
                        BottomNavBar(
                                isHidden: isCurrentImageZoomed || !isChromeVisible,
                                dragProcess: activityPhotoGalleryCoordinator.dragProcess,
                                showDetailView: activityPhotoGalleryCoordinator.showDetailView,
                                onInfo: { isShowingInfoSheet = true },
                                onDelete: { isShowingDeleteAlert = true }
                        )
                    }
                   
                }
            }
            .overlay(alignment: .top) {
                HeaderNavBar(
                    isHidden: isCurrentImageZoomed || !isChromeVisible,
                    dragProcess: activityPhotoGalleryCoordinator.dragProcess,
                    showDetailView: activityPhotoGalleryCoordinator.showDetailView,
                    onBack: { activityPhotoGalleryCoordinator.toggleView(show: false) },
                    onShowHistory: {
                        if let photo = activityPhotoGalleryCoordinator.selectedImage, let tracker = photo.tracker {
                           activityPhotoGalleryCoordinator.pendingHistoryNavigation = tracker
                           activityPhotoGalleryCoordinator.toggleView(show: false)
                        }
                    },
                    onDelete: { isShowingDeleteAlert = true }
                )
                .padding(.horizontal)
                .padding(.top, verticalSizeClass == .regular ? 45 : 15)
            }

        }
        .sheet(isPresented: $isShowingInfoSheet) {
            if let photo = activityPhotoGalleryCoordinator.selectedImage {
                ActivityPhotoInfoSheet(photo: photo, onResume: { tracker in
                    isShowingInfoSheet = false
                    activityPhotoGalleryCoordinator.toggleView(show: false)
                }, onShowHistory: {
                    if activityPhotoGalleryCoordinator.presentedPhotos.isEmpty {
                       activityPhotoGalleryCoordinator.pendingHistoryNavigation = photo.tracker
                    }
                    
                    isShowingInfoSheet = false
                    activityPhotoGalleryCoordinator.toggleView(show: false)
                })
                .presentationDetents([.medium])
            }
        }
        .alert("Delete photo?", isPresented: $isShowingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePhoto()
            }
        }message: {
            Text("This activity photo will be permanently deleted.")
        }
        .ignoresSafeArea()
    }
    private func settleDismiss(using size: CGSize) {
        let down = max(activityPhotoGalleryCoordinator.offset.height, 0)

        // stop the locked state no matter what
        isDismissing = false

        if down > (size.height * dismissThreshold) {
            // Reset interactive transform first so hero can start from centered state
            withAnimation(.easeInOut(duration: 0.12)) {
                activityPhotoGalleryCoordinator.offset = .zero
                activityPhotoGalleryCoordinator.dragProcess = 0
            }

            // Defer the actual toggle slightly to allow the settle animation to commit
            let delay = 0.12
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                activityPhotoGalleryCoordinator.toggleView(show: false)
            }
        } else {
            withAnimation(.easeInOut(duration: 0.12)) {
                activityPhotoGalleryCoordinator.offset = .zero
                activityPhotoGalleryCoordinator.dragProcess = 0
            }
        }
    }


    private func deletePhoto() {
        guard let photo = activityPhotoGalleryCoordinator.selectedImage else { return }
        let currentPhotos = activityPhotoGalleryCoordinator.currentPhotos
        guard let index = currentPhotos.firstIndex(where: { $0.id == photo.id }) else { return }
        
        withAnimation {
            // Remove from local lists
            if let idx = activityPhotoGalleryCoordinator.activityPhotos.firstIndex(where: { $0.id == photo.id }) {
                activityPhotoGalleryCoordinator.activityPhotos.remove(at: idx)
            }
            if let idx = activityPhotoGalleryCoordinator.presentedPhotos.firstIndex(where: { $0.id == photo.id }) {
                activityPhotoGalleryCoordinator.presentedPhotos.remove(at: idx)
            }
            
            // Delete from context
            modelContext.delete(photo)
            
            // Update selection
            let newPhotos = activityPhotoGalleryCoordinator.currentPhotos
            
            if newPhotos.isEmpty {
                activityPhotoGalleryCoordinator.toggleView(show: false)
            } else {
                let newIndex = min(index, newPhotos.count - 1)
                let nextPhoto = newPhotos[newIndex]
                
                activityPhotoGalleryCoordinator.selectedImage = nextPhoto
                activityPhotoGalleryCoordinator.detailScrollPosition = nextPhoto.id.uuidString
                activityPhotoGalleryCoordinator.detailIndicatorPosition = nextPhoto.id.uuidString
            }
        }
    }
 
    
    private struct HeaderNavBar: View {
        @Environment(ActivityPhotoGalleryCoordinator.self) private var activityPhotoGalleryCoordinator
        let isHidden: Bool
        let dragProcess: CGFloat
        let showDetailView: Bool
        let onBack: () -> Void
        var onShowHistory: (() -> Void)? = nil
        var onDelete: (() -> Void)? = nil

        var body: some View {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20))
                        .padding(14)
                        .foregroundStyle(.foreground)
                }
                .glassEffect(.regular.interactive(), in: Circle())
                
                Spacer()
                
                VStack{
                    Text(activityPhotoGalleryCoordinator.selectedImage?.tracker?.displayActivityName ?? "Your activity")
                        .font(.subheadline)
                    if let createdAt = activityPhotoGalleryCoordinator.selectedImage?.createdAt {
                        Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 21)
                .padding(.vertical, 5)
                .glassEffect(.regular.interactive())
                    

                Spacer()
                
                SwiftUI.Menu {
                    Button {
                        onShowHistory?()
                    } label: {
                        Label("View activity details", systemImage: "clock")
                    }
                    
                    Button(role: .destructive) {
                        onDelete?()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .padding(18)
                        .foregroundStyle(.foreground)
                }
                .glassEffect(.regular.interactive(), in: Circle())
            }
            .frame(height: 56)
            .compositingGroup()
            .opacity(isHidden ? 0 : max(0, (1.0 - (dragProcess * 3.5))))
            .allowsHitTesting(!isHidden)
            .offset(y: showDetailView ? (-200.0 * dragProcess) : -200.0)
            .animation(.easeInOut(duration: 0.15), value: showDetailView)
            .animation(.easeInOut(duration: 0.15), value: isHidden)
        }
    }

    private struct BottomIndicatorView: View {
        let photos: [ActivityPhoto]
        let selectedID: UUID?
        let barHeight: CGFloat

        let showDetailView: Bool
        let dragProcess: CGFloat

        @Binding var isZoomed: Bool
        @Binding var detailIndicatorPosition: String?
        let onSelect: (ActivityPhoto) -> Void
        let onIndicatorPositionChanged: () -> Void

        init(
            photos: [ActivityPhoto],
            selectedID: UUID?,
            barHeight: CGFloat = 70,
            showDetailView: Bool,
            dragProcess: CGFloat,
            isZoomed: Binding<Bool>,
            detailIndicatorPosition: Binding<String?>,
            onSelect: @escaping (ActivityPhoto) -> Void,
            onIndicatorPositionChanged: @escaping () -> Void
        ) {
            self.photos = photos
            self.selectedID = selectedID
            self.barHeight = barHeight
            self.showDetailView = showDetailView
            self.dragProcess = dragProcess
            self._isZoomed = isZoomed
            self._detailIndicatorPosition = detailIndicatorPosition
            self.onSelect = onSelect
            self.onIndicatorPositionChanged = onIndicatorPositionChanged
        }

        var body: some View {
            GeometryReader { barGeo in
                let barSize = barGeo.size
                let indicatorID = Binding<String?>(
                    get: { detailIndicatorPosition },
                    set: { detailIndicatorPosition = $0 }
                )

                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 5) {
                            ForEach(photos) { photo in
                                if let img = photo.getPreviewImage() {
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 50)
                                        .clipShape(.rect(cornerRadius: 10))
                                        .scaleEffect(0.97)
                                        .contentShape(.rect)
                                        .onTapGesture {
                                            guard !isZoomed else { return }
                                            if selectedID == photo.id { return }

                                            onSelect(photo)

                                            withAnimation(.easeInOut(duration: 0.38)) {
                                                detailIndicatorPosition = photo.id.uuidString
                                            }
                                        }
                                        .id(photo.id.uuidString)
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        .scrollTargetLayout()
                    }
                    .safeAreaPadding(.horizontal, (barSize.width - 50) / 2)
                    .mask(
                        HStack(spacing: 0) {

                            // Left gradient
                            LinearGradient(gradient:
                               Gradient(
                                   colors: [Color.black.opacity(0), Color.black]),
                                   startPoint: .leading, endPoint: .trailing
                               )
                               .frame(width: 50)

                            // Middle
                            Rectangle().fill(Color.black)

                            // Right gradient
                            LinearGradient(gradient:
                               Gradient(
                                   colors: [Color.black, Color.black.opacity(0)]),
                                   startPoint: .leading, endPoint: .trailing
                               )
                               .frame(width: 50)
                        }
                     )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary, lineWidth: 2)
                            .frame(width: 50, height: 50)
                            .allowsHitTesting(false)
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: indicatorID)
                    .scrollIndicators(.hidden)
                    .animation(.easeInOut(duration: 0.28), value: detailIndicatorPosition)
                    .onChange(of: detailIndicatorPosition) { _, _ in
                        guard !isZoomed else { return }
                        onIndicatorPositionChanged()
                    }
                    .onAppear {
                        if let id = detailIndicatorPosition {
                            DispatchQueue.main.async {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                    .onChange(of: showDetailView) { _, show in
                        if show, let id = detailIndicatorPosition {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                    .onChange(of: barSize) { _, _ in
                         if let id = detailIndicatorPosition {
                             proxy.scrollTo(id, anchor: .center)
                         }
                    }
                    .compositingGroup()
                    .opacity(isZoomed ? 0 : max(0, 1.0 - (dragProcess * 3.5)))
                    .allowsHitTesting(!isZoomed)
                }
            }
            .frame(height: barHeight)
            .offset(y: showDetailView ? (200 * dragProcess) : 200)
            .animation(.easeInOut(duration: 0.15), value: showDetailView)
            .animation(.easeInOut(duration: 0.15), value: isZoomed)
        }
    }
    private struct BottomNavBar: View {
        @Environment(ActivityPhotoGalleryCoordinator.self) private var activityPhotoGalleryCoordinator
        @Environment(\.verticalSizeClass) var verticalSizeClass
        let isHidden: Bool
        let dragProcess: CGFloat
        let showDetailView: Bool
        let onInfo: () -> Void
        let onDelete: () -> Void

        var body: some View {
            HStack {
                Button(action: onInfo) {
                    Image(systemName: "info")
                        .font(.system(size: 20))
                        .padding(18)
                        .foregroundStyle(.foreground)
                }
                .glassEffect(.regular.interactive(), in: Circle())
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                        .padding(14)
                        .foregroundStyle(.foreground)
                }
                .glassEffect(.regular.interactive(), in: Circle())
            }
            .padding()
            .padding(.bottom, verticalSizeClass == .regular ? 48 : 0)
            .frame(height: 56)
            .compositingGroup()
            .opacity(isHidden ? 0 : max(0, 1.0 - (dragProcess * 3.5)))
            .allowsHitTesting(!isHidden)
            .offset(y: showDetailView ? (200 * dragProcess) : 200)
            .animation(.easeInOut(duration: 0.15), value: showDetailView)
            .animation(.easeInOut(duration: 0.15), value: isHidden)
        }
    }

    private struct ActivityPhotoInfoSheet: View {
        let photo: ActivityPhoto
        let onResume: (ActivityTracker) -> Void
        let onShowHistory: () -> Void

        var body: some View {
            VStack(spacing: 24) {
                if let tracker = photo.tracker {
                    // 1. Goal Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Goal")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        if let goalID = photo.goalID {
                            let isCompleted = tracker.completedGoalTimestamps[goalID] != nil
                            let completedAt = tracker.completedGoalTimestamps[goalID]
                            
                            // Try to resolve goal title
                            let goalTitle = resolveGoalTitle(tracker: tracker, goalID: goalID) ?? photo.goalTitle ?? "Unknown Goal"
                            
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(isCompleted ? .green : .secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(goalTitle)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    if isCompleted, let date = completedAt {
                                        Text("Completed at \(date.formatted(date: .omitted, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Text("Photo taken at \(photo.createdAt.formatted(date: .omitted, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                             Text("No specific goal linked to this photo.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                    
                    // 2. Activity Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Activity")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Image(systemName: tracker.displaySymbolName)
                            Text(tracker.displayActivityName)
                                .fontWeight(.semibold)
                            if tracker.isCustomActivity {
                                Text("Custom")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 6)
                                    .background(
                                        Capsule().fill(Color.primary.opacity(0.08))
                                    )
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("Custom activity")
                            }
                        }

                        if let endedAt = tracker.endedAt {
                            Text("Completed • \(endedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("In progress")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    // 3. Actions
                    if tracker.isActive {
                        Button(action: { onResume(tracker) }) {
                            HStack {
                                Text("Resume activity")
                                Image(systemName: "play.fill")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .buttonStyle(.glassProminent)
                        }
                    } else {
                        Button(action: onShowHistory) {
                            Text("Show detailed history")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.primary)
                            
                        }
                        .buttonStyle(.glass)
                    }
                } else {
                    ContentUnavailableView("No activity data", systemImage: "exclamationmark.triangle")
                }
            }
            .padding()
            .padding()
        }
        
        private func resolveGoalTitle(tracker: ActivityTracker, goalID: UUID) -> String? {
             // Try to find in selected goals via meta
             if let goal = tracker.selectedGoals.first(where: { $0.id == goalID }) {
                 return goal.title
             }
             return nil
        }
        
        
    }

}
import SwiftUI
import UIKit

public struct ZoomableImageView: View {
    public let image: UIImage?

    // Behavior tuning
    public var minScale: CGFloat = 1.0
    public var maxScale: CGFloat = 5.0
    public var doubleTapZoomScale: CGFloat = 2.5
    public var canZoom: Bool = true

    // Expose zoom state so parent can disable paging / dismiss
    @Binding public var isZoomed: Bool
    @Binding public var isDismissing: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @State private var containerSize: CGSize = .zero
    @State private var fittedSize: CGSize = .zero
    
    public var onDismissInterruptedByPinch: (() -> Void)? = nil

    public init(
        image: UIImage?,
        isZoomed: Binding<Bool>,
        isDismissing: Binding<Bool>,
        minScale: CGFloat = 1.0,
        maxScale: CGFloat = 5.0,
        doubleTapZoomScale: CGFloat = 2.5,
        canZoom: Bool = true,
        onDismissInterruptedByPinch: (() -> Void)? = nil
    ) {
        self.image = image
        self._isZoomed = isZoomed
        self._isDismissing = isDismissing
        self.minScale = minScale
        self.maxScale = maxScale
        self.doubleTapZoomScale = doubleTapZoomScale
        self.canZoom = canZoom
        self.onDismissInterruptedByPinch = onDismissInterruptedByPinch
    }

    public var body: some View {
        GeometryReader { proxy in
            let container = proxy.size

            ZStack {

                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: container.width, height: container.height)
                        .scaleEffect(scale, anchor: .center)
                        .offset(offset)
                        .contentShape(Rectangle())
                        // Only allow panning gesture when zoomed.
                        .gesture(isZoomed ? panGesture : nil)
                        .simultaneousGesture(pinchGesture)
                        .onTapGesture(count: 2, perform: handleDoubleTap)
                        .onAppear {
                            containerSize = container
                            fittedSize = computeFittedSize(container: container, image: img)
                            resetToFit()
                        }
                        .onChange(of: proxy.size) { _, newSize in
                            containerSize = newSize
                            fittedSize = computeFittedSize(container: newSize, image: img)
                            offset = clamp(offset: offset, scale: scale)
                            lastOffset = offset
                        }
                        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: scale)
                        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: offset)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: container.width, height: container.height)
            .clipped()
        }
    }

    // MARK: - Gestures

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard canZoom else { return }

                if isDismissing {
                    onDismissInterruptedByPinch?()
                    return
                }

                let proposed = lastScale * value
                scale = clampScale(proposed)
                offset = clamp(offset: offset, scale: scale)
                syncZoomFlag()
            }
            .onEnded { _ in
                guard canZoom else { return }

                // NEW: also protect end phase
                if isDismissing {
                    onDismissInterruptedByPinch?()
                    return
                }

                lastScale = scale
                offset = clamp(offset: offset, scale: scale)
                lastOffset = offset
                syncZoomFlag()
            }
    }


    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .onChanged { value in
                guard !isDismissing else { return }
                let proposed = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clamp(offset: proposed, scale: scale)
            }
            .onEnded { _ in
                offset = clamp(offset: offset, scale: scale)
                lastOffset = offset
            }
    }

    // MARK: - Double tap

    private func handleDoubleTap() {
        guard canZoom, !isDismissing else { return }

        if isZoomed {
            resetToFit()
        } else {
            scale = clampScale(doubleTapZoomScale)
            lastScale = scale
            offset = clamp(offset: offset, scale: scale)
            lastOffset = offset
            syncZoomFlag()
        }
    }

    // MARK: - Helpers

    private func resetToFit() {
        scale = minScale
        lastScale = minScale
        offset = .zero
        lastOffset = .zero
        syncZoomFlag()
    }

    private func syncZoomFlag() {
        isZoomed = scale > (minScale + 0.001)
    }

    private func clampScale(_ s: CGFloat) -> CGFloat {
        min(max(s, minScale), maxScale)
    }

    private func computeFittedSize(container: CGSize, image: UIImage) -> CGSize {
        let iw = image.size.width
        let ih = image.size.height
        guard iw > 0, ih > 0, container.width > 0, container.height > 0 else { return .zero }

        let imageAspect = iw / ih
        let containerAspect = container.width / container.height

        if imageAspect > containerAspect {
            let w = container.width
            let h = w / imageAspect
            return CGSize(width: w, height: h)
        } else {
            let h = container.height
            let w = h * imageAspect
            return CGSize(width: w, height: h)
        }
    }

    private func clamp(offset: CGSize, scale: CGFloat) -> CGSize {
        guard containerSize.width > 0, containerSize.height > 0 else { return .zero }

        let zoomedWidth = fittedSize.width * scale
        let zoomedHeight = fittedSize.height * scale

        let maxX = max((zoomedWidth - containerSize.width) / 2.0, 0)
        let maxY = max((zoomedHeight - containerSize.height) / 2.0, 0)

        let clampedX = min(max(offset.width, -maxX), maxX)
        let clampedY = min(max(offset.height, -maxY), maxY)

        return CGSize(width: clampedX, height: clampedY)
    }
}
private struct TouchDownCatcher: UIViewRepresentable {
    let onTouchDown: () -> Void

    func makeUIView(context: Context) -> TouchDownView {
        let v = TouchDownView()
        v.onTouchDown = onTouchDown
        v.backgroundColor = .clear
        v.isMultipleTouchEnabled = true
        return v
    }

    func updateUIView(_ uiView: TouchDownView, context: Context) {
        uiView.onTouchDown = onTouchDown
    }

    final class TouchDownView: UIView {
        var onTouchDown: (() -> Void)?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            onTouchDown?()
            // We intentionally swallow touches while dismissing — we are settling anyway.
            // So no need to call super.
        }
    }
}
