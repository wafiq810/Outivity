//
//  SwiftUIView.swift
//  Outivity
//
//  Created by Wafiq on 12/30/25.
//

import SwiftUI
import SwiftData

struct ActivityPhotoGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ActivityPhotoGalleryCoordinator.self) private var activityPhotoGalleryCoordinator
    @Query private var userInfos: [UserInfo]

    private var userInfo: UserInfo? { userInfos.first }
    private var isDemoMode: Bool { userInfo?.demoMode == true }

    let column = Array(repeating: GridItem(spacing: 3), count: 3)
    // Create a local binding to handle navigation state
    
    @State private var showingInfoPhoto: ActivityPhoto?
    @State private var showDeleteConfirmation = false
    @State private var photoToDelete: ActivityPhoto?

    private var pendingTrackerBinding: Binding<ActivityTracker?> {
        Binding(
            get: { activityPhotoGalleryCoordinator.pendingHistoryNavigation },
            set: { activityPhotoGalleryCoordinator.pendingHistoryNavigation = $0 }
        )
    }

    var body: some View {
        ScrollView(.vertical){
            NavigationStack {
                if activityPhotoGalleryCoordinator.activityPhotos.isEmpty {
                    Section{} footer: {
                        VStack(alignment: .center) {
                            
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 44))
                                .padding(18)
                                .background(Circle().fill(Color.secondary))
                                .foregroundColor(.white)
                            
                            Text("No photos yet")
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text("Capture a goal photo to see it in the gallery.")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                } else {
                    LazyVGrid(columns: column, spacing: 3) {
                        ForEach(activityPhotoGalleryCoordinator.activityPhotos) { activityPhoto in
                            GridImageView(activityPhoto)
                                .onTapGesture {
                                    activityPhotoGalleryCoordinator.presentedPhotos = [] // use global list
                                    activityPhotoGalleryCoordinator.selectedImage = activityPhoto
                                    activityPhotoGalleryCoordinator.detailScrollPosition = activityPhoto.id.uuidString
                                    activityPhotoGalleryCoordinator.detailIndicatorPosition = activityPhoto.id.uuidString
                                    
                                    DispatchQueue.main.async {
                                        activityPhotoGalleryCoordinator.toggleView(show: true)
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        withAnimation {
                                            activityPhotoGalleryCoordinator.selectedImage = activityPhoto
                                            activityPhotoGalleryCoordinator.showInfoSheetOnPresentation = false
                                            activityPhotoGalleryCoordinator.toggleView(show: true)
                                        }
                                        
                                    } label: {
                                        Label("View Photo", systemImage: "photo")
                                    }
                                    
                                    Button {
                                        activityPhotoGalleryCoordinator.presentedPhotos = []
                                        activityPhotoGalleryCoordinator.selectedImage = activityPhoto
                                        activityPhotoGalleryCoordinator.detailScrollPosition = activityPhoto.id.uuidString
                                        activityPhotoGalleryCoordinator.detailIndicatorPosition = activityPhoto.id.uuidString
                                        activityPhotoGalleryCoordinator.showInfoSheetOnPresentation = true
                                        DispatchQueue.main.async {
                                            activityPhotoGalleryCoordinator.toggleView(show: true)
                                        }
                                    } label: {
                                        Label("View info", systemImage: "info.circle")
                                    }
                                    
                                    if let tracker = activityPhoto.tracker {
                                        Button {
                                            activityPhotoGalleryCoordinator.pendingHistoryNavigation = tracker
                                        } label: {
                                            Label("See activity history", systemImage: "clock")
                                        }
                                    }
                                    
                                    if !isDemoMode {
                                        Button(role: .destructive) {
                                            photoToDelete = activityPhoto
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete Photo", systemImage: "trash")
                                        }
                                    }
                                } preview: {
                                    if let previewImage = activityPhoto.getPreviewImage() {
                                        Image(uiImage: previewImage)
                                            .resizable()
                                            .scaledToFill()
                                    }
                                }
                        }
                    }
                }
            }
            .padding(.vertical, 15)
            
            .navigationTitle("Gallery")
            .onAppear{
                activityPhotoGalleryCoordinator.loadPhotos(from: modelContext, userInfo: userInfo)
            }
            .onDisappear {
                activityPhotoGalleryCoordinator.resetForGalleryEntry()
            }
            .navigationDestination(item: pendingTrackerBinding) { tracker in
                ActivityHistoryDetailView(tracker: tracker)
            }
            .alert("Delete photo?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    photoToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    guard !isDemoMode else {
                        // Demo photos aren't persisted.
                        photoToDelete = nil
                        return
                    }
                    if let photo = photoToDelete {
                        modelContext.delete(photo)
                        // Reload or let autosave handle it
                        if let index = activityPhotoGalleryCoordinator.activityPhotos.firstIndex(where: { $0.id == photo.id }) {
                             activityPhotoGalleryCoordinator.activityPhotos.remove(at: index)
                        }
                    }
                    photoToDelete = nil
                }
            } message: {
                Text(isDemoMode ? "Demo photos can't be deleted." : "This activity photo will be permanently deleted.")
            }
        }
    }
    
    @ViewBuilder
    func GridImageView(_ activityPhoto: ActivityPhoto) -> some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .anchorPreference(key: ActivityPhotoGalleryHeroKey.self, value: .bounds) { anchor in
                    [activityPhoto.id.uuidString + "SOURCE": anchor]
                }

            if let previewImage = activityPhoto.getPreviewImage() {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .opacity(
                        activityPhotoGalleryCoordinator.selectedImage?.id == activityPhoto.id &&
                        activityPhotoGalleryCoordinator.animateView ? 0 : 1
                    )
            }
            
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .contentShape(.rect)
    }
    
    

}
