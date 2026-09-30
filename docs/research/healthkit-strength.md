# HealthKit strength workouts: what they carry, and what needs a paid account

Research for issue #4. Sources are Apple primary docs, WWDC transcripts and Apple Support pages, read on 2026-09-28. Apple Support pages already list iOS 27; the HealthKit API availability below is taken from the live developer docs. Items marked **Uncertain** are not stated by any Apple source I found.

## Summary

- An iPhone-only app can save a workout with `HKWorkoutActivityType.traditionalStrengthTraining` ("strength training exercises primarily using machines or free weights") [1]. It carries start/end dates, duration, associated samples (active energy, heart rate, and any other quantity samples), workout events (pause/resume, lap, segment, marker), workout activities, and metadata with Apple keys plus custom string/number/date keys [2][3][4][5][6].
- Use `HKWorkoutBuilder` (iOS 12+) to build and save the workout. Every `HKWorkout(activityType:start:end:...)` initializer and `HKHealthStore.add(_:to:)` is deprecated as of iOS 17 with "Use HKWorkoutBuilder" [7][8][9]. WWDC25 says: "always use the workout builder API to create and save a workout. This will ensure that activity rings are appropriately updated" [10].
- iOS 26 adds live workout sessions on iPhone: `HKWorkoutSession(healthStore:configuration:)`, `associatedWorkoutBuilder()`, `HKLiveWorkoutBuilder` and `HKLiveWorkoutDataSource` all list iOS 26.0 [11][12][13][14]. "All workout activity types are available on iPhone and iPad", but iPhone has no heart rate sensor, so heart rate needs an external Bluetooth HR device [10][15].
- On iOS, saved workouts count toward rings: Exercise by the workout's duration, Move by the associated active energy samples, and Stand by one hour for each wall-clock hour the workout overlaps [2]. Workouts from compatible third-party apps show in the Fitness app's activity summary and count toward Move [16]. In the Health app, the app appears as a data source that the user can reorder or turn off [17].
- Saved HealthKit objects cannot be changed. "HealthKit objects are all immutable" and "Workouts are mostly immutable ... you can continue to add samples" [18][2]. To edit, delete and save a new object (WWDC20: "When you edit a sample, you need to actually delete and add a new sample") [19]. You can also re-save with the same `HKMetadataKeySyncIdentifier` and a higher `HKMetadataKeySyncVersion`, which replaces the older object [20][21].
- An app can delete only objects it saved itself, and loses that ability if the user revokes share permission. Users can always delete any data in the Health app [22]. Deletions leave temporary `HKDeletedObject` records that an anchored query can read [23].
- A paid account is not needed for HealthKit on your own device. Apple's iOS capability table marks HealthKit as available to all three membership types, including the free "Apple Developer" tier [24]. The free Personal Team limits are: provisioning profiles expire after 7 days (rebuild and reinstall), at most 3 devices and 10 App IDs, and at most 3 apps per device [25]. Distribution (App Store, TestFlight) needs the paid program [24][25].

## What a workout can carry

### Activity type and core fields

- `HKWorkoutActivityType.traditionalStrengthTraining` is available on iOS 8.0+ and described as "strength training exercises primarily using machines or free weights" [1].
- `HKWorkout` "records a summary of information about a single physical activity (for example, the duration, total distance, and total energy burned)" and "acts as a container for other HKSample objects" [2].
- Read-back properties include `duration`, `workoutActivityType`, `workoutActivities`, `workoutEvents`, `statistics(for:)`, `allStatistics`, `totalEnergyBurned` and `totalDistance` [2]. `statistics(for:)` (iOS 16+) is calculated "based on the HKQuantitySample objects associated with the workout" [26].

### Builder vs deprecated initializers

- `HKWorkoutBuilder` (iOS 12.0+) "incrementally constructs a workout". When the workout ends, you call `finishWorkout(completion:)` "to create an HKWorkout sample and save it to the HealthKit store" [3].
- `init(healthStore:configuration:device:)` returns a builder "that is not connected to a workout session or other data source" [27]. This is the path for logging a workout without a live session.
- The builder flow is `beginCollection(withStart:)` then `add(_:)` for samples, `addWorkoutEvents(_:)`, `addMetadata(_:)`, `addWorkoutActivity(_:)`, then `endCollection(withEnd:)` and `finishWorkout()`. `discardWorkout()` stops collection and discards the workout without saving it [3][28][29].
- `finishWorkout` requires `endCollection` first. It "returns nil if finishing the workout succeeded but the workout sample is not available because the device is locked" [29].
- Deprecated as of iOS 17.0, each with "Use HKWorkoutBuilder":
  - `HKWorkout.init(activityType:start:end:)` [7]
  - `init(activityType:start:end:duration:totalEnergyBurned:totalDistance:metadata:)` [8]
  - `init(activityType:start:end:workoutEvents:totalEnergyBurned:totalDistance:device:metadata:)` [30]
  - `HKHealthStore.add(_:to:completion:)` [9]
- WWDC25 advice for existing iPhone apps: "make sure to upgrade to the Workout Builder APIs" [10].

### Associated samples (active energy, heart rate)

- Apple says an app "should always provide data for the workout's duration, totalDistance, and totalEnergyBurned properties when the data is both available and relevant", and "a set of associated samples that sum up to these totals". Apple's own examples include `activeEnergyBurned` and `heartRate` (`count/min`) quantity samples per interval [31].
- If a workout has summary information, it "also needs a set of associated samples that add up to the summary's total" [2].
- For rings on iOS, "the Move ring increases by the number of calories in the associated active energy burned samples" [2]. A strength workout with no active energy samples adds no Move credit. It still adds Exercise minutes, because Exercise uses the workout's duration [2].
- Heart rate: "Collecting heart rate data on iPhone or iPad requires pairing with an external heart rate sensor because these devices don't have one" [15]. WWDC25 says any wearable that "supports the heart rate GATT profile" works, and HealthKit then saves heart rate samples itself [10]. The Fitness app lists Apple Watch, AirPods Pro 3, Powerbeats Pro 2, or a compatible Bluetooth heart rate monitor for on-screen workout metrics [32].
- **Uncertain:** whether an iOS 26 iPhone `HKWorkoutSession` with `.traditionalStrengthTraining` and no sensors generates active energy samples by itself. WWDC25 says only that the system generates types "like calories and distance" during a workout, and "may generate different samples than those specifically requested by an app" [10][15]. Assume the app may have to estimate and add its own `activeEnergyBurned` samples. `HKMetadataKeyAverageMETs` (iOS 13+) can record the average intensity as an `HKQuantity` in kcal/(kg*hr) [33].
- Effort (iOS 18+): `HKQuantityTypeIdentifier.workoutEffortScore` exists, and `HKHealthStore.relateWorkoutEffortSample(_:with:activity:)` relates an effort sample to a saved workout [34][35]. Apple's pages for these symbols have no discussion text.

### Events and activities

- `HKWorkoutEventType` values are pause, resume, motionPaused, motionResumed, pauseOrResumeRequest, lap, segment and marker [36].
- `HKWorkoutActivity` (iOS 16+) partitions a workout into separate activities, for example "the active and rest periods during interval training". Every workout has at least one activity [37].

### Metadata

- Apple's workout metadata keys include `HKMetadataKeyIndoorWorkout`, `HKMetadataKeyWorkoutBrandName`, `HKMetadataKeyCoachedWorkout`, `HKMetadataKeyGroupFitness`, `HKMetadataKeyAverageMETs` and `HKMetadataKeyPhysicalEffortEstimationType` [5][33][38][39].
- General identity keys:
  - `HKMetadataKeyExternalUUID` is "a unique identifier ... set by its source" [40].
  - `HKMetadataKeySyncIdentifier` and `HKMetadataKeySyncVersion` identify an object so it can be replaced later (see Edit and delete behaviour) [20][21].
- Custom keys are allowed: "you are also encouraged to create your own, custom keys". Values can be NSString, NSNumber or NSDate [6]. `HKWorkout` should not be subclassed; "You may extend workouts by adding metadata with custom keys" [2].
- Nothing in HealthKit models sets, reps or load for strength training. Apple's workout metadata key list has no such keys [5]. Per-set detail would go in custom metadata, events or activities, or stay in the app. This is an observation from the key list, not an Apple statement.

### iPhone HKWorkoutSession in iOS 26

- `HKWorkoutSession` itself lists iOS 17.0. WWDC23 introduced it on iPhone as the mirrored copy of a primary session running on Apple Watch [11][41]. The initializer an iPhone app uses to start its own session, `init(healthStore:configuration:)`, lists iOS 26.0 [12]. `associatedWorkoutBuilder()`, `HKLiveWorkoutBuilder` and `HKLiveWorkoutDataSource` also list iOS 26.0 [13][14][42].
- WWDC25: "Just like on Apple Watch, you can now use a workout session to track any activity and use the associated workout builder to save the workout in HealthKit" [10].
- Other iPhone session features, all from WWDC25 [10]:
  - A one-time system prompt lets workout data reach the app while the phone is locked, which makes Lock Screen Live Activities possible.
  - Siri can start, pause, resume and cancel a workout from the Lock Screen.
  - After a crash, the app recovers the session with `HKHealthStore.recoverActiveWorkoutSession`.
- Apple's sample project "Building a workout app for iPhone and iPad" requires iOS 26.0 and Xcode 26.0 [43].
- To save workouts at all, the app must request share permission for `HKObjectType.workoutType()` [44].

### How it shows in Fitness and Health

- iOS ring credit (from `HKWorkout` docs): "Workout objects automatically contribute to both the Move and Exercise rings. The Exercise ring increases by the workout's total duration, and the Move ring increases by the number of calories in the associated active energy burned samples. HealthKit also increases the Stand ring by one hour for each wall-clock hour that the workout overlaps" [2].
- Fitness app on iPhone: "Any workout you complete in a compatible third-party app appears in your activity summary and contributes to the progress toward closing your Move ring" [16]. The Fitness app shows completed workouts and Activity rings without an Apple Watch [32].
- Health app:
  - Apps are listed under Profile > Privacy > Apps, where the user turns categories on or off per app [17].
  - Each data type has "Data Sources & Access", where sources can be reordered or turned off. "If multiple sources contribute the same data type, the data source at the top will take priority" [17].
  - Workouts appear under Browse > Activity > Workouts. This is where manual workouts are added [45].
- **Uncertain:** exactly how the Fitness app renders a third-party `traditionalStrengthTraining` workout (icon, which metrics are shown). No Apple source I found describes this.

## Edit and delete behaviour

### No in-place edits

- "HealthKit objects are all immutable. With a few exceptions (such as the object's source revision), the object's properties are set when the object is first created and they cannot change" [18].
- "Workouts are mostly immutable. You set their properties when you instantiate the workout, and they can't change. However, you can continue to add samples to the workouts" [2].
- Saving an object whose UUID already exists in the store fails with `errorInvalidArgument` [46].

### Editing = replace

- WWDC20 "Synchronize health data with HealthKit" (HealthKit engineer): "When you edit a sample, you need to actually delete and add a new sample. If you don't, you could be saving duplicated samples" [19].
- Built-in replace via sync identifier:
  - "When you save an HKObject with a sync identifier, the system looks for any existing objects with the same sync identifier ... If the new object has a greater sync version, the system replaces the old object with the new one. If the old object is associated with a workout or part of a correlation, the system also replaces the old object in the workout or correlation" [20].
  - `HKMetadataKeySyncVersion` takes an NSNumber [21].
  - WWDC20 adds that sync-identifier operations are "transaction safe" [19].
- **Uncertain:** Apple's text describes the sync identifier for `HKObject` in general. Its examples are quantity samples, and no Apple page I found states outright how `HKWorkout` replacement treats the old workout's associated samples. Verify on device before relying on it. The fallback is delete, then rebuild with `HKWorkoutBuilder`.
- **Uncertain:** whether deleting an `HKWorkout` also deletes its associated samples (energy, heart rate). No Apple doc I found states either way. Plan to delete associated samples explicitly (query with `HKQuery.predicateForObjects(from: workout)` [31]), or test on device.

### Delete rules and ownership

- `delete(_:)` (single object and array): "Your app can delete only those objects that it has previously saved to the HealthKit store. If the user revokes sharing permission for an object type, you can no longer delete those objects" [22][47].
- Errors:
  - `errorAuthorizationNotDetermined` if share permission was never requested.
  - `errorAuthorizationDenied` if share permission was denied.
  - `errorInvalidArgument` if the object is not in the store.
  - A multi-object delete is all-or-nothing [22].
- `deleteObjects(of:predicate:)` "Deletes objects saved by this application that match the provided type and predicate" [48].
- "Although your app can manage only the objects it created and saved, the users can always delete any data they want using the Health app" [22].
- Ownership is recorded by the system. On save, HealthKit sets the object's `sourceRevision` "representing the saving app" [46].
- Deletions produce temporary `HKDeletedObject` entries. These can be "removed ... at any time". To catch every deletion, use an `HKObserverQuery` with background delivery plus an anchored object query [23]. This matters if the app mirrors workouts in its own store and the user deletes one in Health.
- Deleting data synced over iCloud "removes it from all synced devices connected to the same iCloud account" [17].

## Account/entitlement requirements

- Enabling HealthKit means adding the HealthKit capability in Xcode. This adds the `com.apple.developer.healthkit` entitlement and a `healthkit` entry in `UIRequiredDeviceCapabilities` [44][49].
- The app also needs `NSHealthUpdateUsageDescription` (write) and `NSHealthShareUsageDescription` (read) in Info.plist [44][50].
- Apple's "Supported capabilities (iOS)" table marks HealthKit as available for ADP, ADEP and "Apple Developer" [24]. The raw table row has a check in all three columns.
  - "Apple Developer" means "Apple Account holders who have agreed to the Apple Developer Agreement ... No cost is associated with this agreement and developers can't distribute apps" [24].
  - For comparison, Apple Pay on the same table is ADP-only [24].
- Free Personal Team limits (Apple "Developer account overview") [25]:
  - "Provisioning profiles that enable apps to be installed on a device will expire 7 days from issuance. You'll need to rebuild and reinstall your app to your device after expiration."
  - "You can register up to 10 App IDs, which expire after 7 days. You can register up to 3 devices, which expire after 7 days. You can install up to 3 apps per device."
  - On-device testing using Xcode is included for "Registered for free". TestFlight, App Store Connect and Certificates, Identifiers & Profiles need a program membership.
- **Uncertain:** whether workouts written by a Personal Team build stay deletable by the app after the 7-day expiry and reinstall. No Apple source covers this. Apple does say that deleting the Health app leaves Health data on the iPhone [17], but that sentence is about the Health app, not third-party apps. Test it on device.

## Sources

1. HKWorkoutActivityType.traditionalStrengthTraining - https://developer.apple.com/documentation/healthkit/hkworkoutactivitytype/traditionalstrengthtraining
2. HKWorkout - https://developer.apple.com/documentation/healthkit/hkworkout
3. HKWorkoutBuilder - https://developer.apple.com/documentation/healthkit/hkworkoutbuilder
4. HKWorkoutEvent - https://developer.apple.com/documentation/healthkit/hkworkoutevent
5. Workout metadata keys - https://developer.apple.com/documentation/healthkit/workout-metadata-keys
6. HKObject.metadata - https://developer.apple.com/documentation/healthkit/hkobject/metadata
7. HKWorkout init(activityType:start:end:) (deprecated) - https://developer.apple.com/documentation/healthkit/hkworkout/init(activitytype:start:end:)
8. HKWorkout init(activityType:start:end:duration:totalEnergyBurned:totalDistance:metadata:) (deprecated) - https://developer.apple.com/documentation/healthkit/hkworkout/init(activitytype:start:end:duration:totalenergyburned:totaldistance:metadata:)
9. HKHealthStore.add(_:to:completion:) (deprecated) - https://developer.apple.com/documentation/healthkit/hkhealthstore/add(_:to:completion:)
10. WWDC25 session 322 "Track workouts with HealthKit on iOS and iPadOS" (transcript) - https://developer.apple.com/videos/play/wwdc2025/322/
11. HKWorkoutSession - https://developer.apple.com/documentation/healthkit/hkworkoutsession
12. HKWorkoutSession init(healthStore:configuration:) - https://developer.apple.com/documentation/healthkit/hkworkoutsession/init(healthstore:configuration:)
13. HKWorkoutSession.associatedWorkoutBuilder() - https://developer.apple.com/documentation/healthkit/hkworkoutsession/associatedworkoutbuilder()
14. HKLiveWorkoutBuilder - https://developer.apple.com/documentation/healthkit/hkliveworkoutbuilder
15. HKWorkoutSession overview (iPhone/iPad heart rate note) - https://developer.apple.com/documentation/healthkit/hkworkoutsession
16. Apple Support, "Sync a third-party workout app to Fitness on iPhone" - https://support.apple.com/guide/iphone/sync-a-third-party-workout-app-iph392b962da/ios
17. Apple Support, "Manage Health data on your iPhone, iPad, or Apple Watch" - https://support.apple.com/en-us/108779
18. HKObject - https://developer.apple.com/documentation/healthkit/hkobject
19. WWDC20 session 10184 "Synchronize health data with HealthKit" (transcript) - https://developer.apple.com/videos/play/wwdc2020/10184/
20. HKMetadataKeySyncIdentifier - https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncidentifier
21. HKMetadataKeySyncVersion - https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncversion
22. HKHealthStore.delete(_:withCompletion:) (array) - https://developer.apple.com/documentation/healthkit/hkhealthstore/delete(_:withcompletion:)-17hzm
23. HKDeletedObject - https://developer.apple.com/documentation/healthkit/hkdeletedobject
24. Apple Developer Account Help, "Supported capabilities (iOS)" - https://developer.apple.com/help/account/reference/supported-capabilities-ios
25. Apple Developer Account Help, "Developer account overview" - https://developer.apple.com/support/compare-memberships/
26. HKWorkout.statistics(for:) - https://developer.apple.com/documentation/healthkit/hkworkout/statistics(for:)
27. HKWorkoutBuilder init(healthStore:configuration:device:) - https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/init(healthstore:configuration:device:)
28. HKWorkoutBuilder.discardWorkout() - https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/discardworkout()
29. HKWorkoutBuilder.finishWorkout(completion:) - https://developer.apple.com/documentation/healthkit/hkworkoutbuilder/finishworkout(completion:)
30. HKWorkout init(activityType:start:end:workoutEvents:totalEnergyBurned:totalDistance:device:metadata:) (deprecated) - https://developer.apple.com/documentation/healthkit/hkworkout/init(activitytype:start:end:workoutevents:totalenergyburned:totaldistance:device:metadata:)
31. Adding samples to a workout - https://developer.apple.com/documentation/healthkit/adding-samples-to-a-workout
32. Apple Support, "Get started with Fitness on iPhone" - https://support.apple.com/guide/iphone/get-started-with-fitness-ipha5dddb411/ios
33. HKMetadataKeyAverageMETs - https://developer.apple.com/documentation/healthkit/hkmetadatakeyaveragemets
34. HKQuantityTypeIdentifier.workoutEffortScore - https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/workouteffortscore
35. HKHealthStore.relateWorkoutEffortSample(_:with:activity:completion:) - https://developer.apple.com/documentation/healthkit/hkhealthstore/relateworkouteffortsample(_:with:activity:completion:)
36. HKWorkoutEventType - https://developer.apple.com/documentation/healthkit/hkworkouteventtype
37. HKWorkoutActivity - https://developer.apple.com/documentation/healthkit/hkworkoutactivity
38. HKMetadataKeyIndoorWorkout - https://developer.apple.com/documentation/healthkit/hkmetadatakeyindoorworkout
39. HKMetadataKeyWorkoutBrandName - https://developer.apple.com/documentation/healthkit/hkmetadatakeyworkoutbrandname
40. HKMetadataKeyExternalUUID - https://developer.apple.com/documentation/healthkit/hkmetadatakeyexternaluuid
41. WWDC23 "Build a multi-device workout app" - https://developer.apple.com/videos/play/wwdc2023/10023/
42. HKLiveWorkoutDataSource - https://developer.apple.com/documentation/healthkit/hkliveworkoutdatasource
43. Sample code "Building a workout app for iPhone and iPad" - https://developer.apple.com/documentation/healthkit/building-a-workout-app-for-iphone-and-ipad
44. Setting up HealthKit - https://developer.apple.com/documentation/healthkit/setting-up-healthkit ; Running workout sessions (share workoutType) - https://developer.apple.com/documentation/healthkit/running-workout-sessions
45. Apple Support, "How to manually add a workout in the Health app" - https://support.apple.com/en-us/101952
46. HKHealthStore.save(_:withCompletion:) - https://developer.apple.com/documentation/healthkit/hkhealthstore/save(_:withcompletion:)-6fmtg
47. HKHealthStore.delete(_:withCompletion:) (single) - https://developer.apple.com/documentation/healthkit/hkhealthstore/delete(_:withcompletion:)-78l1m
48. HKHealthStore.deleteObjects(of:predicate:withCompletion:) - https://developer.apple.com/documentation/healthkit/hkhealthstore/deleteobjects(of:predicate:withcompletion:)
49. HealthKit Entitlement - https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.healthkit
50. NSHealthUpdateUsageDescription - https://developer.apple.com/documentation/bundleresources/information-property-list/nshealthupdateusagedescription
