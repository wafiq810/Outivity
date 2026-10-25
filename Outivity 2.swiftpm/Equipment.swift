import Foundation
import SwiftUI
import SwiftData

public enum Equipment: String, CaseIterable, Codable, Identifiable {
    public var id: String { rawValue }
    // Basic
    case comfyShoes = "Comfy shoes"
    case waterBottle = "Water bottle"
    case sunscreen = "Sunscreen"
    case hat = "Hat"

    // Water gear
    case swimsuit = "Swimsuit"
    case towel = "Towel"
    case snorkelMask = "Snorkel mask"
    case fins = "Fins"
    case surfboard = "Surfboard"
    case paddleboard = "Paddleboard"
    case kayak = "Kayak"
    case canoe = "Canoe"
    case lifeJacket = "Life jacket"
    case fishingRod = "Fishing rod"

    // Camping / outdoor
    case tent = "Tent"
    case sleepingBag = "Sleeping bag"
    case flashlight = "Flashlight"
    case bugSpray = "Bug spray"
    case firstAidKit = "First aid kit"

    // Winter
    case skates = "Ice skates"
    case skis = "Skis"
    case snowboard = "Snowboard"
    case winterJacket = "Winter jacket"
    case gloves = "Gloves"

    // Team sports
    case soccerBall = "Soccer ball"
    case basketball = "Basketball"
    case tennisRacket = "Tennis racket"
    case volleyball = "Volleyball"
    case badmintonRacket = "Badminton racket"
    case baseballGlove = "Baseball glove"
    case cricketBat = "Cricket bat"

    // Misc
    case camera = "Camera"

    /// Human-readable display name (kept for future localization)
    public var displayName: String { rawValue }

    /// SF Symbol name for a compact icon in lists/cards
    public var symbolName: String {
        switch self {
        // Basic
        case .comfyShoes: return "shoe.2"
        case .waterBottle: return "drop.fill"
        case .sunscreen: return "sun.max"
        case .hat: return "hat.cap"

        // Water gear
        case .swimsuit: return "figure.pool.swim"
        case .towel: return "tshirt"
        case .snorkelMask: return "bubbles.and.sparkles"
        case .fins: return "triangle"
        case .surfboard: return "figure.surfing"
        case .paddleboard: return "figure.stand"
        case .kayak: return "drop"
        case .canoe: return "sailboat"
        case .lifeJacket: return "lifepreserver"
        case .fishingRod: return "figure.fishing"

        // Camping / outdoor
        case .tent: return "tent"
        case .sleepingBag: return "bed.double"
        case .flashlight: return "flashlight.off.fill"
        case .bugSpray: return "ant"
        case .firstAidKit: return "cross.case.fill"

        // Winter
        case .skates: return "figure.ice.skating"
        case .skis: return "figure.skiing.downhill"
        case .snowboard: return "figure.snowboarding"
        case .winterJacket: return "wind"
        case .gloves: return "hand.raised"

        // Team sports
        case .soccerBall: return "soccerball"
        case .basketball: return "basketball"
        case .tennisRacket: return "tennisball"
        case .volleyball: return "volleyball"
        case .badmintonRacket: return "figure.badminton"
        case .baseballGlove: return "baseball"
        case .cricketBat: return "figure.cricket"

        // Misc
        case .camera: return "camera"
        }
    }
}

// MARK: - Equipment UI

/// A simple card used across the app to display both built built-in and custom equipment.
public struct EquipmentCardView: View {
    public let symbolName: String
    public let title: String

    public init(symbolName: String, title: String) {
        self.symbolName = symbolName
        self.title = title
    }

    public var body: some View {
        HStack(alignment: .center) {
            Image(systemName: symbolName)
                .font(.title)
                .frame(width: 50, height: 100)

            Text(title)
                .font(.body)

            Spacer()
        }
        .foregroundColor(.primary)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2))
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}

/// Grid-based picker content that includes both custom equipment and built-in equipment.
/// Meant to be presented inside a `NavigationStack` / `.sheet`.
public struct EquipmentPickerView: View {
    @Binding private var selectedEquipment: [Equipment]
    @Binding private var selectedCustomEquipment: [CustomEquipment]
    @Binding private var searchText: String

    private let showsAddCustomEquipmentButton: Bool

    @State private var showAddCustomEquipment = false

    @Query(sort: [SortDescriptor(\CustomEquipment.createdAt, order: .reverse)])
    private var allCustomEquipment: [CustomEquipment]

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    public init(
        selectedEquipment: Binding<[Equipment]>,
        selectedCustomEquipment: Binding<[CustomEquipment]>,
        searchText: Binding<String>,
        showsAddCustomEquipmentButton: Bool = true
    ) {
        _selectedEquipment = selectedEquipment
        _selectedCustomEquipment = selectedCustomEquipment
        _searchText = searchText
        self.showsAddCustomEquipmentButton = showsAddCustomEquipmentButton
    }

    private var normalizedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var filteredEquipment: [Equipment] {
        let q = normalizedQuery
        if q.isEmpty { return Equipment.allCases }
        return Equipment.allCases.filter { $0.displayName.lowercased().contains(q) }
    }

    private var filteredCustomEquipment: [CustomEquipment] {
        let q = normalizedQuery
        guard !q.isEmpty else { return allCustomEquipment }
        return allCustomEquipment.filter { $0.displayName.lowercased().contains(q) }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Custom equipment")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Spacer()

                        if showsAddCustomEquipmentButton {
                            Button {
                                showAddCustomEquipment = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.glass)
                            .sheet(isPresented: $showAddCustomEquipment) {
                                AddCustomEquipmentView()
                            }
                        }
                    }

                    if filteredCustomEquipment.isEmpty {
                        ContentUnavailableView("No custom equipment yet", systemImage: "magnifyingglass")
                            .padding(.top, 4)
                        Text(showsAddCustomEquipmentButton ? "Tap + to add a custom equipment." : "No custom equipment available.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredCustomEquipment) { equipment in
                                customEquipmentRow(for: equipment)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Built-in equipment")
                        .font(.title3)
                        .fontWeight(.semibold)

                    if filteredEquipment.isEmpty {
                        ContentUnavailableView("No equipment found", systemImage: "magnifyingglass")
                            .padding(.top, 4)
                        Text("Try another keyword above.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredEquipment, id: \.self) { equipment in
                                builtInEquipmentRow(for: equipment)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Equipment")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search equipment")
    }

    private func customEquipmentRow(for equipment: CustomEquipment) -> some View {
        let isSelected = selectedCustomEquipment.contains(where: { $0.id == equipment.id })
        return Button {
            toggle(equipment)
        } label: {
            HStack(alignment: .center) {
                Image(systemName: equipment.symbolName)
                    .font(.title)
                    .frame(width: 50, height: 100)

                Text(equipment.displayName)
                    .font(.body)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.blue : Color.gray.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
                    .background(
                        isSelected
                        ? RoundedRectangle(cornerRadius: 10).fill(.blue)
                        : RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground))
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func builtInEquipmentRow(for equipment: Equipment) -> some View {
        let isSelected = selectedEquipment.contains(equipment)
        return Button {
            toggle(equipment)
        } label: {
            HStack(alignment: .center) {
                Image(systemName: equipment.symbolName)
                    .font(.title)
                    .frame(width: 50, height: 100)

                Text(equipment.displayName)
                    .font(.body)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.blue : Color.gray.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
                    .background(
                        isSelected
                        ? RoundedRectangle(cornerRadius: 10).fill(.blue)
                        : RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground))
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ equipment: Equipment) {
        if let idx = selectedEquipment.firstIndex(of: equipment) {
            selectedEquipment.remove(at: idx)
        } else {
            selectedEquipment.append(equipment)
            selectedEquipment.sort { $0.displayName < $1.displayName }
        }
    }

    private func toggle(_ equipment: CustomEquipment) {
        if let idx = selectedCustomEquipment.firstIndex(where: { $0.id == equipment.id }) {
            selectedCustomEquipment.remove(at: idx)
        } else {
            selectedCustomEquipment.append(equipment)
            selectedCustomEquipment.sort { $0.displayName < $1.displayName }
        }
    }
}

/// A reusable sheet wrapper for picking equipment.
/// Owns the NavigationStack and Done button, and clears search on dismiss.
public struct EquipmentPickerSheet: View {
    @Binding private var isPresented: Bool
    @Binding private var selectedEquipment: [Equipment]
    @Binding private var selectedCustomEquipment: [CustomEquipment]

    private let title: String
    private let showsAddCustomEquipmentButton: Bool

    @State private var searchText: String = ""

    public init(
        isPresented: Binding<Bool>,
        selectedEquipment: Binding<[Equipment]>,
        selectedCustomEquipment: Binding<[CustomEquipment]>,
        title: String = "Equipment",
        showsAddCustomEquipmentButton: Bool = true
    ) {
        _isPresented = isPresented
        _selectedEquipment = selectedEquipment
        _selectedCustomEquipment = selectedCustomEquipment
        self.title = title
        self.showsAddCustomEquipmentButton = showsAddCustomEquipmentButton
    }

    public var body: some View {
        NavigationStack {
            EquipmentPickerView(
                selectedEquipment: $selectedEquipment,
                selectedCustomEquipment: $selectedCustomEquipment,
                searchText: $searchText,
                showsAddCustomEquipmentButton: showsAddCustomEquipmentButton
            )
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
        }
        .onChange(of: isPresented) { _, showing in
            if !showing { searchText = "" }
        }
    }
}

// MARK: - Binding helpers

public extension Binding where Value == [String] {

    func asEquipmentSelection() -> Binding<[Equipment]> {
        Binding<[Equipment]>(
            get: {
                self.wrappedValue.compactMap { Equipment(rawValue: $0) }
            },
            set: { newValue in
                self.wrappedValue = newValue.map { $0.rawValue }
            }
        )
    }
}
