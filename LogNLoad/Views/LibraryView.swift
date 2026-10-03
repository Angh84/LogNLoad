import SwiftData
import SwiftUI

/// The Exercises tab's root: the Library by Body Area, with search, a Create row and "+".
struct LibraryView: View {
    @Query(filter: #Predicate<Exercise> { $0.isArchived == false }) private var exercises: [Exercise]
    @Query(filter: #Predicate<Exercise> { $0.isArchived == true }) private var archived: [Exercise]
    @Query(filter: #Predicate<Workout> { $0.endedAt == nil }) private var activeWorkouts: [Workout]
    @Environment(\.modelContext) private var context
    @Environment(HealthSync.self) private var health
    @State private var path = NavigationPath()
    @State private var search = ""
    @State private var toast: String?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                let name = trimmed(search)
                let named = name.flatMap { Exercise.named($0, in: context) }
                if let name, named == nil {
                    NavigationLink(value: ExerciseFormRoute.new(name: name)) {
                        Label("Create \"\(name)\"", systemImage: "plus").foregroundStyle(.tint)
                    }
                }
                if let named, named.isArchived {
                    archivedHit(named)
                }
                let sections = Exercise.librarySections(matches)
                if sections.isEmpty, name != nil, named?.isArchived != true {
                    Text("No Exercises match").foregroundStyle(.secondary)
                }
                ForEach(sections, id: \.area) { section in
                    Section {
                        ForEach(section.exercises) { exercise in
                            NavigationLink(value: exercise) { row(exercise) }
                        }
                    } header: {
                        HStack {
                            Text(section.area.name)
                            Spacer()
                            Text("\(section.exercises.count)")
                        }
                    }
                }
                Section {
                    if !archived.isEmpty {
                        NavigationLink(value: LibraryRoute.archived) {
                            LabeledContent("Archived", value: "\(archived.count)")
                        }
                    }
                } footer: {
                    Text(DisplayFormat.count(exercises.count, "Exercise"))
                        .frame(maxWidth: .infinity)
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Exercises")
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Exercise", systemImage: "plus") { path.append(ExerciseFormRoute.new(name: "")) }
                }
            }
            .navigationDestination(for: LibraryRoute.self) { _ in ArchivedListView() }
            .sharedDestinations(path: $path, toast: $toast, onDeleteWorkout: delete)
        }
        .toast($toast)
    }

    /// Names only, across every section.
    private var matches: [Exercise] {
        guard let query = trimmed(search) else { return exercises }
        return exercises.filter { ($0.name ?? "").localizedStandardContains(query) }
    }

    /// The name, a green dot while it is in the Active Workout, and its Last Performance line.
    private func row(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(exercise.name ?? "")
                if activeWorkouts.first?.contains(exercise) == true {
                    Circle().fill(.green).frame(width: 7, height: 7)
                        .accessibilityLabel("In your current Workout")
                }
            }
            Text(DisplayFormat.lastPerformance(of: exercise))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    /// A search naming an Archived Exercise: the name stays reserved, so this replaces the Create row.
    private func archivedHit(_ exercise: Exercise) -> some View {
        HStack {
            Text("\(exercise.name ?? "") is archived \u{2013} In \(DisplayFormat.count(exercise.workoutCount, "Workout"))")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Unarchive") { toast = unarchive(exercise, in: context) }
            .buttonStyle(.borderless)
        }
    }

    /// Delete Workout from a detail pushed here. The detail closes itself onto the Exercise page it came from.
    private func delete(_ workout: Workout) {
        do {
            try workout.delete()
        } catch {
            fatalError("Could not delete the Workout: \(error)")
        }
        toast = "Workout deleted"
        Task { await health.sync(in: context) }
    }
}

/// The Library's own push: the Archived list.
private enum LibraryRoute: Hashable {
    case archived
}

/// Archived Exercises A-Z, each opening its Exercise page.
private struct ArchivedListView: View {
    @Query(filter: #Predicate<Exercise> { $0.isArchived == true }) private var archived: [Exercise]

    var body: some View {
        List(archived.sorted { ($0.name ?? "").localizedStandardCompare($1.name ?? "") == .orderedAscending }) { exercise in
            NavigationLink(value: exercise) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name ?? "")
                    Text("In \(DisplayFormat.count(exercise.workoutCount, "Workout"))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Archived")
    }
}

/// The Exercise form's two ways in: a new Exercise (from "+" or a Create row) or an edit from its page.
enum ExerciseFormRoute: Hashable {
    case new(name: String)
    case edit(Exercise)
}

extension View {
    /// The pushes both tabs share: a Workout detail, an Exercise page and the Exercise form, in the current tab.
    /// `toast` shows over the tab's whole stack.
    func sharedDestinations(path: Binding<NavigationPath>, toast: Binding<String?>, onDeleteWorkout: @escaping (Workout) -> Void) -> some View {
        navigationDestination(for: Workout.self) { workout in
            WorkoutDetailView(workout: workout, onDelete: onDeleteWorkout)
        }
        .navigationDestination(for: Exercise.self) { exercise in
            ExercisePageView(exercise: exercise)
        }
        .navigationDestination(for: ExerciseFormRoute.self) { route in
            ExerciseFormDestination(route: route, path: path, toast: toast)
        }
    }
}

/// Saving a new Exercise, or its "Unarchive it", opens the Exercise's page in the form's place; saving an edit
/// returns to the page. Archive and Delete go back to the stack's root; Merge pushes the kept Exercise's page there,
/// so no page of the merged Exercise stays in the stack.
private struct ExerciseFormDestination: View {
    let route: ExerciseFormRoute
    @Binding var path: NavigationPath
    @Binding var toast: String?
    @Environment(\.modelContext) private var context
    /// The Active Workout's, while there is one.
    @Environment(LoggingSession.self) private var session: LoggingSession?

    var body: some View {
        switch route {
        case .new(let name):
            ExerciseFormView(name: name) { exercise in
                context.insert(exercise)
                save(context)
                path.removeLast()
                path.append(exercise)
            } onUnarchive: { exercise in
                toast = unarchive(exercise, in: context)
                path.removeLast()
                path.append(exercise)
            }
        case .edit(let exercise) where exercise.modelContext == nil:
            // A deleted Exercise's form is on its way out.
            Color.clear
        case .edit(let exercise):
            ExerciseFormView(editing: exercise) { _ in
                save(context)
                path.removeLast()
            } onRemove: { message in
                save(context)
                path = NavigationPath()
                toast = message
            } onMerge: { target in
                save(context)
                session?.exerciseMerged(into: target)
                path = NavigationPath()
                path.append(target)
                toast = "Merged into \(target.name ?? "")"
            }
        }
    }
}

/// Unarchives the Exercise in place, returning the toast "X is back in the Library".
private func unarchive(_ exercise: Exercise, in context: ModelContext) -> String {
    exercise.isArchived = false
    save(context)
    return "\(exercise.name ?? "") is back in the Library"
}

private func save(_ context: ModelContext) {
    do {
        try context.save()
    } catch {
        fatalError("Could not save the Exercise: \(error)")
    }
}
