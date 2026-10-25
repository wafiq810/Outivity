import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case home
    case progress
    case gallery
    case backpack
}

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Query var userInfos: [UserInfo]
    @AppStorage("UserInfoViewShown") private var UserInfoViewShown: Bool = false
    @State private var showingUserInfoView = false
    @State private var activityPhotoGalleryCoordinator = ActivityPhotoGalleryCoordinator()

    @State private var selectedTab: AppTab = .home
    @State private var pendingBackpackAdd: Bool = false
    @State private var showBackpackAddSheet: Bool = false

    private var isShowingPhotoDetail: Bool {
        activityPhotoGalleryCoordinator.selectedImage != nil
    }

    var body: some View {
        Group {
            if UserInfoViewShown {

                ZStack {
                    TabView(selection: $selectedTab) {
                        Tab("Home", systemImage: "house", value: AppTab.home) {
                            Home(menuRouteHandler: handleMenuRoute(_:))
                                .onAppear {
                                    withAnimation {
                                        activityPhotoGalleryCoordinator.resetForGalleryEntry()
                                    }
                                }
                        }

                        Tab("Your progress", systemImage: "figure.run", value: AppTab.progress) {
                            ActivityStatisticsView()
                        }

                        Tab("Gallery", systemImage: "photo.on.rectangle", value: AppTab.gallery) {
                            NavigationStack {
                                ActivityPhotoGalleryView()
                                    .environment(activityPhotoGalleryCoordinator)
                                    .allowsHitTesting(activityPhotoGalleryCoordinator.selectedImage == nil)
                            }
                            .onAppear {
                                withAnimation {
                                    activityPhotoGalleryCoordinator.resetForGalleryEntry()
                                }
                            }
                        }
                        Tab("BackPack", systemImage: "backpack", value: AppTab.backpack) {
                            BackPackView(showAddSheet: $showBackpackAddSheet)
                        }
                    }
                    .environment(activityPhotoGalleryCoordinator)
                    .toolbar(isShowingPhotoDetail ? .hidden : .visible, for: .tabBar)
                    .onChange(of: selectedTab) { _old, newTab in
                        // Reset hero/anchor state when switching between Home <-> Gallery.
                        // This prevents stale anchors from carrying across tab switches.
                        if (_old == .home && newTab == .gallery) || (_old == .gallery && newTab == .home) {
                            withAnimation {
                                activityPhotoGalleryCoordinator.resetForGalleryEntry()
                            }
                        }

                        if newTab == .backpack, pendingBackpackAdd {
                            DispatchQueue.main.async {
                                showBackpackAddSheet = true
                            }
                            pendingBackpackAdd = false
                        } else if newTab != .backpack {
                            pendingBackpackAdd = false
                        }
                    }

                    Rectangle()
                        .fill(.background)
                        .ignoresSafeArea()
                        .opacity(activityPhotoGalleryCoordinator.animateView
                                 ? 1 - activityPhotoGalleryCoordinator.dragProcess
                                 : 0)
                        .allowsHitTesting(false)
                        .zIndex(5)

                    if isShowingPhotoDetail {
                        ActivityPhotoDetailView()
                            .environment(activityPhotoGalleryCoordinator)
                            .allowsHitTesting(activityPhotoGalleryCoordinator.showDetailView)
                            .zIndex(10)
                    }

                }
                .overlayPreferenceValue(ActivityPhotoGalleryHeroKey.self) { value in
                    if let selectedImage = activityPhotoGalleryCoordinator.selectedImage,
                       let sAnchor = value[selectedImage.id.uuidString + "SOURCE"],
                       let dAnchor = value[selectedImage.id.uuidString + "DEST"] {

                        ActivityPhotoGalleryHeroLayer(
                            activityPhoto: selectedImage,
                            sAnchor: sAnchor,
                            dAnchor: dAnchor
                        )
                        .environment(activityPhotoGalleryCoordinator)
                    }
                }
                // Demo seeding is triggered after onboarding finishes (see `UserInfoView.saveUserPref()`).

            } else {
                VStack {
                    Image(systemName: "mountain.2.fill")
                        .opacity(0.2)
                        .foregroundColor(.accentColor)
                        .font(.system(size: 260))

                    VStack {
                        Text("Welcome to Outivity!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Image(systemName: "figure.outdoor.soccer")
                            .font(.system(size: 44))
                            .padding(18)
                            .background(Circle().fill(Color.accentColor))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button(action: { showingUserInfoView = true }) {
                        HStack {
                            Text("Let's begin")
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.right")
                                .font(.headline)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 28)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.accentColor)
                    .controlSize(.large)

                    Spacer().frame(height: 40)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingUserInfoView) {
            UserInfoView()
        }
    }

    private func handleMenuRoute(_ route: MenuRoute) {
        switch route {
        case .backpack:
            pendingBackpackAdd = false
            selectedTab = .backpack
        case .backpackAdd:
            pendingBackpackAdd = true
            showBackpackAddSheet = false
            selectedTab = .backpack
        case .progress:
            selectedTab = .progress
        case .gallery:
            selectedTab = .gallery
        default:
            break
        }
    }
}



public struct EditModeToggleButton: View {
    @Environment(\.editMode) private var editMode

    var inactiveSystemImageName: String = "square.and.pencil"
    var doneTitle: String = "Done"

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing ?? false
    }

    public var body: some View {
        Button {
            toggle()
        } label: {
            if isEditing {
                Text(doneTitle)
                    .fontWeight(.semibold)
            } else {
                Image(systemName: inactiveSystemImageName)
            }
        }
        .accessibilityLabel(isEditing ? doneTitle : "Edit")
    }

    private func toggle() {
        guard editMode != nil else { return }
        withAnimation {
            editMode?.wrappedValue = isEditing ? .inactive : .active
        }
    }
}
