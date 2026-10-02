import SwiftData
import SwiftUI

/// The form for a new Exercise, pushed from the picker's Create row with the search as its name.
struct ExerciseFormView: View {
    let onSave: (Exercise) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Draft
    private let initial: Draft
    /// The added Muscle Group whose weight control is open.
    @State private var adjusting: MuscleGroup?
    @State private var isConfirmingDiscard = false

    /// What the form holds until Save.
    private struct Draft: Equatable {
        var name: String
        var muscleEmphases: [MuscleEmphasis] = []
        var equipment: Equipment?
        var loadType = LoadType.loaded
        var isUnilateral = false
        var note = ""
    }

    init(name: String, onSave: @escaping (Exercise) -> Void) {
        self.onSave = onSave
        initial = Draft(name: name)
        _draft = State(initialValue: initial)
    }

    var body: some View {
        let conflict = Exercise.named(draft.name, in: context)
        let isValid = !isIncomplete && conflict == nil
        Form {
            Section {
                TextField("Name", text: $draft.name)
            } footer: {
                if let conflict, let name = conflict.name {
                    Text(conflict.isArchived ? "\(name) is archived." : "You already have an Exercise called \(name).")
                        .foregroundStyle(.red)
                }
            }
            Section {
                muscleGroups
            } header: {
                Text("Muscle Groups")
            } footer: {
                Text("Each weight is how much one Set counts toward that Muscle Group: 1.0 is a full Set, 0.5 is half a Set.")
            }
            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        Button { draft.equipment = equipment } label: {
                            Chip(title: equipment.name, isOn: draft.equipment == equipment, horizontalPadding: 6)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .buttonStyle(.plain)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            } header: {
                Text("Equipment")
            } footer: {
                if let equipment = draft.equipment, equipment.weightConvention == .perImplement {
                    Text("Weight is logged per \(equipment.name.lowercased()).")
                }
            }
            Section {
                Picker("Load Type", selection: $draft.loadType) {
                    ForEach(LoadType.allCases, id: \.self) { Text($0.name) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Load Type")
            } footer: {
                switch draft.loadType {
                case .loaded: Text("Weight is the load you lift.")
                case .bodyweight: Text("Weight is added load. 0 kg is bodyweight only.")
                case .assisted: Text("Weight is assistance, so a higher number is easier.")
                }
            }
            Section {
                Toggle("Unilateral", isOn: $draft.isUnilateral)
            } footer: {
                Text("Left and right reps are logged separately.")
            }
            Section {
                TextField("Note", text: $draft.note, axis: .vertical)
            } footer: {
                Text("Shown while you log this Exercise.")
            }
            if isIncomplete {
                Section {} footer: {
                    Text("Add a name, equipment and at least one Muscle Group to save.")
                }
            }
        }
        .navigationTitle("New Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", systemImage: "chevron.left") {
                    if draft == initial { dismiss() } else { isConfirmingDiscard = true }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!isValid || draft == initial)
            }
        }
        .interactiveDismissDisabled(draft != initial)
        .alert("Discard your changes?", isPresented: $isConfirmingDiscard) {
            Button("Keep Editing", role: .cancel) {}
            Button("Discard", role: .destructive) { dismiss() }
        }
    }

    /// All 22 Muscle Groups in Body Area rows. Tapping one adds it at 1.0, last in stored order; tapping an added one
    /// opens its weight control.
    private var muscleGroups: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(BodyArea.allCases, id: \.self) { area in
                VStack(alignment: .leading, spacing: 6) {
                    Text(area.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 6) {
                        ForEach(area.muscleGroups, id: \.self) { group in
                            Button { tap(group) } label: {
                                Chip(title: chipTitle(group), isOn: weight(of: group) != nil)
                            }
                        }
                    }
                    if let adjusting, adjusting.bodyArea == area {
                        weightControl(for: adjusting)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    private func weightControl(for group: MuscleGroup) -> some View {
        HStack {
            Picker(group.name, selection: weightBinding(group)) {
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { Text(Self.weightText($0)).tag($0) }
            }
            .pickerStyle(.segmented)
            Button("Remove", role: .destructive) {
                draft.muscleEmphases.removeAll { $0.muscleGroup == group }
                adjusting = nil
            }
            .buttonStyle(.borderless)
        }
    }

    private func tap(_ group: MuscleGroup) {
        if weight(of: group) == nil {
            draft.muscleEmphases.append(MuscleEmphasis(muscleGroup: group, weight: 1))
        } else {
            adjusting = adjusting == group ? nil : group
        }
    }

    private func weight(of group: MuscleGroup) -> Double? {
        draft.muscleEmphases.first { $0.muscleGroup == group }?.weight
    }

    private func weightBinding(_ group: MuscleGroup) -> Binding<Double> {
        Binding {
            weight(of: group) ?? 1
        } set: { weight in
            guard let index = draft.muscleEmphases.firstIndex(where: { $0.muscleGroup == group }) else { return }
            draft.muscleEmphases[index].weight = weight
        }
    }

    private func chipTitle(_ group: MuscleGroup) -> String {
        weight(of: group).map { "\(group.name) \(Self.weightText($0))" } ?? group.name
    }

    private static func weightText(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(1...2)))
    }

    private var isIncomplete: Bool {
        trimmed(draft.name) == nil || draft.equipment == nil || draft.muscleEmphases.isEmpty
    }

    private func save() {
        guard let name = trimmed(draft.name), let equipment = draft.equipment, Exercise.named(name, in: context) == nil else { return }
        onSave(Exercise(
            name: name,
            equipment: equipment,
            loadType: draft.loadType,
            isUnilateral: draft.isUnilateral,
            note: draft.note,
            muscleEmphases: draft.muscleEmphases
        ))
    }
}

/// Lays chips out left to right, wrapping onto a new line when the row is full.
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if let last = rows.last, last.width + spacing + size.width <= width {
                rows[rows.count - 1].indices.append(index)
                rows[rows.count - 1].width += spacing + size.width
                rows[rows.count - 1].height = max(last.height, size.height)
            } else {
                rows.append(([index], size.width, size.height))
            }
        }
        return rows
    }
}
