//
//  SwiftUIView.swift
//  Outivity
//
//  Created by Wafiq on 1/5/26.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct BackPackView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var activeActionPackID: UUID? = nil
    @State private var packPendingDelete: BackPack? = nil
    @State private var showDeleteAlert = false
    @State private var isDeleteMode = false

    @Query(sort: \BackPack.createdAt, order: .reverse)
    private var backpacks: [BackPack]
    
    @Query private var allCustomActivities: [CustomActivity]

    @Binding private var showAddSheet: Bool

    init(showAddSheet: Binding<Bool> = .constant(false)) {
        _showAddSheet = showAddSheet
    }

    var body: some View {
        NavigationStack {
            ScrollView{
                VStack {
                    if backpacks.isEmpty {
                        Section{} footer: {
                            VStack(alignment: .center) {
                                
                                Image(systemName: "backpack.fill")
                                    .font(.system(size: 44))
                                    .padding(18)
                                    .background(Circle().fill(Color.secondary))
                                    .foregroundColor(.white)
                                
                                Text("No Backpacks yet")
                                    .font(.title)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.secondary)
                                    .multilineTextAlignment(.center)

                                Text("Tap \(Image(systemName: "plus")) to add your first BackPack.")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    } else {
                        ForEach(backpacks) { pack in
                            VStack {
                                VStack(spacing: 10) {

                                    Image(systemName: "backpack.fill")
                                        .foregroundStyle(pack.color)
                                        .font(.system(size: 75))
                                    Text(pack.name)
                                        .font(.title.bold())
                                }

                                Text("Created: \(pack.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.bottom)
                                
                                
                                if let identity = identityForPack(pack) {
                                    NavigationLink {
                                        ActivityDetailedView(identity: identity)
                                    } label: {
                                        ActivityCard(identity: identity)
                                            .glassEffect(.regular.interactive())
                                    }
                                    .buttonStyle(.plain)
                                }

                                VStack{
                                    Text("Quick look")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .center)

                                    if pack.equipment.isEmpty && pack.customEquipment.isEmpty {
                                        HStack {
                                            Text("No equipment for this BackPack")
                                                .multilineTextAlignment(.center)
                                                .frame(maxWidth: .infinity, alignment: .center)
                                                .foregroundStyle(.secondary)
                                                .padding(.bottom)
                                        }
                                        .padding(.horizontal)
                                    } else {
                                        ScrollView(.horizontal) {
                                            HStack(spacing: 10) {
                                                ForEach(pack.equipment) { equipment in
                                                    EquipmentChipView(
                                                        symbolName: equipment.symbolName,
                                                        title: equipment.displayName
                                                    )
                                                }

                                                ForEach(pack.customEquipment) { equipment in
                                                    EquipmentChipView(
                                                        symbolName: equipment.symbolName,
                                                        title: equipment.displayName
                                                    )
                                                }
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 6)
                                        }.mask(
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
                                        .scrollIndicators(.hidden)
                                    }
                                    
                                    NavigationLink {
                                        BackPackDetailedView(pack: pack)
                                    } label: {
                                        Text("Open BackPack")
                                            .padding()
                                    }
                                    .buttonStyle(.glassProminent)
                                    
                                }.padding()
                                
                            }
                            .padding()
                            .background(.quinary.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 38))
                            .onLongPressGesture(minimumDuration: 0.35) {
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                #endif
                                withAnimation(.bouncy(duration: 0.18)) {
                                    activeActionPackID = pack.id
                                }
                            }
                            
                            .overlay(alignment: .topLeading) {
                                if isDeleteMode || activeActionPackID == pack.id {
                                    Button {
                                        packPendingDelete = pack
                                        showDeleteAlert = true
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                            .font(.headline)
                                            .padding(12)
                                    }
                                    .glassEffect(.regular.interactive(), in: Circle())
                                    .offset(x: -12, y: -12)
                                }
                            }

                        }
                        .onDelete(perform: deleteBackpacks)
                    }
                }
                .padding()
                .padding()
                .navigationTitle("BackPack")
                .toolbar {
                    if !backpacks.isEmpty{
                        ToolbarItem(placement: .topBarTrailing) {
                            Button{
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isDeleteMode.toggle()
                                    if !isDeleteMode {
                                        activeActionPackID = nil
                                    }
                                }
                            }label: {
                                if isDeleteMode {
                                    Text("Done")
                                } else{
                                    Image(systemName: "square.and.pencil")
                                }
                            }
                        }
                    }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showAddSheet = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.title3)
                            }
                        }
                    
                }
                .sheet(isPresented: $showAddSheet) {
                    NavigationStack {
                        AddNewBackPack()
                    }
                }

            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !isDeleteMode && activeActionPackID != nil {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        activeActionPackID = nil
                    }
                }
            }
            .alert("Delete backpack?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let pack = packPendingDelete {
                        withAnimation {
                            modelContext.delete(pack)
                            packPendingDelete = nil
                            activeActionPackID = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    packPendingDelete = nil
                }
            } message: {
                Text("This BackPack will be permanently deleted.")
            }

        }
    }

    private func deleteBackpacks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(backpacks[index])
        }
    }

    private func identityForPack(_ pack: BackPack) -> ActivityIdentity? {
        if let customID = pack.customActivityID, let custom = allCustomActivities.first(where: { $0.id == customID }) {
            return ActivityIdentity(custom: custom)
        } else if let activity = pack.activity {
            return ActivityIdentity(activity: activity)
        }
        return nil
    }
}

private struct EquipmentChipView: View {
    let symbolName: String
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbolName)
                .font(.subheadline)
                .frame(width: 20)

            Text(title)
                .font(.subheadline)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}

struct BackPackDetailedView: View {
    let pack: BackPack

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Editing state
    @State private var isEditing: Bool = false
    @State private var showDeleteAlert: Bool = false

    // Editable copies
    @State private var editedName: String = ""
    @State private var editedDescription: String = ""
    @State private var editedColorRaw: String = BackPackColor.primary.rawValue
    @State private var editedActivityIdentity: ActivityIdentity? = nil
    @State private var editedEquipment: [Equipment] = []
    @State private var editedCustomEquipment: [CustomEquipment] = []

    // Sheets
    @State private var showEquipmentSheet = false

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    @Query private var allCustomActivities: [CustomActivity]

    private var descriptionText: String? {
        let t = (pack.backPackDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private var packIdentity: ActivityIdentity? {
        if let customID = pack.customActivityID, let custom = allCustomActivities.first(where: { $0.id == customID }) {
            return ActivityIdentity(custom: custom)
        } else if let activity = pack.activity {
            return ActivityIdentity(activity: activity)
        }
        return nil
    }

    var body: some View {
        ScrollView {
            Group {
                if isEditing {
                    editContent
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    detailContent
                        .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: isEditing)
        .sheet(isPresented: $showEquipmentSheet) {
            EquipmentPickerSheet(
                isPresented: $showEquipmentSheet,
                selectedEquipment: $editedEquipment,
                selectedCustomEquipment: $editedCustomEquipment,
                title: "Equipment",
                showsAddCustomEquipmentButton: true
            )
        }
        .navigationTitle("Backpack")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if isEditing {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                            saveEdits()
                        }
                    } else {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                            startEditing()
                        }
                    }
                } label: {
                    if isEditing {
                        Text("Done")
                    } else {
                        Image(systemName: "square.and.pencil")
                    }
                }
                .disabled(isEditing && editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("Delete backpack?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                modelContext.delete(pack)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This BackPack will be permanently deleted.")
        }
    }

    // MARK: - Read-only content
    private var detailContent: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "backpack.fill")
                    .font(.system(size: 150))
                    .foregroundStyle(pack.color)

                Text(pack.name)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text("Created: \(pack.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical)

            // About
            VStack(alignment: .leading, spacing: 10) {
                Text("About")
                    .font(.title3)
                    .fontWeight(.semibold)

                if let desc = descriptionText {
                    Text(desc)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .glassEffect(in: RoundedRectangle(cornerRadius: 38))
                } else {
                    HStack {
                        Text("No description")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding()
                    .glassEffect(in: RoundedRectangle(cornerRadius: 38))
                }
            }

            // Activity
            VStack(alignment: .leading, spacing: 10) {
                Text("Activity")
                    .font(.title3)
                    .fontWeight(.semibold)

                if let identity = packIdentity {
                    NavigationLink {
                        ActivityDetailedView(identity: identity)
                    } label: {
                        ActivityCard(identity: identity)
                            .glassEffect(.regular.interactive())
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack {
                        Text("No activity")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding()
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 38))
                }
            }

            // Equipment
            VStack {
                Text("Equipment")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.vertical)

                // Custom equipment
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Your equipment")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                    }

                    let list = pack.customEquipment
                    if list.isEmpty {
                        HStack {
                            Text("Nothing added yet")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }.padding(.bottom)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(list) { equipment in
                                EquipmentCardView(
                                    symbolName: equipment.symbolName,
                                    title: equipment.displayName
                                )
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                // Built-in equipment
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Built-in equipment")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                    }

                    let list = pack.equipment
                    if list.isEmpty {
                        HStack {
                            Text("Nothing added yet")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }.padding(.bottom)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(list) { equipment in
                                EquipmentCardView(
                                    symbolName: equipment.symbolName,
                                    title: equipment.displayName
                                )
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .padding()
    }

    // MARK: - Edit content
    private var editContent: some View {
        VStack(spacing: 20) {
            sectionCard {
                VStack(spacing: 12) {
                    Image(systemName: "backpack.fill")
                        .font(.system(size: 150))
                        .foregroundStyle(BackPackColor(rawValue: editedColorRaw)?.color ?? .white)

                    BackpackColorSelector(selectedColorRaw: $editedColorRaw)
                        .padding(.bottom, 4)

                    TextField("Backpack name", text: $editedName)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.words)
                        .padding()
                        .glassEffect()
                }
            }

            sectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Description")
                        .font(.title3).fontWeight(.semibold)
                    TextField("Description (Optional)", text: $editedDescription, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                        .padding()
                        .glassEffect(in: RoundedRectangle(cornerRadius: 24))
                }
            }

            sectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Activity")
                        .font(.title3).fontWeight(.semibold)
                    ActivityCardPicker(optional: $editedActivityIdentity, noneTitle: "No activity")
                }
            }

            sectionCard {
                VStack(spacing: 12) {
                    HStack {
                        Text("Equipment")
                            .font(.title3).fontWeight(.semibold)
                        Spacer()
                        Button { showEquipmentSheet = true } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.glassProminent)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        let builtIn = editedEquipment
                        if !builtIn.isEmpty {
                            Text("Selected Built-in Equipment")
                                .font(.subheadline)
                        }
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(builtIn) { equipment in
                                EquipmentCardView(symbolName: equipment.symbolName, title: equipment.displayName)
                            }
                        }

                        if !editedCustomEquipment.isEmpty {
                            Text("Selected Custom Equipment")
                                .font(.subheadline)
                        }
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(editedCustomEquipment) { equipment in
                                EquipmentCardView(symbolName: equipment.symbolName, title: equipment.displayName)
                            }
                        }
                    }
                }
            }

            sectionCard {
                VStack(alignment: .center, spacing: 10) {
                    Text("Danger zone")
                        .font(.headline)

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Spacer()
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete backpack")
                        }
                        .padding(.vertical, 6)
                        .foregroundStyle(.red)
                        Spacer()
                    }
                    .tint(.red)
                    .buttonStyle(.glass)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top)
        .padding(.bottom, 24)
        .onAppear {
            // Ensure edit fields reflect the latest data when entering edit mode via animation.
        }
    }

    // MARK: - Helpers
    private func sectionCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding()
            .glassEffect(in: RoundedRectangle(cornerRadius: 32))
    }

    private func startEditing() {
        editedName = pack.name
        editedDescription = pack.backPackDescription ?? ""
        editedColorRaw = pack.colorEnum?.rawValue ?? BackPackColor.primary.rawValue
        editedActivityIdentity = packIdentity
        editedEquipment = pack.equipment
        editedCustomEquipment = pack.customEquipment
        isEditing = true
    }

    private func saveEdits() {
        let cleanName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        pack.name = cleanName

        let desc = editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        pack.backPackDescription = desc.isEmpty ? nil : desc

        pack.colorRaw = editedColorRaw

        if let identity = editedActivityIdentity {
            switch identity.kind {
            case .builtIn(let a):
                pack.activity = a
                pack.customActivityID = nil
            case .custom(let uuid):
                pack.activity = nil
                pack.customActivityID = uuid
            }
        } else {
            pack.activity = nil
            pack.customActivityID = nil
        }

        pack.equipment = editedEquipment
        pack.customEquipment = editedCustomEquipment

        do {
            try modelContext.save()
            isEditing = false
        } catch {
            // Keep behavior simple: remain in edit mode if save fails.
        }
    }
}


struct AddNewBackPack: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Draft State
    @State private var name: String = ""
    @State private var bacPackDescription: String = ""
    @State private var selectedColorRaw: String = BackPackColor.primary.rawValue

    @State private var selectedActivityIdentity: ActivityIdentity? = nil

    @State private var selectedEquipment: [Equipment] = []
    @State private var selectedCustomEquipment: [CustomEquipment] = []
    @State private var showEquipmentPickerSheet = false

    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case name, description }

    // MARK: - Wizard
    private enum Step: Int, CaseIterable, Identifiable, Hashable {
        case basics, activity, equipment
        var id: Int { rawValue }

        var title: String {
            switch self {
            case .basics: return "Basics"
            case .activity: return "Activity"
            case .equipment: return "Equipment"
            }
        }

        var systemImage: String {
            switch self {
            case .basics: return "sparkles"
            case .activity: return "figure.walk"
            case .equipment: return "backpack"
            }
        }
    }

    @State private var step: Step? = .basics
    private var currentStep: Step { step ?? .basics }
    private var stepIndex: Int { currentStep.rawValue }

    private var canAdvance: Bool {
        // Require name for all steps (same as your custom activity wizard)
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isFirstStep: Bool { currentStep == .basics }
    private var isLastStep: Bool { currentStep == .equipment }

    private var hasValidName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canProceed: Bool { hasValidName }
    
    // MARK: - Preview helpers
    private var selectedColor: Color {
        BackPackColor(rawValue: selectedColorRaw)?.color ?? .white
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                previewHeader
                stepHeader

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        basicsStep
                            .containerRelativeFrame(.horizontal)
                            .id(Step.basics)

                        activityStep
                            .containerRelativeFrame(.horizontal)
                            .id(Step.activity)

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
        .navigationTitle("New Backpack")
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Leading chevron: dismiss on first step, otherwise go back
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if isFirstStep {
                        dismiss()
                    } else {
                        goBack()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel(isFirstStep ? "Close" : "Back")
            }

            // Next or Finish
            ToolbarItem(placement: .topBarTrailing) {
                Button(isLastStep ? "Finish" : "Next") {
                    if isLastStep {
                        save()
                    } else {
                        goNext()
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(!canProceed)
            }
        }

        .sheet(isPresented: $showEquipmentPickerSheet) {
            EquipmentPickerSheet(
                isPresented: $showEquipmentPickerSheet,
                selectedEquipment: $selectedEquipment,
                selectedCustomEquipment: $selectedCustomEquipment,
                title: "Equipment",
                showsAddCustomEquipmentButton: true
            )
        }
    }

    // MARK: - Header UI

    private var previewHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your backpack preview")
                .fontWeight(.bold)

            VStack(spacing: 10) {
                Image(systemName: "backpack.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(selectedColor)

                Text(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Backpack" : name)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                if !bacPackDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(bacPackDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .glassEffect(in: RoundedRectangle(cornerRadius: 32))
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
        .animation(.easeInOut(duration: 0.18), value: currentStep)
    }

    // MARK: - Steps

    private var basicsStep: some View {
        VStack(spacing: 16) {
            sectionCard {
                VStack(spacing: 12) {
                    Image(systemName: "backpack.fill")
                        .font(.system(size: 110))
                        .foregroundStyle(selectedColor)

                    BackpackColorSelector(selectedColorRaw: $selectedColorRaw)
                        .frame(height: 60)

                    TextField("Backpack name", text: $name)
                        .textInputAutocapitalization(.words)
                        .padding()
                        .glassEffect()
                        .focused($focusedField, equals: .name)
                }
            }

            sectionCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)

                    TextField("Description (Optional)", text: $bacPackDescription, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                        .padding()
                        .glassEffect(in: RoundedRectangle(cornerRadius: 24))
                        .focused($focusedField, equals: .description)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
    }

    private var activityStep: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Add an activity (Optional)")
                    .font(.headline)

            }
            
            ActivityCardPicker(optional: $selectedActivityIdentity, noneTitle: "No activity")

            Spacer(minLength: 0)
        }
        .padding()
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
                            builtIn: selectedEquipment,
                            custom: selectedCustomEquipment
                        )
                    }
                }

                Spacer(minLength: 0)
            }
            .padding()
        }
    }


    private func reviewRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
    }

    // MARK: - Shared bits

    private func sectionCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding()
            .glassEffect(in: RoundedRectangle(cornerRadius: 32))
    }

    private struct EquipmentSelectionPreview: View {
        let builtIn: [Equipment]
        let custom: [CustomEquipment]

        private let columns: [GridItem] = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                if !builtIn.isEmpty {
                    Text("Selected Built-in Equipment").font(.subheadline)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(builtIn) { equipment in
                            EquipmentCardView(symbolName: equipment.symbolName, title: equipment.displayName)
                        }
                    }
                }

                if !custom.isEmpty {
                    Text("Selected Custom Equipment").font(.subheadline)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(custom) { equipment in
                            EquipmentCardView(symbolName: equipment.symbolName, title: equipment.displayName)
                        }
                    }
                }

                if builtIn.isEmpty && custom.isEmpty {
                    Text("No equipment selected yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Wizard navigation

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

    // MARK: - Save

    @MainActor
    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let desc = bacPackDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedDescription: String? = desc.isEmpty ? nil : desc

        var act: Activity? = nil
        var customID: UUID? = nil

        if let identity = selectedActivityIdentity {
            switch identity.kind {
            case .builtIn(let a): act = a
            case .custom(let uuid): customID = uuid
            }
        }

        let pack = BackPack(
            name: cleanName,
            colorRaw: selectedColorRaw,
            createdAt: .now,
            activity: act,
            customActivityID: customID,
            equipment: selectedEquipment,
            customEquipment: selectedCustomEquipment,
            backPackDescription: cleanedDescription
        )

        modelContext.insert(pack)
        dismiss()
    }
}


private struct BackpackColorSelector: View {
    @Binding var selectedColorRaw: String

    private let swatchSize: CGFloat = 48
    private let spacing: CGFloat = 10

    var body: some View {
        GeometryReader { barGeo in
            let barSize = barGeo.size

            // Match ActivityPhotoDetailView's indicator pattern by using a String? binding.
            let indicatorID: Binding<String?> = Binding(
                get: { selectedColorRaw },
                set: { val in
                    guard let val else { return }
                    // Avoid redundant writes that can cause animation jitter.
                    if selectedColorRaw != val {
                        selectedColorRaw = val
                      }
                    }
            )

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: spacing) {
                        ForEach(BackPackColor.allCases, id: \.rawValue) { colorCase in
                            RoundedRectangle(cornerRadius: 10)
                                .fill(colorCase.color)
                                .frame(width: swatchSize, height: swatchSize)
                                .scaleEffect(0.97)
                                .contentShape(.rect)
                                .onTapGesture {
                                    // Only animate on direct user taps.
                                    withAnimation(.easeInOut(duration: 0.28)) {
                                        selectedColorRaw = colorCase.rawValue
                                    }
                                }
                                .id(colorCase.rawValue)
                        }
                    }
                    .padding(.vertical, 6)
                    .scrollTargetLayout()
                }
                .safeAreaPadding(.horizontal, (barSize.width - swatchSize) / 2)
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
                        .frame(width: swatchSize, height: swatchSize)
                        .allowsHitTesting(false)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: indicatorID)
                .scrollIndicators(.hidden)
                .onAppear {
                    // Center current selection when shown.
                    DispatchQueue.main.async {
                        proxy.scrollTo(selectedColorRaw, anchor: .center)
                    }
                }
                .onChange(of: barSize) {
                    // Re-center on layout changes (rotation, sheet resizing).
                    if !selectedColorRaw.isEmpty {
                        proxy.scrollTo(selectedColorRaw, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 60)
    }
}

#Preview("Backpacks – seeded") {
    BackPackView()
        .modelContainer(BackPackPreviewData.container)
}

// MARK: - Preview data

enum BackPackPreviewData {
    @MainActor static var container: ModelContainer = {
        do {
            // Include ALL @Model types that appear in your model graph.
            // BackPack has a relationship to CustomEquipment, so it must be in the schema.
            let schema = Schema([
                BackPack.self,
                CustomEquipment.self
            ])

            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: config)

            let context = container.mainContext

            // Seed a few backpacks
            let packs: [BackPack] = [
                BackPack(
                    name: "Day Hike Kit",
                    colorRaw: BackPackColor.teal.rawValue,
                    createdAt: .now.addingTimeInterval(-60 * 60 * 24 * 1),
                    activity: .hiking,
                    equipment: [.firstAidKit]
                ),
                BackPack(
                    name: "Travel Essentials",
                    colorRaw: BackPackColor.indigo.rawValue,
                    createdAt: .now.addingTimeInterval(-60 * 60 * 24 * 10),
                    activity: nil,
                    equipment: []
                )
            ]

            packs.forEach { context.insert($0) }
            try? context.save()

            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()
}
