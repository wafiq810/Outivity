//
//  SwiftUIView.swift
//  Outivity-pretest
//
//  Created by Wafiq on 12/27/25.
//

import SwiftUI
import SwiftData

struct UserSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Editable fields
    @State private var name: String = ""
    @State private var age: Int = 18
    @State private var weight: Int = 170
    @State private var existingActivities: Set<Activity> = []
    @State private var existingEquipment: Set<Equipment> = []
    @State private var minutesOutside: Int = 60
    @State private var environment: Theme = .other
    @State private var intensity: Int = 3
    @State private var tryNewPreference: TryNewLevel = .onlyRelated
    @State private var userLimitations: Set<UserLimitation> = []
    @State private var preferredUnits: PreferredUnits = .imperial

    @State private var didLoad: Bool = false
    
    // Limitation picker presentation
    @State private var isShowingLimitationPicker: Bool = false

    // Search within pickers (match onboarding)
    @State private var activitySearchText: String = ""
    @State private var equipmentSearchText: String = ""

    private let columns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]

    private var activitiesLabel: String {
        existingActivities.isEmpty
        ? "Your existing hobbies (Optional)"
        : "Your existing hobbies: \(existingActivities.count) saved"
    }

    private var equipmentLabel: String {
        existingEquipment.isEmpty
        ? "Your equipment (Optional)"
        : "Your equipment: \(existingEquipment.count) saved"
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
            Section("Profile") {
                TextField("Name (optional)", text: $name)
                    .textInputAutocapitalization(.words)

                Stepper(value: $age, in: 0...120) {
                    Text("Age: \(age)")
                }

                HStack {
                    Text("Weight")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper(value: $weight, in: 30...1000, step: 1) {
                        Text(UnitsFormatter.weightString(pounds: weight, units: preferredUnits))
                    }
                    .frame(minWidth: 120)
                }
            }

            Section("Activities & equipment") {
                // Activities grid (same design as UserInfoView)
                NavigationLink(activitiesLabel) {
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
                                        toggleActivity(activity)
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

                // Equipment grid (same design as UserInfoView)
                NavigationLink(equipmentLabel) {
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
                                        toggleEquipment(equipment)
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

            Section("Preferences") {
                Picker("Environment", selection: $environment) {
                    ForEach(Theme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }

                Stepper(value: $intensity, in: 1...5) {
                    Text("Intensity: \(intensity)")
                }

                Picker("Try new activities", selection: $tryNewPreference) {
                    ForEach(TryNewLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }

                Picker("Units", selection: $preferredUnits) {
                    ForEach(PreferredUnits.allCases) { units in
                        Text(units.displayName).tag(units)
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
                Text("Accessibility")
            } footer: {
                Text("Specify any limitations to help Outivity recommend appropriate activities. This information is kept private.")
            }

            Section("Plan") {
                Stepper(value: $minutesOutside, in: 0...1440, step: 5) {
                    Text("Minutes outside per day: \(minutesOutside)")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            load()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { save() }
                    .buttonStyle(.glassProminent)
            }
        }
        .sheet(isPresented: $isShowingLimitationPicker) {
            LimitationPickerView(
                selectedLimitations: $userLimitations,
                title: "Accessibility Considerations"
            )
        }
        .sheet(isPresented: $isShowingLimitationPicker) {
            LimitationPickerView(
                selectedLimitations: $userLimitations,
                title: "Accessibility Considerations"
            )
        }
    }

    private func load() {
        UserInfoStore.ensureSingleInstance(in: modelContext)
        let userInfo = UserInfoStore.fetchOrCreate(in: modelContext)

        name = userInfo.name ?? ""
        age = userInfo.age
        weight = userInfo.weight
        existingActivities = Set(userInfo.existingActivities)
        existingEquipment = Set(userInfo.existingEquipment)
        minutesOutside = userInfo.minutesOutside
        environment = userInfo.environment
        intensity = userInfo.intensity
        tryNewPreference = userInfo.tryNewPreference
        userLimitations = Set(userInfo.userLimitations)
        existingActivities = Set(userInfo.existingActivities)
        existingEquipment = Set(userInfo.existingEquipment)
        minutesOutside = userInfo.minutesOutside
        environment = userInfo.environment
        intensity = userInfo.intensity
        tryNewPreference = userInfo.tryNewPreference
        userLimitations = Set(userInfo.userLimitations)
        existingActivities = Set(userInfo.existingActivities)
        existingEquipment = Set(userInfo.existingEquipment)
        minutesOutside = userInfo.minutesOutside
        environment = userInfo.environment
        intensity = userInfo.intensity
        tryNewPreference = userInfo.tryNewPreference
        preferredUnits = userInfo.preferredUnits
    }

    private func save() {
        let userInfo = UserInfoStore.fetchOrCreate(in: modelContext)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        userInfo.name = trimmedName.isEmpty ? nil : trimmedName
        userInfo.age = age
        userInfo.weight = max(30, min(1000, weight))
        userInfo.existingActivities = Array(existingActivities)
        userInfo.existingEquipment = Array(existingEquipment)
        userInfo.minutesOutside = max(0, min(1440, minutesOutside))
        userInfo.environment = environment
        userInfo.intensity = intensity
        userInfo.tryNewPreference = tryNewPreference
        userInfo.userLimitations = Array(userLimitations)
        userInfo.preferredUnits = preferredUnits
        // Mark the time of this preferences change so history can be dampened.
        userInfo.preferencesLastChangedAt = Date()

        try? modelContext.save()
        dismiss()
    }

    private func toggleActivity(_ activity: Activity) {
        if existingActivities.contains(activity) {
            existingActivities.remove(activity)
        } else {
            existingActivities.insert(activity)
        }
    }

    private func toggleEquipment(_ equipment: Equipment) {
        if existingEquipment.contains(equipment) {
            existingEquipment.remove(equipment)
        } else {
            existingEquipment.insert(equipment)
        }
    }
}
