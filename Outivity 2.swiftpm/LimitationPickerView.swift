//
//  LimitationPickerView.swift
//  Outivity
//
//  Created by Assistant on 2/25/26.
//

import SwiftUI

struct LimitationPickerView: View {
    @Binding var selectedLimitations: Set<UserLimitation>
    @State private var searchText = ""
    @State private var expandedCategories: Set<LimitationCategory> = []

    let title: String
    let allowsNone: Bool
    let showsDescriptions: Bool

    init(
        selectedLimitations: Binding<Set<UserLimitation>>,
        title: String = "Select Limitations",
        allowsNone: Bool = true,
        showsDescriptions: Bool = true
    ) {
        self._selectedLimitations = selectedLimitations
        self.title = title
        self.allowsNone = allowsNone
        self.showsDescriptions = showsDescriptions
    }

    private var filteredCategories: [LimitationCategory] {
        if searchText.isEmpty {
            return LimitationCategory.allCases
        }

        return LimitationCategory.allCases.filter { category in
            category.limitations.contains { limitation in
                limitation.displayName.localizedCaseInsensitiveContains(searchText) ||
                limitation.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func filteredLimitations(for category: LimitationCategory) -> [UserLimitation] {
        if searchText.isEmpty {
            return category.limitations
        }

        return category.limitations.filter { limitation in
            limitation.displayName.localizedCaseInsensitiveContains(searchText) ||
            limitation.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with summary
                if !selectedLimitations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Selected Limitations")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text("\(selectedLimitations.count)")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(
                                    selectedLimitations
                                        .sorted { $0.displayName < $1.displayName },
                                    id: \.self
                                ) { limitation in
                                    LimitationChip(limitation: limitation) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            _ = selectedLimitations.remove(limitation)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(.separator),
                        alignment: .bottom
                    )
                }

                // Search Bar
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.body)

                        TextField("Search limitations...", text: $searchText)
                            .textFieldStyle(.plain)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                }
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.separator),
                    alignment: .bottom
                )

                // "No Limitations" Option
                if allowsNone {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedLimitations.removeAll()
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: selectedLimitations.isEmpty ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selectedLimitations.isEmpty ? .blue : .secondary)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("No limitations")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)

                                Text("I don't have any accessibility considerations")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(selectedLimitations.isEmpty ? .blue.opacity(0.06) : .clear)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(.separator),
                        alignment: .bottom
                    )
                }

                // Categories List (dropdowns)
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredCategories, id: \.self) { category in
                            let limitations = filteredLimitations(for: category)
                            LimitationCategoryDropdown(
                                category: category,
                                limitations: limitations,
                                selectedLimitations: $selectedLimitations,
                                isExpanded: expandedCategories.contains(category),
                                showsDescriptions: showsDescriptions,
                                onToggleExpanded: {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        if expandedCategories.contains(category) {
                                            expandedCategories.remove(category)
                                        } else {
                                            expandedCategories.insert(category)
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            // Start with categories that have selections expanded (or all when searching)
            expandedCategories = Set(LimitationCategory.allCases.filter { category in
                category.limitations.contains { selectedLimitations.contains($0) }
            })
        }
        .onChange(of: searchText) { _, newValue in
            // When searching, expand everything so matches are immediately visible.
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                expandedCategories = Set(LimitationCategory.allCases.filter { category in
                    category.limitations.contains { selectedLimitations.contains($0) }
                })
            } else {
                expandedCategories = Set(filteredCategories)
            }
        }
    }
}

struct LimitationCategoryDropdown: View {
    let category: LimitationCategory
    let limitations: [UserLimitation]
    @Binding var selectedLimitations: Set<UserLimitation>
    let isExpanded: Bool
    let showsDescriptions: Bool
    let onToggleExpanded: () -> Void

    private var selectedCount: Int {
        limitations.reduce(into: 0) { partialResult, limitation in
            if selectedLimitations.contains(limitation) { partialResult += 1 }
        }
    }

    private var selectionState: SelectionState {
        if selectedCount == 0 { return .none }
        if selectedCount == limitations.count { return .all }
        return .partial
    }

    private enum SelectionState {
        case none, partial, all
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category header (dropdown button)
            Button {
                onToggleExpanded()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.blue.opacity(0.10))
                            .frame(width: 40, height: 40)

                        Image(systemName: category.symbolName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(category.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            if selectionState != .none {
                                Text("\(selectedCount) selected")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }

                        Text("\(limitations.count) option\(limitations.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    // Select-all toggle (hit target + no gesture conflicts)
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            switch selectionState {
                            case .none, .partial:
                                limitations.forEach { selectedLimitations.insert($0) }
                            case .all:
                                limitations.forEach { selectedLimitations.remove($0) }
                            }
                        }
                    } label: {
                        Image(systemName: selectionState == .all ? "checkmark.circle.fill" : selectionState == .partial ? "minus.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selectionState == .none ? Color.secondary : Color.blue)
                            .accessibilityLabel(selectionState == .all ? "Deselect all" : "Select all")
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 2)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.regularMaterial)
            )

            if isExpanded, !limitations.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(limitations.enumerated()), id: \.element) { idx, limitation in
                        LimitationRow(
                            limitation: limitation,
                            isSelected: selectedLimitations.contains(limitation),
                            showsDescription: showsDescriptions,
                            isLast: idx == limitations.count - 1,
                            onToggle: {
                                if selectedLimitations.contains(limitation) {
                                    selectedLimitations.remove(limitation)
                                } else {
                                    selectedLimitations.insert(limitation)
                                }
                            }
                        )
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.regularMaterial)
                        .opacity(0.70)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct LimitationRow: View {
    let limitation: UserLimitation
    let isSelected: Bool
    let showsDescription: Bool
    let isLast: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                onToggle()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .accessibilityHidden(true)

                Image(systemName: limitation.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(limitation.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    if showsDescription {
                        Text(limitation.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(
            Group {
                if !isLast {
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(.separator.opacity(0.6))
                        .padding(.leading, 46)
                }
            },
            alignment: .bottom
        )
        .accessibilityLabel(limitation.displayName)
        .accessibilityHint(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct LimitationChip: View {
    let limitation: UserLimitation
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: limitation.symbolName)
                .font(.caption2)

            Text(limitation.displayName)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.blue.opacity(0.1))
        .foregroundStyle(.blue)
        .clipShape(Capsule())
    }
}

private struct LimitationPickerView_PreviewWrapper: View {
    @State private var selectedLimitations: Set<UserLimitation> = [.lowVision, .wheelchairUser]

    var body: some View {
        LimitationPickerView(
            selectedLimitations: $selectedLimitations,
            title: "Select Your Limitations"
        )
    }
}

#Preview {
    LimitationPickerView_PreviewWrapper()
}
