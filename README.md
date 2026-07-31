# WheelHours

WheelHours is an offline-first native iOS app that helps teen drivers (and their
parents/supervisors) log supervised practice drives, track progress against their
state's DMV permit-hours requirements, and export a signed log for the road test.

Built with SwiftUI + SwiftData, following an MVVM + Clean Architecture layering.

## Folder structure

```
WheelHours/
  App/
    WheelHoursApp.swift        # @main entry point, ModelContainer setup, root view
  Domain/
    Models/                    # SwiftData @Model entities + plain value types
      DriverProfile.swift
      Supervisor.swift
      Vehicle.swift
      DriveLog.swift
      RoadCondition.swift
      StateDMVPreset.swift
    Services/                  # Business logic / use cases (populated by later tasks)
  Presentation/
    Screens/                   # SwiftUI screens (populated by later tasks)
    Components/                # Reusable SwiftUI views (populated by later tasks)
  Resources/                   # Assets, plists, localized strings, etc.
  Tests/
    WheelHoursTests/           # Unit/UI tests (populated by later tasks)
  README.md
```

`Domain` holds persistence models and (eventually) business-logic services, kept
free of SwiftUI imports where possible. `Presentation` holds SwiftUI views and view
models that consume `Domain` services. `App` wires the two together at launch.

### Model overview

- `DriverProfile` — the teen driver's name, permit issue date, and target state
  code (`targetStateCode`) used to look up DMV requirements.
- `Supervisor` — an adult who can supervise/sign off on drives, with an optional
  captured signature (`signatureData`, PNG bytes).
- `Vehicle` — a named vehicle used during drives.
- `DriveLog` — one supervised drive: start/end times, duration breakdowns
  (total/night/day), optional distance, road conditions, optional linked
  `Supervisor`/`Vehicle`, location names, notes, and a manual-entry flag.
- `RoadCondition` — enum of taggable conditions (city, highway, rural, parking
  lot, wet/rain, snow, fog) with a `displayName` for UI.
- `StateDMVPreset` — plain `Codable` struct (not a SwiftData model) describing one
  state's hour requirements. A later task populates a static array covering all
  50 states; `DriverProfile.targetStateCode` is looked up against that array
  rather than the app storing the preset data itself.

## Known limitations

- **No Xcode project file yet.** This project was scaffolded in a Linux sandbox
  with no access to Xcode or the Apple SDKs, so no `.xcodeproj` or `.xcworkspace`
  exists. Hand-rolling an `.xcodeproj` file without Xcode available to verify it
  is risky and likely to produce a broken/unopenable project, so instead: on a
  Mac, create a new Xcode "App" project (SwiftUI interface, SwiftData for
  storage) named `WheelHours`, then drag the `App`, `Domain`, `Presentation`,
  `Resources`, and `Tests` folders from this repo into the project navigator
  (choosing "Create groups" and adding to the target, and adding
  `Tests/WheelHoursTests` as a test target). Delete the placeholder
  `ContentView.swift`/`App.swift` Xcode generates in favor of the ones here.
- **Code has not been compiled.** No Apple SDKs or Xcode are available in this
  environment, so none of this Swift code has been built or run. It was written
  by hand to be idiomatic Swift 5.9+/SwiftData, but it should be built and
  smoke-tested in Xcode before relying on it.
- `DriveLog.roadConditions` is backed by a stored `[String]`
  (`roadConditionsRaw`) rather than a stored `[RoadCondition]`, since persisting
  arrays of `Codable` enums directly in a SwiftData `@Model` can be unreliable
  depending on the exact Swift/SwiftData toolchain version. Use the
  `roadConditions` computed property for typed access; treat `roadConditionsRaw`
  as private storage.
- `DriveLog.supervisor` / `DriveLog.vehicle` are plain optional relationships
  with no explicit inverse declared on `Supervisor`/`Vehicle`. Add
  `@Relationship(inverse:)` on either side later if bidirectional traversal
  (e.g. "all drives for this supervisor") is needed.

## Info.plist requirements

`LocationTrackingService` (`Domain/Services/LocationTrackingService.swift`) uses
CoreLocation for live, GPS-tracked drives. Since there's no Xcode project yet (see
"Known limitations" above), these keys aren't set anywhere yet — add them to the
target's Info.plist once the Xcode project is created:

- `NSLocationWhenInUseUsageDescription` — required for `.whenInUse` authorization
  (the default level `startLiveDrive()` requests).
- `NSLocationAlwaysAndWhenInUseUsageDescription` — required if `.always`
  authorization is ever requested.
- `UIBackgroundModes` — array containing `location`, required for location updates
  to keep being delivered while the app is backgrounded/the phone is locked
  (paired with `allowsBackgroundLocationUpdates = true` in code).

Location permission is only ever requested when a user explicitly starts a live
drive (`LocationTrackingService.startLiveDrive()`) — never at app launch, and never
as a side effect of manual/offline drive entry.
