//
//  CustomEquipmentView.swift
//  Outivity
//
//  Created by Wafiq on 1/7/26.
//
import SwiftUI
import SwiftData

struct CustomEquipmentView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: [SortDescriptor(\CustomEquipment.createdAt, order: .reverse)]) private var customEquipment: [CustomEquipment]

    @State private var showingAddSheet = false
    @State private var selectedEquipment: CustomEquipment?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        NavigationStack {
            if customEquipment.isEmpty {
                Section{} footer: {
                    VStack(alignment: .center) {
                        
                        Image(systemName: "plus.rectangle.fill")
                            .font(.system(size: 44))
                            .padding(18)
                            .background(Circle().fill(Color.secondary))
                            .foregroundColor(.white)
                        
                        Text("No custom equipment yet")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Tap \(Image(systemName: "plus")) to add your first custom equipment.")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(customEquipment) { equipment in
                            NavigationLink {
                                EditCustomEquipmentView(equipment: equipment)
                            } label: {
                                EquipmentListCard(equipment: equipment)
                                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 38))

                            }
                            .contextMenu {
                                NavigationLink {
                                    EditCustomEquipmentView(equipment: equipment)
                                } label: {
                                    Label("Edit", systemImage: "square.and.pencil")

                                }

                                Button(role: .destructive) {
                                    withAnimation{
                                        deleteEquipment(equipment)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                    
                }

            }
        }
        .navigationTitle("Custom Equipment")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAddSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddCustomEquipmentView()
        }
    }
    private func deleteEquipment(_ equipment: CustomEquipment) {
        modelContext.delete(equipment)
        try? modelContext.save()
    }

    private func deleteEquipment(at indices: IndexSet) {
        for index in indices {
            let equipment = customEquipment[index]
            CustomEquipmentStore.delete(equipment, in: modelContext)
        }
    }
}
struct EquipmentListCard: View {
    let equipment: CustomEquipment
    
    var body: some View {
        VStack {
            Image(systemName: equipment.symbolName)
                .font(.system(size: 45))
                .foregroundColor(.blue)
                .padding()
            VStack(alignment: .leading, spacing: 2) {
                Text(equipment.displayName)
                    .foregroundStyle(Color.primary)
                    .font(.body)

            }.padding()

        }
        .frame(maxWidth: .infinity)
    }
}

struct EmptyEquipmentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "backpack")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Custom Equipment")
                .font(.headline)
            
            Text("Add equipment to get started")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct EditCustomEquipmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let equipment: CustomEquipment
    @Query private var allEquipment: [CustomEquipment]

    @State private var equipmentName: String = ""
    @State private var selectedSymbol: String = "ellipsis.circle"
    @State private var showingSymbolPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 39) {

                    // Icon preview + change button (matches Add view)
                    VStack {
                        Image(systemName: selectedSymbol)
                            .font(.system(size: 127))
                            .foregroundColor(.blue)
                            .frame(width: 40, alignment: .center)

                        Button(action: { showingSymbolPicker = true }) {
                            Text("Change Icon")
                                .foregroundColor(Color.primary)
                                .padding()
                        }
                        .buttonStyle(.glass)
                    }

                    // Name entry (matches Add view)
                    VStack {
                        Text("About your equipment")
                            .font(.title3.bold())

                        TextField("Enter name", text: $equipmentName)
                            .padding()
                            .glassEffect()
                    }

                    // Info block (matches Add view)
                    VStack {
                        Text("Customising Your Equipment")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)

                        Text("You can use this equipment to plan your BackPacks. Customize to your liking for an efficient packing.")
                            .multilineTextAlignment(.center)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .padding()
            }
            .navigationTitle("Edit Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEquipment()
                    }
                    .disabled(equipmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.glassProminent)
                }
            }
            .sheet(isPresented: $showingSymbolPicker) {
                SymbolPickerView(selectedSymbol: $selectedSymbol)
            }
            .alert("Cannot Save", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                equipmentName = equipment.displayName
                // If symbolName is optional in your model, use: equipment.symbolName ?? "ellipsis.circle"
                selectedSymbol = equipment.symbolName
            }
        }
    }

    private func saveEquipment() {
        let cleanName = equipmentName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            errorMessage = "Equipment name cannot be empty"
            showingError = true
            return
        }

        // Check if another equipment has the same name and symbol (excluding current)
        if allEquipment.contains(where: {
            $0.id != equipment.id &&
            $0.displayName == cleanName &&
            $0.symbolName == selectedSymbol
        }) {
            errorMessage = "Equipment with this name and symbol already exists"
            showingError = true
            return
        }

        CustomEquipmentStore.update(
            equipment,
            displayName: cleanName,
            symbolName: selectedSymbol,
            in: modelContext
        )

        dismiss()
    }
}



// MARK: - Symbol for custom equipment
struct SymbolPickerView: View {
    @Binding var selectedSymbol: String
    @Environment(\.dismiss) var dismiss
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(OutivitySymbol.availableSymbols, id: \.name) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.name)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(category.symbols, id: \.self) { symbol in
                                    SymbolCell(
                                        symbol: symbol,
                                        isSelected: selectedSymbol == symbol,
                                        action: {
                                            selectedSymbol = symbol
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Select Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }
}

struct SymbolCell: View {
    let symbol: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .blue)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

public struct AddCustomEquipmentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    @State private var equipmentName: String = ""
    @State private var selectedSymbol: String = "ellipsis.circle"
    @State private var showingSymbolPicker = false
    
    public var body: some View {
        NavigationStack {
            ScrollView{
                VStack(spacing: 39) {
                        VStack {
                            Image(systemName: selectedSymbol)
                                .font(.system(size: 127))
                                .foregroundColor(.blue)
                                .frame(width: 40, alignment: .center)

                            Button(action: { showingSymbolPicker = true }) {
                                Text("Change Icon")
                                    .foregroundColor(Color.primary)
                                    .padding()
                            }.buttonStyle(.glass)
                        }
                    VStack{
                        Text("About your equipment")
                            .font(.title3.bold())
                        TextField("Enter name", text: $equipmentName)
                            .padding()
                            .glassEffect()
                    }
                    
                    VStack{
                        Text("Customising Your Equipment")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                        Text("You can use this equipment to plan your BackPacks. Customize to your liking for an efficient packing.")
                            .multilineTextAlignment(.center)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }.padding()
                    .padding()
                .navigationTitle("Add Equipment")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add") {
                            addEquipment()
                        }
                        .disabled(equipmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.glassProminent)

                        
                    }
                }
                .sheet(isPresented: $showingSymbolPicker) {
                    SymbolPickerView(selectedSymbol: $selectedSymbol)
                }
            }
        }
    }
    
    private func addEquipment() {
        if CustomEquipmentStore.create(
            displayName: equipmentName,
            symbolName: selectedSymbol,
            in: modelContext
        ) != nil {
            dismiss()
        }
    }
}

enum OutivitySymbol {
    static let availableSymbols: [SymbolCategory] = [
        .init(name: "Basic", symbols: [
            "shoe.2", "sun.max", "moon.stars", "cloud", "umbrella",
            "backpack", "bag", "briefcase", "figure.walk", "figure.stand",
            "figure.run", "bicycle", "car", "bus", "tram", "airplane",
            "figure.hiking", "map", "location.circle", "flag"
        ]),
        .init(name: "Water", symbols: [
            "figure.pool.swim", "drop", "water.waves", "sailboat", "ferry",
            "figure.surfing", "figure.rower", "lifepreserver", "fish",
            "figure.fishing", "figure.open.water.swim", "figure.sailing",
            "beach.umbrella", "tropicalstorm",
            "rainbow", "cloud.rain", "cloud.heavyrain"
        ]),
        .init(name: "Camping & Outdoor", symbols: [
            "tent", "tree", "leaf", "flame",
            "binoculars", "flashlight.on.fill", "mountain.2", "camera",
            "map.fill", "figure.hiking",
            "figure.climbing", "figure.archery", "figure.hunting",
            "pawprint", "moonrise", "sunrise", "sunset"
        ]),
        .init(name: "Winter", symbols: [
            "snowflake", "wind", "thermometer", "cloud.snow",
            "figure.skiing.downhill", "figure.snowboarding",
            "figure.ice.skating", "figure.fall"
        ]),
        .init(name: "Sports & Fitness", symbols: [
            "soccerball", "basketball", "tennisball", "volleyball",
            "baseball", "cricket.ball", "football", "rugbyball",
            "figure.badminton", "figure.cricket",
            "figure.basketball", "figure.volleyball", "figure.tennis",
            "dumbbell", "figure.strengthtraining.traditional",
            "figure.yoga", "figure.pilates", "figure.martial.arts",
            "figure.boxing", "figure.american.football", "figure.handball",
            "figure.table.tennis", "figure.fencing", "figure.hockey",
            "figure.skating", "figure.baseball",
            "figure.bowling", "figure.golf", "figure.disc.sports",
            "figure.squash", "figure.softball"
        ]),
        .init(name: "Adventure", symbols: [
            "figure.skateboarding",
            "figure.surfing",
            "figure.rower"
        ]),
        .init(name: "Travel & Exploration", symbols: [
            "airplane.departure", "airplane.arrival", "suitcase",
            "globe", "safari", "signpost.left", "signpost.right",
            "binoculars.fill", "map", "map.fill", "location",
            "location.north.line", "compass.drawing",
            "figure.hiking", "figure.walk.circle", "figure.run.circle"
        ]),
        .init(name: "Hobbies & Activities", symbols: [
            "figure.dance", "music.note", "paintpalette",
            "book", "pencil", "figure.mind.and.body",
            "gamecontroller", "balloon", "cup.and.saucer",
            "fork.knife", "figure.socialdance", "figure.dancing",
            "figure.meditation"
        ]),
        .init(name: "General", symbols: [
            "camera", "photo.on.rectangle", "video", "mic",
            "mic.fill", "speaker.wave.2", "bell", "bell.fill",
            "heart", "heart.fill", "star", "star.fill",
            "checkmark.circle", "checkmark.circle.fill",
            "info.circle", "info.circle.fill", "questionmark.circle",
            "person.circle", "figure.play", "figure.cooldown",
            "figure.mind.and.body", "figure.mixed.cardio",
            "figure.flexibility", "figure.core.training",
            "figure.jumprope", "figure.cooldown.circle"
        ])
    ]
    
    static var allSymbols: [String] {
        availableSymbols.flatMap { $0.symbols }
    }
}

struct SymbolCategory {
    let name: String
    let symbols: [String]
}


@MainActor
private func previewContainer() -> ModelContainer {
    do {
        let schema = Schema([
            CustomEquipment.self
        ])

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)

        let context = container.mainContext

        // Seed sample data
        context.insert(CustomEquipment(displayName: "Water Bottle", symbolName: "drop"))
        context.insert(CustomEquipment(displayName: "Tent", symbolName: "tent"))
        context.insert(CustomEquipment(displayName: "Sunscreen", symbolName: "sun.max"))
        context.insert(CustomEquipment(displayName: "Backpack", symbolName: "backpack"))
        context.insert(CustomEquipment(displayName: "Flashlight", symbolName: "flashlight.on.fill"))

        return container
    } catch {
        fatalError("Failed to create preview container: \(error)")
    }
}

// MARK: - Previews
#Preview("CustomEquipmentView (Seeded)") {
    CustomEquipmentView()
        .modelContainer(previewContainer())
}

#Preview("SymbolPickerView") {
    SymbolPickerView(selectedSymbol: .constant("tent"))
}
