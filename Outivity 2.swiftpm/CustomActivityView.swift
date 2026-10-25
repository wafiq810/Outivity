import SwiftUI
import SwiftData

extension Notification.Name {
    static let activityIdentityPicked = Notification.Name("CustomActivityView.activityIdentityPicked")
}

struct CustomActivityView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomActivity.name) private var customActivities: [CustomActivity]

    @State private var showAddSheet = false
    @State private var activityToEdit: CustomActivity? = nil

    @State private var deleteErrorMessage: String? = nil
    @State private var showDeleteErrorAlert: Bool = false

    var body: some View {
        ScrollView {
            VStack {
                if customActivities.isEmpty {
                    ContentUnavailableView(
                        "No Custom Activities",
                        systemImage: "plus.circle",
                        description: Text("Create your own activities.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(customActivities) { activity in
                            let identity = ActivityIdentity(custom: activity)
                            Button {
                                handleSelect(identity)
                            } label: {
                                ActivityCard(identity: identity, difficulty: activity.difficulty)
                                    .glassEffect(.regular.interactive())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Edit") { activityToEdit = activity }
                                Button("Delete", role: .destructive) {
                                    do {
                                        try CustomActivityStore.delete(activity, in: modelContext)
                                    } catch {
                                        deleteErrorMessage = error.localizedDescription
                                        showDeleteErrorAlert = true
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding()
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Custom Activities")
        .alert("Couldn’t delete activity", isPresented: $showDeleteErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "Please try again.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                AddNewCustomActivity(activity: nil)
            }
        }
        .sheet(item: $activityToEdit) { activity in
            NavigationStack {
                AddNewCustomActivity(activity: activity)
            }
        }
    }

    private func handleSelect(_ identity: ActivityIdentity) {
        NotificationCenter.default.post(name: .activityIdentityPicked, object: identity)
    }
}


struct AddNewCustomActivity: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var activity: CustomActivity?

    // UUID
    @State private var draftID: UUID
    init(activity: CustomActivity?) {
        self.activity = activity
        _draftID = State(initialValue: activity?.id ?? UUID())
    }

    // Existing state (unchanged)
    @State private var name: String = ""
    @State private var symbolName: String = "figure.run"
    @State private var difficulty: Int = 1

    @State private var needDistance: Bool = false
    @State private var needSteps: Bool = false
    @State private var needMET: Bool = false
    @State private var metValueStr: String = ""

    @State private var description: String = ""
    @State private var safetyWarnings: [String] = []

    @State private var minMinutes: Int = 15
    @State private var maxMinutes: Int = 60

    @State private var phoneAllowance: PhoneAvailability = .fullyAllowed

    struct EditableGoal: Identifiable, Hashable {
        let id = UUID()
        var title: String
        var difficulty: Int
    }
    @State private var editableGoals: [EditableGoal] = []

    @State private var builtInEquipmentIDs: [String] = []
    @State private var customEquipment: [CustomEquipment] = []

    @State private var showEquipmentPickerSheet = false
    @State private var showingSymbolPicker = false

    
    @Namespace private var formNamespace

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case description
    }

    // Wizard state
    private enum Step: Int, CaseIterable, Identifiable, Hashable {
        case basics, intensity, tracking, details, goals, equipment
        var id: Int { rawValue }

        var title: String {
            switch self {
            case .basics: return "Basics"
            case .intensity: return "Intensity"
            case .tracking: return "Tracking"
            case .details: return "Details"
            case .goals: return "Goals"
            case .equipment: return "Equipment"
            }
        }

        var systemImage: String {
            switch self {
            case .basics: return "sparkles"
            case .intensity: return "flame"
            case .tracking: return "waveform.path.ecg"
            case .details: return "text.alignleft"
            case .goals: return "target"
            case .equipment: return "backpack"
            }
        }
    }
    @State private var step: Step? = .basics
    private var currentStep: Step { step ?? .basics }

    private var previewIdentity: ActivityIdentity {
        if let activity {
            return ActivityIdentity(custom: activity)
        }

        let draft = CustomActivity(
            id: draftID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Activity" : name,
            symbolName: symbolName,
            difficulty: difficulty,
            needDistance: needDistance,
            needSteps: needSteps,
            metValue: needMET ? Double(metValueStr) : nil,
            userDescription: description,
            safetyWarnings: safetyWarnings,
            defaultGoals: [],
            minMinutes: minMinutes,
            maxMinutes: maxMinutes,
            phoneAllowance: phoneAllowance,
            customEquipment: customEquipment,
            builtInEquipmentIDs: builtInEquipmentIDs
        )

        return ActivityIdentity(custom: draft)
    }

    private var hasValidName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                
                previewHeader
                stepHeader
                
                // Horizontal pager with pages sized to the visible width and dynamic height
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        basicsStep
                            .containerRelativeFrame(.horizontal)
                            .id(Step.basics)
                        intensityStep
                            .containerRelativeFrame(.horizontal)
                            .id(Step.intensity)
                        trackingStep
                            .containerRelativeFrame(.horizontal)
                            .id(Step.tracking)
                        detailsStep
                            .containerRelativeFrame(.horizontal)
                            .id(Step.details)
                        goalsStep
                            .containerRelativeFrame(.horizontal)
                            .id(Step.goals)
                        equipmentStep
                            .containerRelativeFrame(.horizontal)
                            .id(Step.equipment)
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $step)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .padding(.top)
        .padding(.bottom, 12)
        .navigationTitle(activity == nil ? "New custom activity" : "Edit custom activity")
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if currentStep == .basics {
                        dismiss()
                    } else {
                        goBack()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(currentStep == .equipment ? "Finish" : "Next") {
                    if currentStep == .equipment {
                        save()
                    } else {
                        goNext()
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(!canAdvance)
            }
        }
        
        .onAppear { loadIfEditing() }
        .sheet(isPresented: $showingSymbolPicker) {
            SymbolPickerView(selectedSymbol: $symbolName)
        }
        .sheet(isPresented: $showEquipmentPickerSheet) {
            EquipmentPickerSheet(
                isPresented: $showEquipmentPickerSheet,
                selectedEquipment: $builtInEquipmentIDs.asEquipmentSelection(),
                selectedCustomEquipment: $customEquipment,
                title: "Equipment",
                showsAddCustomEquipmentButton: true
            )
        }
    }
    // MARK: - Header UI

    private var previewHeader: some View {
        VStack(alignment: .leading, spacing: 8){
            Text("Your activity's preview")
                .fontWeight(.bold)
            ActivityCard(identity: previewIdentity, difficulty: difficulty, showsSelectedCheck: false)
                .glassEffect(.regular.interactive())
                .onTapGesture {

                }
        }
        .padding()
        .padding(.horizontal)
    }


    private var stepHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Label(currentStep.title, systemImage: currentStep.systemImage)
                    .font(.headline)
                Spacer()
                Text("\(stepIndex + 1) / \(Step.allCases.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(Step.allCases) { s in
                    Capsule()
                        .frame(height: 6)
                        .opacity(s.rawValue <= currentStep.rawValue ? 1 : 0.18)
                }
            }
        }
        .padding()
        .padding(.horizontal)
        // Prevent the header/progress UI from inheriting the TabView paging animation.
        .animation(.easeInOut(duration: 0.18), value: currentStep)    }


    // MARK: - Steps

    private var basicsStep: some View {
        VStack(spacing: 16) {
            sectionCard {
                VStack(spacing: 12) {
                    Image(systemName: symbolName)
                        .font(.system(size: 90))
                        .foregroundStyle(.blue)
                        .matchedGeometryEffect(id: "icon", in: formNamespace)

                    Button { showingSymbolPicker = true } label: {
                        Text("Change Icon")
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.glass)

                    TextField("Activity Name", text: $name)
                        .padding()
                        .glassEffect()
                        .focused($focusedField, equals: .name)
                }
            }
            
            sectionCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)

                    TextField("Describe your activity (Optional)", text: $description, axis: .vertical)
                        .padding()
                        .glassEffect(in: RoundedRectangle(cornerRadius: 24))
                        .focused($focusedField, equals: .description)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
    }

    private var intensityStep: some View {
        VStack(spacing: 16) {
            sectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Difficulty")
                        .font(.headline)
                    DifficultySelector(difficulty: $difficulty)
                }
            }

            sectionCard {
                HStack {
                    Text("Estimated Minutes")
                        .font(.headline)
                    Spacer()
                    TextField("Min", value: $minMinutes, format: .number)
                        .multilineTextAlignment(.center)
                        .frame(width: 48)
                    Text("to")
                    TextField("Max", value: $maxMinutes, format: .number)
                        .multilineTextAlignment(.center)
                        .frame(width: 48)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
    }

    private var trackingStep: some View {
        VStack(spacing: 16) {
            sectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Phone Availability")
                            .font(.headline)
                        Spacer()
                        Picker("Phone Allowance", selection: $phoneAllowance) {
                            Text("Fully Allowed").tag(PhoneAvailability.fullyAllowed)
                            Text("Allowed with Risk").tag(PhoneAvailability.allowedWithRisk)
                            Text("Not Allowed").tag(PhoneAvailability.notAllowed)
                        }
                        .pickerStyle(.menu)
                    }

                    if phoneAllowance != .notAllowed {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tracking")
                                .font(.headline)

                            Toggle("Track Distance", isOn: $needDistance)
                            Toggle("Track Steps", isOn: $needSteps)

                            Toggle("Track Calories", isOn: $needMET)
                                .tint(.orange)

                            if needMET {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Metabolic Equivalent of Task (MET)")
                                        .fontWeight(.semibold)

                                    TextField("MET Value", text: $metValueStr)
                                        .padding()
                                        .keyboardType(.decimalPad)
                                        .glassEffect(in: RoundedRectangle(cornerRadius: 18))

                                    Text("The metabolic equivalent of a task (MET) measures how intense an activity is, helping calculate how many calories you burn.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Button {
                                        
                                    } label: {
                                        Text("How should I choose MET?")
                                            .font(.caption)
                                            .foregroundStyle(Color.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .transition(.opacity)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
    }

    private var detailsStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                sectionCard {
                    SafetyWarningsEditor(safetyWarnings: $safetyWarnings)
                }

                Spacer(minLength: 0)
            }
            .padding()
        }
    }


    private var goalsStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                sectionCard { GoalsEditor(editableGoals: $editableGoals) }
                Spacer(minLength: 0)
            }
            .padding()
        }
    }

    private var equipmentStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                sectionCard {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Equipment")
                                .font(.headline)
                            Spacer()
                            Button { showEquipmentPickerSheet = true } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.glassProminent)
                        }

                        EquipmentSelectionPreview(
                            builtInEquipmentIDs: builtInEquipmentIDs,
                            customEquipment: customEquipment
                        )
                    }
                }

                Spacer(minLength: 0)
            }
            .padding()
        }
    }

    
    private struct EquipmentSelectionPreview: View {
        let builtInEquipmentIDs: [String]
        let customEquipment: [CustomEquipment]

        private let columns: [GridItem] = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                let builtIn = builtInEquipmentIDs.compactMap(Equipment.init(rawValue:))
                if !builtIn.isEmpty {
                    Text("Selected Built-in Equipment").font(.subheadline)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(builtIn) { equipment in
                            EquipmentCardView(symbolName: equipment.symbolName, title: equipment.displayName)
                        }
                    }
                }

                if !customEquipment.isEmpty {
                    Text("Selected Custom Equipment").font(.subheadline)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(customEquipment) { equipment in
                            EquipmentCardView(symbolName: equipment.symbolName, title: equipment.displayName)
                        }
                    }
                }

                if builtIn.isEmpty && customEquipment.isEmpty {
                    Text("No equipment selected yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private struct DifficultySelector: View {
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
                                        color: level == difficulty
                                            ? Color.black.opacity(0.15)
                                            : .clear,
                                        radius: 2,
                                        x: 0,
                                        y: 1
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                level == difficulty
                                                    ? Color.blue
                                                    : Color.gray.opacity(0.2),
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

    private struct SafetyWarningsEditor: View {
        @Binding var safetyWarnings: [String]

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Safety Warnings")
                        .font(.headline)
                    Spacer()
                    Button {
                        safetyWarnings.append("")
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add safety warning")
                }

                if safetyWarnings.isEmpty {
                    Text("No warnings added")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(safetyWarnings.indices), id: \.self) { idx in
                        HStack(alignment: .center, spacing: 8) {
                            TextField("Warning \(idx + 1)", text: Binding(
                                get: { safetyWarnings[idx] },
                                set: { safetyWarnings[idx] = $0 }
                            ))
                            .textInputAutocapitalization(.sentences)
                            .disableAutocorrection(false)

                            Button(role: .destructive) {
                                safetyWarnings.remove(at: idx)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove warning \(idx + 1)")
                        }
                    }
                }
            }
        }
    }

    private struct GoalsEditor: View {
        @Binding var editableGoals: [EditableGoal]

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Default Goals")
                        .font(.headline)
                    Spacer()
                    Button {
                        editableGoals.append(EditableGoal(title: "", difficulty: 1))
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add default goal")
                }

                if editableGoals.isEmpty {
                    Text("No default goals added")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(editableGoals.indices), id: \.self) { idx in
                        HStack(spacing: 8) {
                            TextField("Title", text: Binding(
                                get: { editableGoals[idx].title },
                                set: { editableGoals[idx].title = $0 }
                            ))
                            .textInputAutocapitalization(.words)

                            Stepper(value: Binding(
                                get: { editableGoals[idx].difficulty },
                                set: { editableGoals[idx].difficulty = max(1, min(5, $0)) }
                            ), in: 1...5) {
                                Text("Diff \(editableGoals[idx].difficulty)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Button(role: .destructive) {
                                editableGoals.remove(at: idx)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove goal \(idx + 1)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    private var stepIndex: Int { currentStep.rawValue }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canAdvance: Bool {
        guard hasValidName else { return false }
        if currentStep == .tracking, needMET { return parsedMET() != nil }
        return true
    }



    private func goNext() {
        let s = step ?? .basics
        guard s != .equipment else { return }
        let next = min(s.rawValue + 1, Step.allCases.count - 1)
        withAnimation(.snappy(duration: 0.35)) {
            step = Step(rawValue: next)
        }
    }

    private func goBack() {
        let s = step ?? .basics
        let prev = max(s.rawValue - 1, 0)
        withAnimation(.snappy(duration: 0.35)) {
            step = Step(rawValue: prev)
        }
    }


    private func parsedMET() -> Double? {
        guard needMET else { return nil }
        return Double(metValueStr.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func sectionCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding()
            .glassEffect(in: RoundedRectangle(cornerRadius: 32))
    }

    @MainActor
    private func loadIfEditing() {
        guard let activity else { return }
        name = activity.name
        symbolName = activity.symbolName
        difficulty = activity.difficulty
        needDistance = activity.needDistance
        needSteps = activity.needSteps
        needMET = activity.metValue != nil
        if let m = activity.metValue { metValueStr = "\(m)" }
        description = activity.userDescription
        safetyWarnings = activity.safetyWarnings.isEmpty ? [] : activity.safetyWarnings
        editableGoals = activity.defaultGoals.map {
            EditableGoal(title: $0.title, difficulty: max(1, min(5, $0.difficulty)))
        }
        minMinutes = activity.minMinutes
        maxMinutes = activity.maxMinutes
        phoneAllowance = activity.phoneAllowance
        builtInEquipmentIDs = activity.builtInEquipmentIDs
        customEquipment = activity.customEquipment
    }

    @MainActor
    private func save() {
        let warnings = safetyWarnings
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let cleanGoals: [GoalTemplate] = editableGoals
            .map { EditableGoal(title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines),
                                difficulty: max(1, min(5, $0.difficulty))) }
            .filter { !$0.title.isEmpty }
            .map { GoalTemplate(id: UUID(), title: $0.title, difficulty: $0.difficulty) }

        let met = parsedMET()

        do {
            _ = try CustomActivityStore.upsert(
                activity: activity,
                name: name,
                symbolName: symbolName,
                difficulty: difficulty,
                needDistance: needDistance,
                needSteps: needSteps,
                metValue: met,
                userDescription: description,
                safetyWarnings: warnings,
                defaultGoals: cleanGoals,
                minMinutes: minMinutes,
                maxMinutes: maxMinutes,
                phoneAllowance: phoneAllowance,
                customEquipment: customEquipment,
                builtInEquipmentIDs: builtInEquipmentIDs,
                in: modelContext
            )
            dismiss()
        } catch {

        }
    }
}
