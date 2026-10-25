import SwiftUI
import SwiftData

struct CustomGoalView: View {
    let identity: ActivityIdentity
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // If selecting, bind to a selection set (IDs for safer set usage)
    @Binding var selectedGoalIDs: Set<UUID>
    let isSelectionMode: Bool
    
    @Query private var goals: [CustomGoal]
    
    @State private var showingAddSheet = false
    @State private var goalToEdit: CustomGoal?
    
    init(identity: ActivityIdentity, selectedGoalIDs: Binding<Set<UUID>> = .constant([]), isSelectionMode: Bool = false) {
        self.identity = identity
        self._selectedGoalIDs = selectedGoalIDs
        self.isSelectionMode = isSelectionMode
        
        switch identity.kind {
        case .builtIn(let activity):
            let raw = activity.rawValue
            _goals = Query(
                filter: #Predicate<CustomGoal> { $0.builtInActivityID == raw },
                sort: [
                    SortDescriptor(\CustomGoal.customActivityID, order: .reverse),
                    SortDescriptor(\CustomGoal.title)
                ]
            )
        case .custom(let uuid):
            _goals = Query(
                filter: #Predicate<CustomGoal> { $0.customActivityID == uuid },
                sort: [
                    SortDescriptor(\CustomGoal.customActivityID, order: .reverse),
                    SortDescriptor(\CustomGoal.title)
                ]
            )
        }
    }
    
    var body: some View {
        List {
            if goals.isEmpty {
                Section{} footer: {
                    VStack(alignment: .center) {
                        
                        Image(systemName: "target")
                            .font(.system(size: 44))
                            .padding(18)
                            .background(Circle().fill(Color.secondary))
                            .foregroundColor(.white)
                        
                        Text("No custom goal yet")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)

                        Text("Tap \(Image(systemName: "plus")) to add goals specific to this activity.")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }            }
            
            ForEach(goals) { goal in
                HStack {
                    if isSelectionMode {
                        Image(systemName: selectedGoalIDs.contains(goal.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(.blue)
                            .onTapGesture {
                                toggleSelection(goal)
                            }
                    }

                    VStack(alignment: .leading) {
                        HStack(spacing: 8) {
                            Text(goal.title)
                                .font(.headline)
                            if goal.customActivityID != nil {
                                Text("Custom")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.blue.opacity(0.15)))
                                    .foregroundStyle(.blue)
                            }
                            if !isSelectionMode {
                                Button {
                                    goalToEdit = goal
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Edit goal")
                            }
                        }
                        Text("Difficulty: \(goal.difficulty)")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Edit button
                    if !isSelectionMode {
                        Button {
                            goalToEdit = goal
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Edit goal")
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSelectionMode {
                        toggleSelection(goal)
                    }
                }
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        CustomGoalStore.delete(goal, in: modelContext)
                        // also remove from selection if deleted
                        selectedGoalIDs.remove(goal.id)
                    }
                    Button("Edit") {
                        goalToEdit = goal
                    }
                }
                .contextMenu {
                     Button("Edit") { goalToEdit = goal }
                     Button("Delete", role: .destructive) {
                        CustomGoalStore.delete(goal, in: modelContext)
                        selectedGoalIDs.remove(goal.id)
                     }
                }
            }
        }
        .navigationTitle("Custom Goals")
        .toolbar {
            Button(action: { showingAddSheet = true }) {
                Label("Add", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                CustomGoalEditView(identity: identity, goal: nil)
            }
        }
        .sheet(item: $goalToEdit) { goal in
            NavigationStack {
                CustomGoalEditView(identity: identity, goal: goal)
            }
        }
    }
    
    func toggleSelection(_ goal: CustomGoal) {
        if selectedGoalIDs.contains(goal.id) {
            selectedGoalIDs.remove(goal.id)
        } else {
            selectedGoalIDs.insert(goal.id)
        }
    }
}

struct CustomGoalEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let identity: ActivityIdentity
    var goal: CustomGoal?
    
    @State private var title: String = ""
    @State private var difficulty: Int = 1
    
    init(identity: ActivityIdentity, goal: CustomGoal?) {
        self.identity = identity
        self.goal = goal
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Goal Title", text: $title)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Difficulty")
                        .font(.headline)
                    FlameDifficultyPicker(difficulty: $difficulty)
                }
            } footer: {
               Text("Goals are specific to this activity.")
            }
        }
        .navigationTitle(goal == nil ? "New Goal" : "Edit Goal")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .buttonStyle(.glassProminent)
                    .disabled(title.isEmpty)
            }
        }
        .onAppear {
            if let goal {
                title = goal.title
                difficulty = goal.difficulty
            }
        }
    }
    
    func save() {
        if let goal {
            goal.title = title
            goal.difficulty = difficulty
        } else {
            _ = CustomGoalStore.create(title: title, difficulty: difficulty, for: identity, in: modelContext)
        }
        try? modelContext.save()
        dismiss()
    }
}

private struct FlameDifficultyPicker: View {
    @Binding var difficulty: Int
    var body: some View {
        HStack {
            ForEach(1...5, id: \.self) { level in
                Spacer()
                Button {
                    withAnimation(.spring()) {
                        difficulty = level
                    }
                } label: {
                    Image(systemName: level <= difficulty ? "flame.fill" : "flame")
                        .font(.system(size: level == difficulty ? 22 : 18))
                        .foregroundStyle(level <= difficulty ? Color.white : Color.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(level <= difficulty ? Color.blue : Color(.systemBackground))
                                .shadow(
                                    color: level == difficulty ? Color.black.opacity(0.15) : .clear,
                                    radius: 2,
                                    x: 0,
                                    y: 1
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            level == difficulty ? Color.blue : Color.gray.opacity(0.2),
                                            lineWidth: level == difficulty ? 0 : 1
                                        )
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(level) out of 5 difficulty")
                .accessibilityAddTraits(level == difficulty ? .isSelected : [])
                Spacer()
            }
        }
    }
}

