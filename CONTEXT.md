# LogNLoad

A personal iPhone app for logging strength training.

## Language

**Workout**:
One training session, started empty and built up by adding Exercises as you go.
_Avoid_: Session, routine, template

**Exercise**:
A named strength movement on specific equipment, e.g. "Barbell Bench Press" or "Chest Press (Hoist)". Loads are comparable across all its Sets, so the same movement on machines that load differently is separate Exercises.
_Avoid_: Movement, lift

**Exercise Library**:
The user's own collection of Exercises, seeded with a starter list.
_Avoid_: Catalog, exercise database

**Set**:
One bout of an Exercise within a Workout, recorded as reps and weight. A Set is a target until the user completes it.
_Avoid_: Round

**Completed Set**:
A Set the user has confirmed as performed. Only Completed Sets are kept when a Workout finishes.
_Avoid_: Done set, logged set

**Last Performance**:
The Completed Sets of an Exercise from the most recent Workout that contains it.
_Avoid_: Previous, last time

**Prefill**:
Seeding a newly added Exercise in a Workout with target Sets copied from its Last Performance.
_Avoid_: Autofill, template

**RIR (Reps in Reserve)**:
The user's estimate of how many more reps they could have done on a Completed Set. Optional per Set.
_Avoid_: RPE, effort, intensity

**Muscle Group**:
A body area an Exercise trains, e.g. "Upper Chest". The unit the user sets priorities for. Drawn from a fixed list; the user cannot add or rename them.
_Avoid_: Body part, muscle

**Muscle Emphasis**:
How much an Exercise trains one Muscle Group, as a relative weight from 0 to 1, e.g. Bench Press has a Triceps emphasis of 0.5. An Exercise has one or more.
_Avoid_: Muscle load, involvement, contribution, primary/secondary

**Load Type**:
How an Exercise's weight is read: Loaded (external weight), Bodyweight (optional added weight) or Assisted (weight is assistance, so higher is easier).
_Avoid_: Weight type, mode
