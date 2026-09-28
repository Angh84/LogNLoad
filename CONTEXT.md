# LogNLoad

A personal iPhone app for logging strength training.

## Language

**Workout**:
One training session, started empty and built up by adding Exercises as you go.
_Avoid_: Session, routine, template

**Exercise**:
A named strength movement the user has defined, e.g. "Barbell Bench Press".
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
