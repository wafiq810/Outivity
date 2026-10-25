//
//  SwiftUIView.swift
//  Outivity-pretest
//
//  Created by Wafiq on 12/23/25.
//

import SwiftUI
import SwiftData

struct UserInfoView: View {
    @AppStorage("UserInfoViewShown") var UserInfoViewShown: Bool = false

    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    // Shared onboarding state
    @State private var name: String = ""
    @State private var age: Int = 18
    @State private var weight: Int = 170
    @State private var existingActivities: Set<Activity> = []
    @State private var existingEquipment: Set<Equipment> = []

    @State private var environment: Theme = .other
    @State private var intensity: Int = 3
    @State private var tryNewPreference: TryNewLevel = .onlyRelated
    @State private var userLimitations: Set<UserLimitation> = []

    @State private var minutesOutside: Int = 60

    public enum Step: Int, CaseIterable {
        case aboutYou = 0
        case preferences = 1
        case planHours = 2

        var title: String {
            switch self {
            case .aboutYou: return "About you"
            case .preferences: return "Preferences"
            case .planHours: return "Plan hours"
            }
        }

        var showsBack: Bool { self != .aboutYou }
        var isLast: Bool { self == .planHours }
    }

    @State private var isPresentingOnboarding: Bool = false
    @State private var currentStep: Step = .aboutYou
    @State private var navigationDirection: Int = 1
    @State private var didLoadDefaults: Bool = false

    // Demo onboarding uses a trimmed flow (no name/age/weight, no plan hours).
    @State private var isDemoOnboarding: Bool = false

    var body: some View {
        // This view only hosts the onboarding sheet.
        VStack(spacing: 16) {
            Image(systemName: "figure.outdoor.soccer")
                .font(.system(size: 44))
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(.circle)

            Text("Let's set us up!")
                .font(.title)
                .fontWeight(.semibold)

            Text("We'll ask a few quick questions to personalize your experience.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Start") {
                isDemoOnboarding = false
                isPresentingOnboarding = true
                
                UserInfoStore.ensureSingleInstance(in: modelContext)
                let userInfo = UserInfoStore.fetchOrCreate(in: modelContext)

                name = userInfo.name ?? ""
                age = userInfo.age
                weight = userInfo.weight
                existingActivities = Set(userInfo.existingActivities)
                minutesOutside = userInfo.minutesOutside

                environment = userInfo.environment
                intensity = userInfo.intensity
                tryNewPreference = userInfo.tryNewPreference
                userLimitations = Set(userInfo.userLimitations)

                withAnimation{
                    currentStep = .aboutYou
                }
            }
            .padding()
            .tint(.blue)
            .glassEffect(.regular.tint(.blue).interactive())
            .foregroundStyle(.white)

            Text("For Congressional App Challenge")
                .foregroundStyle(.secondary)
            Button {
                isDemoOnboarding = true
                isPresentingOnboarding = true

                UserInfoStore.ensureSingleInstance(in: modelContext)
                let userInfo = UserInfoStore.fetchOrCreate(in: modelContext)
                userInfo.demoMode = true
                try? modelContext.save()

                // Load existing values (if any) into the onboarding form.
                existingActivities = Set(userInfo.existingActivities)
                existingEquipment = Set(userInfo.existingEquipment)

                environment = userInfo.environment
                intensity = userInfo.intensity
                tryNewPreference = userInfo.tryNewPreference
                userLimitations = Set(userInfo.userLimitations)

                withAnimation {
                    currentStep = .aboutYou
                }
            }
            label: {
                Text("Start Demo")
                    .padding()
            }
            .buttonStyle(.glass)
            .tint(.secondary)

        }.sheet(isPresented: $isPresentingOnboarding) {
            OnboardingContainerView(
                isDemoMode: isDemoOnboarding,
                currentStep: $currentStep,
                navigationDirection: $navigationDirection,
                name: $name,
                age: $age,
                existingActivities: $existingActivities, existingEquipment: $existingEquipment,
                weight: $weight,
                environment: $environment,
                intensity: $intensity,
                tryNewPreference: $tryNewPreference,
                userLimitations: $userLimitations,
                minutesOutside: $minutesOutside,
                onClose: { isPresentingOnboarding = false; dismiss() },
                onFinish: saveUserPref
            )
            .interactiveDismissDisabled()
        }
        .padding()
        
        
            
    }

    private func saveUserPref() {
        guard (0...1440).contains(minutesOutside) else { return }
        let userInfo = UserInfoStore.fetchOrCreate(in: modelContext)
        userInfo.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        userInfo.age = age
        userInfo.weight = weight
        userInfo.existingActivities = Array(existingActivities)
        userInfo.existingEquipment = Array(existingEquipment)
        userInfo.environment = environment
        userInfo.intensity = intensity
        userInfo.tryNewPreference = tryNewPreference
        userInfo.userLimitations = Array(userLimitations)
        // Record this as a preference change so history is downweighted immediately.
        userInfo.preferencesLastChangedAt = Date()
        // Persist the updated user info immediately.
        try? modelContext.save()

        // If demo mode is enabled, seed demo history after the user's setup inputs are saved.
        DemoModeSeeder.ensureSeededIfNeeded(in: modelContext)

        UserInfoViewShown = true
        isPresentingOnboarding = false
        dismiss()
    }

}

private struct OnboardingContainerView: View {
    let isDemoMode: Bool

    @Binding var currentStep: UserInfoView.Step
    @Binding var navigationDirection: Int

    @Binding var name: String
    @Binding var age: Int
    @Binding var existingActivities: Set<Activity>
    @Binding var existingEquipment: Set<Equipment>
    @Binding var weight: Int

    @Binding var environment: Theme
    @Binding var intensity: Int
    @Binding var tryNewPreference: TryNewLevel
    @Binding var userLimitations: Set<UserLimitation>

    @Binding var minutesOutside: Int

    let onClose: () -> Void
    let onFinish: () -> Void

    private var isNextDisabled: Bool {
        // Demo flow never hits planHours.
        if isDemoMode { return false }
        return currentStep == .planHours && !(0...1440).contains(minutesOutside)
    }

    private var isFinishStep: Bool {
        isDemoMode ? (currentStep == .preferences) : currentStep.isLast
    }

    private var title: String {
        if isDemoMode {
            switch currentStep {
            case .aboutYou: return "About You"
            case .preferences: return "Preferences"
            case .planHours: return "Plan hours"
            }
        }
        return currentStep.title
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $currentStep) {
                    if isDemoMode {
                        // Demo: reuse AboutYouStepView but hide name/age/weight.
                        DemoHobbiesEquipmentStepView(existingActivities: $existingActivities, existingEquipment: $existingEquipment)
                            .tag(UserInfoView.Step.aboutYou)

                        PreferencesStepView(environment: $environment, intensity: $intensity, tryNewPreference: $tryNewPreference, userLimitations: $userLimitations)
                            .tag(UserInfoView.Step.preferences)
                    } else {
                        AboutYouStepView(
                            name: $name,
                            age: $age,
                            weight: $weight,
                            existingActivities: $existingActivities,
                            existingEquipment: $existingEquipment
                        )
                        .tag(UserInfoView.Step.aboutYou)

                        PreferencesStepView(environment: $environment, intensity: $intensity, tryNewPreference: $tryNewPreference, userLimitations: $userLimitations)
                            .tag(UserInfoView.Step.preferences)

                        PlanHoursStepView(minutesOutside: $minutesOutside)
                            .tag(UserInfoView.Step.planHours)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.28), value: currentStep)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep.showsBack {
                        Button(action: { goBack() }) {
                            Text("Back")
                        }
                        .tint(.blue)
                    } else {
                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .tint(.blue)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if isFinishStep {
                            onFinish()
                        } else {
                            goNext()
                        }
                    }) {
                        Text(isFinishStep ? "Finish" : "Next")
                    }
                    .disabled(isNextDisabled)
                    .buttonStyle(.glassProminent)
                    .tint(.blue)
                }
            }
        }
        .onChange(of: currentStep) { old, new in
            if old == .aboutYou && new != .aboutYou {
                dismissKeyboard()
            }
        }
    }

    private func goNext() {
        if currentStep == .aboutYou { dismissKeyboard() }

        if isDemoMode {
            // Demo: aboutYou -> preferences only.
            if currentStep == .aboutYou {
                navigationDirection = 1
                withAnimation { currentStep = .preferences }
            }
            return
        }

        guard let next = UserInfoView.Step(rawValue: currentStep.rawValue + 1) else { return }
        navigationDirection = 1
        withAnimation { currentStep = next }
    }

    private func goBack() {
        if isDemoMode {
            // Demo: preferences -> aboutYou only.
            if currentStep == .preferences {
                navigationDirection = -1
                withAnimation { currentStep = .aboutYou }
            }
            return
        }

        guard let prev = UserInfoView.Step(rawValue: currentStep.rawValue - 1) else { return }
        navigationDirection = -1
        withAnimation { currentStep = prev }
    }

    // Dismiss keyboard helper
    private func dismissKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }

    // Demo-only step: only hobbies + equipment pickers.
    private struct DemoHobbiesEquipmentStepView: View {
        @Binding var existingActivities: Set<Activity>
        @Binding var existingEquipment: Set<Equipment>

        private let columns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]
        @State private var activitySearchText: String = ""
        @State private var equipmentSearchText: String = ""

        private var existingHobbiesLabel: String {
            existingActivities.isEmpty ? "Your existing hobbies" : "Your existing hobbies: \(existingActivities.count) added..."
        }

        private var existingEquipmentLabel: String {
            existingEquipment.isEmpty ? "Your equipment" : "Your equipment: \(existingEquipment.count) added..."
        }

        private var filteredActivities: [Activity] {
            let query = activitySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let base = Activity.allCases
            guard !query.isEmpty else { return base }
            return base.filter {
                $0.displayName.localizedCaseInsensitiveContains(query) ||
                $0.difficultyLevel.localizedCaseInsensitiveContains(query)
            }
        }

        private var filteredEquipment: [Equipment] {
            let query = equipmentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let base = Equipment.allCases
            guard !query.isEmpty else { return base }
            return base.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
        }

        var body: some View {
            Form {
                Section(header: Text("Hobbies & equipment")) {
                    NavigationLink(existingHobbiesLabel) {
                        Text("Your existing hobbies...")
                            .font(.title2)
                            .padding()
                            .fontWeight(.semibold)

                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(filteredActivities, id: \.self) { activity in
                                    Button {
                                        if existingActivities.contains(activity) {
                                            existingActivities.remove(activity)
                                        } else {
                                            existingActivities.insert(activity)
                                        }
                                    } label: {
                                        HStack(alignment: .center) {
                                            Image(systemName: activity.symbolName)
                                                .font(.title)
                                                .frame(width: 50, height: 100)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(activity.displayName)
                                                Text(activity.difficultyLevel)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            if existingActivities.contains(activity) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .foregroundColor(existingActivities.contains(activity) ? .white : .primary)
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(existingActivities.contains(activity) ? Color.blue : Color.gray.opacity(0.2), lineWidth: existingActivities.contains(activity) ? 2 : 1)
                                                .background(existingActivities.contains(activity) ? RoundedRectangle(cornerRadius: 10).fill(.blue) : RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                        }
                        .searchable(text: $activitySearchText, prompt: "Search activities")
                    }

                    NavigationLink(existingEquipmentLabel) {
                        Text("Equipments you have access")
                            .font(.title2)
                            .padding()
                            .fontWeight(.semibold)

                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(filteredEquipment, id: \.self) { equipment in
                                    Button {
                                        if existingEquipment.contains(equipment) {
                                            existingEquipment.remove(equipment)
                                        } else {
                                            existingEquipment.insert(equipment)
                                        }
                                    } label: {
                                        HStack(alignment: .center) {
                                            Image(systemName: equipment.symbolName)
                                                .font(.title)
                                                .frame(width: 50, height: 100)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(equipment.displayName)
                                                    .font(.body)
                                            }
                                            Spacer()
                                            if existingEquipment.contains(equipment) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .foregroundColor(existingEquipment.contains(equipment) ? .white : .primary)
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(existingEquipment.contains(equipment) ? Color.blue : Color.gray.opacity(0.2), lineWidth: existingEquipment.contains(equipment) ? 2 : 1)
                                                .background(existingEquipment.contains(equipment) ? RoundedRectangle(cornerRadius: 10).fill(.blue) : RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                        }
                        .searchable(text: $equipmentSearchText, prompt: "Search equipment")
                    }
                }
            }
        }
    }
    
    private struct PreferencesStepView: View {
        @Binding var environment: Theme
        @Binding var intensity: Int
        @Binding var tryNewPreference: TryNewLevel
        @Binding var userLimitations: Set<UserLimitation>
        
        @State private var isShowingLimitationPicker: Bool = false
        
        var body: some View {
            Form {
                Section("Your preferences") {
                    Picker("Environment", selection: $environment) {
                        ForEach(Theme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Intensity")
                            Spacer()
                            Text("\(intensity)/5")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack() {
                            ForEach(1...5, id: \.self) { level in
                                Spacer()
                                Button {
                                    withAnimation(.spring()) {
                                        intensity = level
                                    }
                                } label: {
                                    Image(systemName: level <= intensity ? "flame.fill" : "flame")
                                        .font(.system(size: level == intensity ? 22 : 18))
                                        .foregroundStyle(level <= intensity ? Color.white : Color.primary)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle()
                                                .fill(level <= intensity ? Color.blue : Color(.systemBackground))
                                                .shadow(color: level == intensity ? Color.black.opacity(0.15) : .clear, radius: 2, x: 0, y: 1)
                                                .overlay(
                                                    Circle()
                                                        .stroke(level == intensity ? Color.blue : Color.gray.opacity(0.2), lineWidth: level == intensity ? 0 : 1)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(level) out of 5 intensity")
                                .accessibilityAddTraits(level == intensity ? .isSelected : [])
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Picker("Try new activities", selection: $tryNewPreference) {
                        ForEach(TryNewLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }
                
                Section {
                    Button {
                        isShowingLimitationPicker = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Accessibility considerations")
                                    .foregroundStyle(.primary)
                                
                                if userLimitations.isEmpty {
                                    Text("None selected")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("\(userLimitations.count) selected")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Accessibility (Optional)")
                } footer: {
                    Text("Help Outivity recommend activities that match your needs and abilities. This information is kept private and only used to improve your experience.")
                }
            }
            .sheet(isPresented: $isShowingLimitationPicker) {
                LimitationPickerView(
                    selectedLimitations: $userLimitations,
                    title: "Accessibility Considerations"
                )
            }
        }
    }
    
    private struct PlanHoursStepView: View {
        @Binding var minutesOutside: Int
        
        var body: some View {
            Form {
                Section("Let's plan hours") {
                    Stepper(value: $minutesOutside, in: 0...1440, step: 15) {
                        HStack(alignment: .lastTextBaseline) {
                            Text("\(minutesOutside)").font(.title)
                            Text("minutes/day")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
            }
        }
    }
    
    //MARK: About you step
    private struct AboutYouStepView: View {
        @Binding var name: String
        @Binding var age: Int
        @Binding var weight: Int
        @Binding var existingActivities: Set<Activity>
        @Binding var existingEquipment: Set<Equipment>

        @FocusState private var isNameFocused: Bool
        @FocusState private var isWeightFocused: Bool

        private let columns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]
        
        // Search state for the chooser screens
        @State private var activitySearchText: String = ""
        @State private var equipmentSearchText: String = ""

        private var existingHobbiesLabel: String {
            if existingActivities.isEmpty {
                return "Your existing hobbies (Optional)"
            }
            return "Your existing hobbies: \(existingActivities.count) added..."
        }

        private var existingEquipmentLabel: String {
            if existingEquipment.isEmpty {
                return "Your equipment (Optional)"
            }
            return "Your equipment: \(existingEquipment.count) added..."
        }
        
        private var filteredActivities: [Activity] {
            let query = activitySearchText.trimmingCharacters(in: .whitespacesAndNewlines)

            let base = Activity.allCases

            guard !query.isEmpty else { return base }

            return base.filter {
                $0.displayName.localizedCaseInsensitiveContains(query) ||
                $0.difficultyLevel.localizedCaseInsensitiveContains(query)
            }
        }

        private var filteredEquipment: [Equipment] {
            let query = equipmentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

            let base = Equipment.allCases


            guard !query.isEmpty else { return base }

            return base.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
        }
        
        var body: some View {
            Form {
                Section(header: Text("About you")) {
                    TextField("Your name (optional)", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($isNameFocused)

                    Stepper(value: $age, in: 0...120) {
                        Text("Age: \(age)")
                    }

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Weight")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(weight) lb")
                                .font(.title2)
                                .onTapGesture {
                                    isWeightFocused = true
                                }
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Button {
                                if weight > 30 { weight -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)

                            Button {
                                if weight < 1000 { weight += 1 }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                        }
                    }


                    NavigationLink(existingHobbiesLabel) {
                        Text("Your existing hobbies...")
                            .font(.title2)
                            .padding()
                            .fontWeight(.semibold)
                        
                        ScrollView {
                            if filteredActivities.isEmpty {
                                ContentUnavailableView("No activities found", systemImage: "magnifyingglass")
                                    .padding(.top, 40)
                            } else {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(filteredActivities, id: \.self) { activity in
                                        Button {
                                            if existingActivities.contains(activity) {
                                                existingActivities.remove(activity)
                                            } else {
                                                existingActivities.insert(activity)
                                            }
                                        } label: {
                                            HStack(alignment: .center) {
                                                Image(systemName: activity.symbolName)
                                                    .font(.title)
                                                    .frame(width: 50, height: 100)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(activity.displayName)
                                                        .font(.body)
                                                    Text(activity.difficultyLevel)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                                
                                                if existingActivities.contains(activity) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .foregroundColor(existingActivities.contains(activity) ? .white : .primary)
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(existingActivities.contains(activity) ? Color.blue : Color.gray.opacity(0.2), lineWidth: existingActivities.contains(activity) ? 2 : 1)
                                                    .background(existingActivities.contains(activity) ? RoundedRectangle(cornerRadius: 10).fill(.blue) : RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding()
                            }
                        }
                        .searchable(text: $activitySearchText, prompt: "Search activities")
                    }
                    
                    NavigationLink(existingEquipmentLabel) {
                        Text("Equipments you have access")
                            .font(.title2)
                            .padding()
                            .fontWeight(.semibold)
                        
                        ScrollView {
                            if filteredEquipment.isEmpty {
                                ContentUnavailableView("No equipment found", systemImage: "magnifyingglass")
                                    .padding(.top, 40)
                            } else {
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(filteredEquipment, id: \.self) { equipment in
                                        Button {
                                            if existingEquipment.contains(equipment) {
                                                existingEquipment.remove(equipment)
                                            } else {
                                                existingEquipment.insert(equipment)
                                            }
                                        } label: {
                                            HStack(alignment: .center) {
                                                Image(systemName: equipment.symbolName)
                                                    .font(.title)
                                                    .frame(width: 50, height: 100)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(equipment.displayName)
                                                        .font(.body)
                                                }
                                                Spacer()
                                                
                                                if existingEquipment.contains(equipment) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .foregroundColor(existingEquipment.contains(equipment) ? .white : .primary)
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(existingEquipment.contains(equipment) ? Color.blue : Color.gray.opacity(0.2), lineWidth: existingEquipment.contains(equipment) ? 2 : 1)
                                                    .background(existingEquipment.contains(equipment) ? RoundedRectangle(cornerRadius: 10).fill(.blue) : RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding()
                            }
                        }
                        .searchable(text: $equipmentSearchText, prompt: "Search equipment")
                    }
                }
            }
        }
    }
}

#Preview {
    UserInfoView()
}
