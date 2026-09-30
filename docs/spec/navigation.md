# Navigation

The app's structure: tabs, the pinned Workout bar, what launch shows, the logging cover, onboarding, and where each screen is pushed. Screen contents: [logging-screen.md](logging-screen.md), [history-screens.md](history-screens.md), [exercise-library-screens.md](exercise-library-screens.md).

## Tabs

- Two tabs: History, then Exercises. No Workout tab, no Settings screen.
- History's root is the History list; Exercises' root is the Library list.

## Pinned Workout bar

- A bar pinned above the tab bar on both tabs (`tabViewBottomAccessory`).
- With no Active Workout it is "Start Workout".
- During an Active Workout it shows the current Exercise, "Set n of m" and the elapsed timer. Tapping it expands the logging cover.
  - **Open** ([What do the logging and Library screens do in the cases the spec leaves open?](https://github.com/Angh84/LogNLoad/issues/20)): what it shows when the Workout has no Exercise Entries, when the current Entry has no target Set left, and when the current Set is a Warm-up Set.

## Launch

- First launch: the onboarding screen.
- Any other launch with an Active Workout: the logging cover, expanded, with the stale prompt on top when it is due ([workout-lifecycle.md](workout-lifecycle.md#stale-workout)).
- Any other launch: the History tab.

## Logging cover

- The Focus logging screen is a full-screen cover.
- It minimizes into the pinned bar by swiping down or tapping its chevron. While minimized, History and Exercises are fully usable.
- "Start Workout" starts the Workout at once ([workout-lifecycle.md](workout-lifecycle.md#start)) and expands the cover with the Exercise picker sheet already up.
- After Finish, the cover closes, the History tab is selected, and the list shows the new Workout ([history-screens.md](history-screens.md#finish-landing)). The bar returns to "Start Workout".
- After Discard, the cover closes onto whichever tab was underneath.

## Editing a finished Workout

- Workout detail is pushed in the current tab's stack.
- Its Edit opens the Focus screen in edit mode as a full-screen cover. Done or Cancel returns to the detail.
- While an Active Workout exists, Edit is disabled ([history-screens.md](history-screens.md#workout-detail)).

## Onboarding

- First launch only: one screen with the app name, "Finished Workouts are saved to Apple Health as strength training", and Continue.
- Continue raises the system Health permission sheet ([healthkit.md](healthkit.md#permission)), then shows the History tab.

## Exercise form

- From the picker's `Create "<search text>"` row: pushed inside the picker sheet, which goes full height. Back returns to the picker with the search kept. Save adds the Exercise to the Workout and closes the sheet onto its new Entry.
- From the Exercises tab: pushed from the Library's "+" and from Edit on an Exercise page.
- The Swap picker has no Create row.

## Links between tabs' screens

- An Exercise page's history row pushes that Workout's detail in the current tab.
- A Workout detail's "Exercise history >" pushes that Exercise's page in the current tab.
- Nothing switches tabs, apart from Finish selecting History.

Sources: [What is the app's navigation structure?](https://github.com/Angh84/LogNLoad/issues/13), [How does a Workout start, finish, and survive interruption?](https://github.com/Angh84/LogNLoad/issues/7), [How do the Exercise Library screens look?](https://github.com/Angh84/LogNLoad/issues/16)
