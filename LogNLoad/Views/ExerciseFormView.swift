import SwiftData
import SwiftUI

/// The Exercise form: a new Exercise (from the picker's Create row or the Library's "+"), or an edit of one from its
/// page. With history, Load Type and Unilateral are locked and equipment stays within its weight convention. A new
/// form offers to unarchive the Archived Exercise its name belongs to; an edit form ends with Merge and Archive with
/// history, or Delete without.
struct ExerciseFormView: View {
    let onSave: (Exercise) -> Void
    /// A new form's "Unarchive it", with the Archived Exercise its name belongs to.
    private var onUnarchive: ((Exercise) -> Void)?
    /// An edit form's Archive or Delete, done, with the toast to show.
    private var onRemove: ((String) -> Void)?
    /// An edit form's Merge, done, with the Exercise kept.
    private var onMerge: ((Exercise) -> Void)?
    /// The Exercise being edited; empty for a new one.
    private let exercise: Exercise?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Draft
    private let initial: Draft
    /// The added Muscle Group whose weight control is open.
    @State private var adjusting: MuscleGroup?
    @State private var isConfirmingDiscard = false
    @State private var isConfirmingArchive = false
    @State private var isConfirmingDelete = false
    @State private var isPickingMergeTarget = false

    /// What the form holds until Save.
    private struct Draft: Equatable {
        var name: String
        var muscleEmphases: [MuscleEmphasis] = []
        var equipment: Equipment?
        var loadType = LoadType.loaded
        var isUnilateral = false
        var note = ""
    }

    init(name: String, onSave: @escaping (Exercise) -> Void, onUnarchive: @escaping (Exercise) -> Void) {
        self.onSave = onSave
        self.onUnarchive = onUnarchive
        exercise = nil
        initial = Draft(name: name)
        _draft = State(initialValue: initial)
    }

    init(
        editing exercise: Exercise,
        onSave: @escaping (Exercise) -> Void,
        onRemove: @escaping (String) -> Void,
        onMerge: @escaping (Exercise) -> Void
    ) {
        self.onSave = onSave
        self.onRemove = onRemove
        self.onMerge = onMerge
        self.exercise = exercise
        initial = Draft(
            name: exercise.name ?? "",
            muscleEmphases: exercise.muscleEmphases,
            equipment: exercise.equipment,
            loadType: exercise.loadType,
            isUnilateral: exercise.isUnilateral,
            note: exercise.note ?? ""
        )
        _draft = State(initialValue: initial)
    }

    var body: some View {
        let named = Exercise.named(draft.name, in: context)
        let conflict = named == exercise ? nil : named
        let isValid = !isIncomplete && conflict == nil
        let isLocked = exercise?.hasHistory ?? false
        Form {
            Section {
                TextField("Name", text: $draft.name)
            } footer: {
                if let conflict, let name = conflict.name {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(conflict.isArchived ? "\(name) is archived." : "You already have an Exercise called \(name).")
                            .foregroundStyle(.red)
                        if conflict.isArchived, let onUnarchive {
                            Button("Unarchive it") { onUnarchive(conflict) }
                                .font(.footnote.weight(.semibold))
                        }
                    }
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
                        let isAllowed = exercise?.allowedEquipment.contains(equipment) ?? true
                        Button { draft.equipment = equipment } label: {
                            Chip(title: equipment.name, isOn: draft.equipment == equipment, horizontalPadding: 6)
                                .frame(maxWidth: .infinity)
                                .opacity(isAllowed ? 1 : 0.35)
                        }
                        .disabled(!isAllowed)
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
                .disabled(isLocked)
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
                    .disabled(isLocked)
            } footer: {
                Text("Left and right reps are logged separately.")
            }
            if isLocked, let exercise {
                Section {
                    Text("It's in \(DisplayFormat.count(exercise.workoutCount, "Workout")), so Load Type and Unilateral are locked. "
                        + DisplayFormat.equipmentLimit(for: exercise)
                        + " Changing them would change what the logged Sets mean. If one is wrong, create a new Exercise and archive this one.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
            if let exercise {
                Section {
                    if exercise.hasHistory {
                        Button("Merge into Another Exercise") { isPickingMergeTarget = true }
                        Button("Archive Exercise") { isConfirmingArchive = true }
                            .disabled(!exercise.canArchive)
                    } else {
                        Button("Delete Exercise", role: .destructive) { isConfirmingDelete = true }
                    }
                } footer: {
                    if exercise.isInActiveWorkout {
                        Text("It's in your current Workout, so it can't be archived yet.")
                    }
                }
            }
        }
        .navigationTitle(exercise == nil ? "New Exercise" : "Edit Exercise")
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
        .sheet(isPresented: $isPickingMergeTarget) {
            if let exercise {
                MergeSheet(exercise: exercise) { target in
                    exercise.merge(into: target)
                    isPickingMergeTarget = false
                    onMerge?(target)
                }
            }
        }
        .alert("Archive \(exercise?.name ?? "")?", isPresented: $isConfirmingArchive) {
            Button("Cancel", role: .cancel) {}
            Button("Archive") { remove("archived") { $0.archive() } }
        } message: {
            Text("It's in \(DisplayFormat.count(exercise?.workoutCount ?? 0, "Workout")), so it stays in your history. It's hidden from the Library and the Exercise picker until you unarchive it.")
        }
        .alert("Delete \(exercise?.name ?? "")?", isPresented: $isConfirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { remove("deleted") { $0.delete() } }
        } message: {
            Text("It isn't in any Workout, so it's deleted for good." + (exercise?.isSeed == true ? " Starter Exercises you delete don't come back." : ""))
        }
    }

    /// Archive or Delete, then the toast "X archived" or "X deleted".
    private func remove(_ verb: String, _ action: (Exercise) -> Void) {
        guard let exercise else { return }
        let name = exercise.name ?? ""
        action(exercise)
        onRemove?("\(name) \(verb)")
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
        guard let name = trimmed(draft.name), let equipment = draft.equipment else { return }
        let conflict = Exercise.named(name, in: context)
        if let exercise {
            guard conflict == nil || conflict == exercise else { return }
            exercise.update(name: name, equipment: equipment, loadType: draft.loadType, isUnilateral: draft.isUnilateral, note: draft.note, muscleEmphases: draft.muscleEmphases)
            onSave(exercise)
            return
        }
        guard conflict == nil else { return }
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

/// "Merge X into...": the Compatible Exercises to keep it in, then the confirm.
private struct MergeSheet: View {
    let exercise: Exercise
    let onMerge: (Exercise) -> Void
    @Query private var exercises: [Exercise]
    @State private var search = ""
    @State private var target: Exercise?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // The merged Exercise is deleted while the sheet closes.
        if exercise.modelContext == nil {
            Color.clear
        } else {
            targetList
        }
    }

    private var targetList: some View {
        let name = exercise.name ?? ""
        let targets = exercise.mergeTargets(among: exercises)
        let alsoMainly = matching(targets.alsoMainly)
        let others = matching(targets.others)
        return NavigationStack {
            List {
                Text("Pick the Exercise to keep. The Sets in \(DisplayFormat.count(exercise.workoutCount, "Workout")) move to it, then \(name) is deleted.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                if !alsoMainly.isEmpty {
                    section("Also mainly \(exercise.topMuscleGroup?.name ?? "")", alsoMainly)
                }
                if !others.isEmpty {
                    section(alsoMainly.isEmpty ? "Matches" : "Other matches", others)
                }
                if alsoMainly.isEmpty, others.isEmpty {
                    Text("No matching Exercise").foregroundStyle(.secondary)
                }
                Section {} footer: {
                    Text(DisplayFormat.mergeFilter(for: exercise, hiddenCount: targets.hiddenCount))
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Exercises")
            .navigationTitle("Merge \(name) into...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert(
                "Move \(DisplayFormat.count(exercise.workoutCount, "Workout")) from \(name) to \(target?.name ?? "") and delete \(name)?",
                isPresented: Binding { target != nil } set: { if !$0 { target = nil } },
                presenting: target
            ) { target in
                Button("Cancel", role: .cancel) {}
                Button("Merge", role: .destructive) { onMerge(target) }
            } message: { target in
                let shared = exercise.workoutCount(sharedWith: target)
                let combined = "\(DisplayFormat.count(shared, "Workout")) already \(shared == 1 ? "has" : "have") \(target.name ?? ""), so the Sets are combined there. "
                Text((shared > 0 ? combined : "") + "This can't be undone.")
            }
        }
    }

    private func section(_ title: String, _ exercises: [Exercise]) -> some View {
        Section(title) {
            ForEach(exercises) { candidate in
                Button { target = candidate } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(candidate.name ?? "")
                        Text("\(candidate.equipment?.name ?? "") \u{2013} " + (candidate.hasHistory ? "in \(DisplayFormat.count(candidate.workoutCount, "Workout"))" : "not logged yet"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
            }
        }
    }

    private func matching(_ exercises: [Exercise]) -> [Exercise] {
        guard let query = trimmed(search) else { return exercises }
        return exercises.filter { ($0.name ?? "").localizedStandardContains(query) }
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
