# Muscle Emphases are a value list on Exercise

An Exercise's Muscle Emphases are stored as one `.codable` attribute on Exercise, an ordered list of (Muscle Group raw key, weight), not as a Muscle Emphasis entity. They are always edited and saved as a whole with the Exercise form, so under a later CloudKit sync the list moves with its Exercise record as one last-writer-wins value, with no duplicate or orphan emphasis records to dedupe. The list's own order is the stored order that breaks weight ties, so no `order` field is needed. This goes against the research checklist's "separate records, not merged flat values", which is aimed at data edited concurrently piece by piece, like Sets.

## Consequences

- Predicates and sorting can't see inside the list: Body Area placement, the bars and later volume totals are computed in memory, which is fine at a few hundred Exercises.
- A shape change triggers no migration, so fields added later must be optional or decode with a default.
- Muscle Groups are stored by stable raw key, never display name.

Sources: [What does the data layer do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/19), [research](../research/swiftdata-cloudkit.md)
