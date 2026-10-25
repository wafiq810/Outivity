import SwiftUI
import SwiftData

// MARK: - 1) ActivityCard

public struct ActivityCard: View {
    public let identity: ActivityIdentity
    public var difficulty: Int
    public var difficultyLevel: String
    public var showsSelectedCheck: Bool
    
    public init(identity: ActivityIdentity, difficulty: Int? = nil, showsSelectedCheck: Bool = false) {
        self.identity = identity
        self.showsSelectedCheck = showsSelectedCheck
        
        let d: Int
        if let difficulty {
            d = difficulty
        } else {
             if case .builtIn(let a) = identity.kind { d = a.difficulty }
             else { d = 1 }
        }
        self.difficulty = d
        
        switch d {
        case 1: self.difficultyLevel = "Very Easy"
        case 2: self.difficultyLevel = "Easy"
        case 3: self.difficultyLevel = "Moderate"
        case 4: self.difficultyLevel = "Hard"
        case 5: self.difficultyLevel = "Very Hard"
        default: self.difficultyLevel = "Unknown"
        }
    }
    
    // Compatibility
    public init(activity: Activity, showsSelectedCheck: Bool = false) {
        self.init(identity: ActivityIdentity(activity: activity), difficulty: activity.difficulty, showsSelectedCheck: showsSelectedCheck)
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: identity.symbolName)
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(circleBackground)
                .clipShape(.circle)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(identity.displayName)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(Color.primary)
                    .font(.headline)
                Text(difficultyLevel)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            
            Spacer(minLength: 0)
            
            HStack(spacing: 2) {
                ForEach(0..<5) { idx in
                    Image(systemName: idx < difficulty ? "flame.fill" : "flame")
                        .font(.caption)
                    .foregroundColor(idx < difficulty ? .orange : .gray.opacity(0.3)) }
            }
            
            if showsSelectedCheck {
                Image(systemName: "checkmark")
                    .font(.headline)
                    .foregroundStyle(.foreground)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .contentShape(Rectangle())
    }
    
    public var circleBackground: some View {
        let hue = identity.colorHue
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.6, brightness: 0.9),
                Color(hue: hue, saturation: 0.8, brightness: 0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - 2) ActivityCardList

public struct ActivityCardList: View {
    private let title: String
    private let showsCloseButton: Bool
    
    private let onSelectIdentity: ((ActivityIdentity) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var customActivities: [CustomActivity]
    
    @State private var searchText: String = ""
    
    public init(
        title: String = "Activities",
        showsCloseButton: Bool = true,
        onSelect: ((ActivityIdentity) -> Void)? = nil
    ) {
        self.title = title
        self.showsCloseButton = showsCloseButton
        self.onSelectIdentity = onSelect
    }
    
    // Compatibility init: Only calls back if built-in selected.
    public init(
        title: String = "Activities",
        showsCloseButton: Bool = true,
        onSelectActivity: ((Activity) -> Void)? = nil
    ) {
        self.title = title
        self.showsCloseButton = showsCloseButton
        if let callback = onSelectActivity {
            self.onSelectIdentity = { identity in
                if case .builtIn(let a) = identity.kind { callback(a) }
            }
        } else {
            self.onSelectIdentity = nil
        }
    }

    private var filteredCustom: [ActivityIdentity] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let custom = customActivities.sorted { $0.name < $1.name }
        let visibleCustom: [CustomActivity]
        if query.isEmpty {
            visibleCustom = custom
        } else {
            visibleCustom = custom.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        return visibleCustom.map { ActivityIdentity(custom: $0) }
    }

    private var filteredBuiltIn: [ActivityIdentity] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let builtIn = Activity.allCases
        let visibleBuiltIn: [Activity]
        if query.isEmpty {
            visibleBuiltIn = builtIn
        } else {
            visibleBuiltIn = builtIn.filter {
                $0.displayName.localizedCaseInsensitiveContains(query) ||
                $0.difficultyLevel.localizedCaseInsensitiveContains(query)
            }
        }
        return visibleBuiltIn.map { ActivityIdentity(activity: $0) }
    }

    public var body: some View {
        ScrollView {
            if filteredCustom.isEmpty && filteredBuiltIn.isEmpty {
                ContentUnavailableView(
                    "No activities found",
                    systemImage: "magnifyingglass",
                    description: Text("Try searching or create a new custom activity.")
                )
                .padding(.top, 40)
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if !filteredCustom.isEmpty {
                        Text("Custom activities")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        LazyVStack(spacing: 12) {
                            ForEach(filteredCustom) { identity in
                                row(for: identity)
                            }
                        }
                        .padding(.horizontal)
                    }

                    if !filteredBuiltIn.isEmpty {
                        Text("Built in activities")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, filteredCustom.isEmpty ? 0 : 8)
                            .padding(.horizontal)
                        LazyVStack(spacing: 12) {
                            ForEach(filteredBuiltIn) { identity in
                                row(for: identity)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
                .padding(.top, 8)
            }
        }
        .navigationTitle(title)
        .searchable(text: $searchText, prompt: "Search activities")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if showsCloseButton {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                } else {
                    EmptyView()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AddNewCustomActivity(activity: nil)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    @ViewBuilder
    private func row(for identity: ActivityIdentity) -> some View {
        let diff: Int = {
            if case .builtIn(let a) = identity.kind { return a.difficulty }
            if case .custom(let uuid) = identity.kind, let c = customActivities.first(where: { $0.id == uuid }) { return c.difficulty }
            return 1
        }()
        
        if let onSelectIdentity {
            Button {
                onSelectIdentity(identity)
                dismiss()
            } label: {
                ActivityCard(identity: identity, difficulty: diff)
                    .glassEffect(.regular.interactive())
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                ActivityDetailedView(identity: identity)
            } label: {
                ActivityCard(identity: identity, difficulty: diff)
                    .glassEffect(.regular.interactive())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 3) ActivityCardPicker (Supports Custom Activities)

public struct ActivityCardPicker: View {
    private let title: String
    private let noneTitle: String?
    @Binding private var selection: ActivityIdentity?
    @State private var isPresented = false
    
    /// Non-optional initializer
    public init(selection: Binding<ActivityIdentity>, title: String = "Choose Activity") {
        self.title = title
        self.noneTitle = nil
        self._selection = Binding<ActivityIdentity?>(
            get: { selection.wrappedValue },
            set: { if let v = $0 { selection.wrappedValue = v } }
        )
    }
    
    /// Optional initializer (shows a "None" row)
    public init(
        optional selection: Binding<ActivityIdentity?>,
        title: String = "Choose Activity",
        noneTitle: String = "None"
    ) {
        self.title = title
        self.noneTitle = noneTitle
        self._selection = selection
    }

    public var body: some View {
         Button {
            isPresented = true
        } label: {
            if let selected = selection {
                ActivityCard(identity: selected)
                    .glassEffect(.regular.interactive())
            } else {
                 HStack {
                    Text(noneTitle ?? "None")
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(Color.primary)
                }
                .padding()
                .glassEffect(.regular.interactive())
            }
        }
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                ActivityCardList(title: title, showsCloseButton: true) { identity in
                    selection = identity
                }
            }
        }
    }
}
