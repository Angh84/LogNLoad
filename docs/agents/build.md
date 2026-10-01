# Build, test and run

`project.yml` (XcodeGen) is the source of the Xcode project; `LogNLoad.xcodeproj` is generated and gitignored. Run `xcodegen generate` after cloning and after adding, moving or deleting any file, then build. Run every command from the repo root.

## Typecheck

```bash
xcodegen generate && xcodebuild build-for-testing -project LogNLoad.xcodeproj -scheme LogNLoad -destination 'generic/platform=iOS Simulator' -quiet
```

Silent on success; prints only warnings and errors.

## Test

Tests use Swift Testing on the iPhone 17e simulator, the user's phone model. Domain tests open the store with `ModelContainer.logNLoad(inMemory: true)`.

```bash
xcodebuild test -project LogNLoad.xcodeproj -scheme LogNLoad -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "✘|error:|Test run with|TEST (SUCCEEDED|FAILED)"
```

- One suite: add `-only-testing:LogNLoadTests/<SuiteStruct>`, e.g. `-only-testing:LogNLoadTests/SchemaTests`.
- Keep `-quiet` off here: the `grep` needs Swift Testing's `✘` lines and its `Test run with N tests` summary, which `-quiet` drops.
- PosterBoard crash reports during a simulator run come from the simulator's lock screen, not from the app.

## Run in the simulator

```bash
APP=$(xcodebuild -project LogNLoad.xcodeproj -scheme LogNLoad -destination 'platform=iOS Simulator,name=iPhone 17e' -showBuildSettings 2>/dev/null | awk '$1 == "BUILT_PRODUCTS_DIR" {print $3}')/LogNLoad.app
xcrun simctl boot "iPhone 17e"
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.angh84.lognload
```

Build first (Typecheck or Test above); `APP` points at that build's output.

## Install on the iPhone

The phone is paired, trusted and in Developer Mode, and installs over USB or the same Wi-Fi. Signing uses the free Personal Team: the profile expires after 7 days, then rebuild and reinstall. Find the phone's UDID with `xcrun devicectl list devices` (the `physical` row).

```bash
UDID=<the phone's UDID>
xcodebuild build -project LogNLoad.xcodeproj -scheme LogNLoad -destination "id=$UDID" -allowProvisioningUpdates -allowProvisioningDeviceRegistration -quiet
APP=$(xcodebuild -project LogNLoad.xcodeproj -scheme LogNLoad -destination "id=$UDID" -showBuildSettings 2>/dev/null | awk '$1 == "BUILT_PRODUCTS_DIR" {print $3}')/LogNLoad.app
xcrun devicectl device install app --device "$UDID" "$APP"
xcrun devicectl device process launch --device "$UDID" com.angh84.lognload
```

A launch that fails with "profile has not been explicitly trusted" needs the user: Settings > General > VPN & Device Management > the Apple Development profile > Trust.
