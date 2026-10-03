import SwiftData
import SwiftUI

/// The Exercises tab's root: the Library by Body Area, with search, a Create row and "+".
struct LibraryView: View {
    @Query(filter: #Predicate<Exercise> { $0.isArchived == false }) private var exercises: [Exercise]
    @Query(filter: #Predicate<Workout> { $0.endedAt == nil }) private var activeWorkouts: [Workout]
    @Environment(\.modelContext) private var context
    @State private var path = NavigationPath()
    @State private var search = ""
    @State private var toast: String?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if let name = trimmed(search), Exercise.named(name, in: context) == nil {
                    NavigationLink(value: ExerciseFormRoute.new(name: name)) {
                        Label("Create \"\(name)\"", systemImage: "plus").foregroundStyle(.tint)
                    }
                }
                let sections = Exercise.librarySections(matches)
                if sections.isEmpty, trimmed(search) != nil {
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
                Section {} footer: {
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
            .sharedDestinations(path: $path, onDeleteWorkout: delete)
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

    /// Delete Workout from a detail pushed here. The detail closes itself onto the Exercise page it came from.
    private func delete(_ workout: Workout) {
        do {
            try workout.delete()
        } catch {
            fatalError("Could not delete the Workout: \(error)")
        }
        toast = "Workout deleted"
    }
}

/// The Exercise form's two ways in: a new Exercise (from "+" or a Create row) or an edit from its page.
enum ExerciseFormRoute: Hashable {
    case new(name: String)
    case edit(Exercise)
}

extension View {
    /// The pushes both tabs share: a Workout detail, an Exercise page and the Exercise form, in the current tab.
    func sharedDestinations(path: Binding<NavigationPath>, onDeleteWorkout: @escaping (Workout) -> Void) -> some View {
        navigationDestination(for: Workout.self) { workout in
            WorkoutDetailView(workout: workout, onDelete: onDeleteWorkout)
        }
        .navigationDestination(for: Exercise.self) { exercise in
            ExercisePageView(exercise: exercise)
        }
        .navigationDestination(for: ExerciseFormRoute.self) { route in
            ExerciseFormDestination(route: route, path: path)
        }
    }
}

/// Saving a new Exercise opens its page in the form's place; saving an edit returns to the page.
private struct ExerciseFormDestination: View {
    let route: ExerciseFormRoute
    @Binding var path: NavigationPath
    @Environment(\.modelContext) private var context

    var body: some View {
        switch route {
        case .new(let name):
            ExerciseFormView(name: name) { exercise in
                context.insert(exercise)
                save()
                path.removeLast()
                path.append(exercise)
            }
        case .edit(let exercise):
            ExerciseFormView(editing: exercise) { _ in
                save()
                path.removeLast()
            }
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            fatalError("Could not save the Exercise: \(error)")
        }
    }
}
