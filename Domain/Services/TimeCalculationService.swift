import Foundation

/// Pure, dependency-free time and solar-position calculations for `DriveLog` entries.
///
/// Responsibilities:
/// 1. Compute a drive's total duration, in whole minutes, from its start/end `Date`s.
/// 2. Compute a sensible **automatic default** split of that duration into daytime vs.
///    nighttime minutes, based on the actual solar sunrise/sunset for the drive's
///    location and date(s) — not a fixed clock cutoff (e.g. "day = 6am-6pm").
///
/// ## Manual override
/// `DriveLog.dayDurationMinutes` / `DriveLog.nightDurationMinutes` are plain, mutable
/// `Int` fields on the model. This service only produces the automatic calculation; it
/// is expected (and encouraged) that the presentation layer lets a user manually edit
/// the computed split afterward — e.g. a supervisor knows actual conditions were
/// darker/lighter than the astronomical calculation suggests (heavy overcast, a long
/// tunnel, tinted windows, etc.). No override state is stored or read by this service;
/// it only ever produces the automatic calculation.
///
/// ## Accuracy
/// Sunrise/sunset are computed with the NOAA "low precision" solar position algorithm
/// (the same closed-form formulas behind NOAA's public solar calculator spreadsheet).
/// It is accurate to roughly a minute or two of true sunrise/sunset for ordinary dates
/// and latitudes. It is a coarser approximation near the poles and around the equinoxes
/// at very high latitudes, where day length changes extremely quickly — an accepted
/// limitation for this app's use case (supervised driving practice, virtually always
/// well away from polar latitudes).
///
/// All solar math is performed internally in UTC using absolute `Date` instants, so no
/// `TimeZone`/DST assumptions are needed: callers pass in `Date`s (already timezone-free
/// instants, however they were recorded) and get back timezone-free `Date`/minute
/// results.
enum TimeCalculationService {

    // MARK: - Duration

    /// Total duration between `startTime` and `endTime`, in whole minutes.
    ///
    /// Rounding rule: **round-half-up** (equivalently, round-half-away-from-zero for the
    /// non-negative durations expected here) — e.g. 30 minutes 29 seconds rounds down to
    /// 30, while exactly 30 minutes 30 seconds rounds up to 31. This is `Foundation`'s
    /// `.rounded(.toNearestOrAwayFromZero)`.
    ///
    /// If `endTime` precedes `startTime` the result is negative; this function does not
    /// validate ordering — callers should treat a negative result as an invalid drive
    /// log rather than clamp it silently.
    static func totalDurationMinutes(startTime: Date, endTime: Date) -> Int {
        let minutes = endTime.timeIntervalSince(startTime) / 60.0
        return Int(minutes.rounded(.toNearestOrAwayFromZero))
    }

    // MARK: - Day / night classification

    /// Splits a drive into automatic daytime vs. nighttime minutes using real sunrise/
    /// sunset times for `latitude`/`longitude` on the day(s) the drive occurred.
    ///
    /// - "Day" is the time between sunrise and sunset (the standard solar-disc
    ///   definition most sunrise/sunset tables use — not civil/nautical/astronomical
    ///   twilight).
    /// - "Night" is everything else.
    /// - A drive that starts or ends while the sun is mid-transition (crossing sunrise
    ///   or sunset) is split proportionally, down to fractional seconds internally,
    ///   then rounded to whole minutes.
    /// - Multi-day drives (including ones that cross midnight UTC) are handled by
    ///   evaluating sunrise/sunset for every calendar day the drive could possibly
    ///   touch and summing the overlap of each day's (sunrise, sunset) interval with
    ///   `[startTime, endTime]`. This intentionally does *not* clip a given day's
    ///   sunset/sunrise to that UTC calendar day's own midnight-to-midnight window,
    ///   because for locations west of Greenwich a local evening's sunset frequently
    ///   falls just *after* UTC midnight (i.e. "belongs", in absolute UTC terms, to the
    ///   next UTC calendar date) — clipping there would incorrectly reclassify the last
    ///   few minutes before sunset as night.
    /// - `dayMinutes + nightMinutes` always equals exactly
    ///   `totalDurationMinutes(startTime:endTime:)`: `nightMinutes` is derived as the
    ///   remainder after rounding `dayMinutes`, rather than independently rounding both
    ///   values, so the pair never drifts a minute off the true total.
    /// - Returns `(0, 0)` if `endTime <= startTime`.
    ///
    /// - Parameters:
    ///   - startTime: Drive start instant.
    ///   - endTime: Drive end instant.
    ///   - latitude: Degrees, positive north (e.g. `40.7128` for New York City).
    ///   - longitude: Degrees, positive **east**, negative **west** (e.g. `-74.0060`
    ///     for New York City) — matches `CLLocationCoordinate2D.longitude`'s convention.
    /// - Returns: The day/night split, in whole minutes, summing to the total duration.
    static func classifyDayNight(
        startTime: Date,
        endTime: Date,
        latitude: Double,
        longitude: Double
    ) -> (dayMinutes: Int, nightMinutes: Int) {
        guard endTime > startTime else { return (0, 0) }

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let startDay = utcCalendar.startOfDay(for: startTime)
        let endDay = utcCalendar.startOfDay(for: endTime)

        // Pad two calendar days on either side of the query range. A location's solar
        // noon can drift up to ~12 hours from UTC noon purely from longitude, and day
        // length itself can add several more hours at high latitude in summer/winter,
        // so a given day's sunrise/sunset can legitimately land a full UTC day away
        // from that day's own midnight-to-midnight window.
        guard
            let firstDay = utcCalendar.date(byAdding: .day, value: -2, to: startDay),
            let lastDay = utcCalendar.date(byAdding: .day, value: 2, to: endDay)
        else {
            // Should be unreachable for any real `Date`; fail safe to "all night"
            // rather than crash or silently misclassify.
            return (0, totalDurationMinutes(startTime: startTime, endTime: endTime))
        }

        var daySeconds: Double = 0
        var dayCursor = firstDay

        while dayCursor <= lastDay {
            switch SolarCalculator.sunriseSunset(utcDayStart: dayCursor, latitude: latitude, longitude: longitude) {
            case .normal(let sunrise, let sunset):
                let overlapStart = max(startTime, sunrise)
                let overlapEnd = min(endTime, sunset)
                if overlapEnd > overlapStart {
                    daySeconds += overlapEnd.timeIntervalSince(overlapStart)
                }

            case .neverSets:
                // Midnight sun: treat this UTC calendar day as entirely daylight.
                if let dayEnd = utcCalendar.date(byAdding: .day, value: 1, to: dayCursor) {
                    let overlapStart = max(startTime, dayCursor)
                    let overlapEnd = min(endTime, dayEnd)
                    if overlapEnd > overlapStart {
                        daySeconds += overlapEnd.timeIntervalSince(overlapStart)
                    }
                }

            case .neverRises:
                // Polar night: contributes no daylight.
                break
            }

            guard let next = utcCalendar.date(byAdding: .day, value: 1, to: dayCursor) else { break }
            dayCursor = next
        }

        let totalSeconds = endTime.timeIntervalSince(startTime)
        let totalMinutes = Int((totalSeconds / 60.0).rounded(.toNearestOrAwayFromZero))
        let rawDayMinutes = Int((daySeconds / 60.0).rounded(.toNearestOrAwayFromZero))
        let dayMinutes = min(max(rawDayMinutes, 0), totalMinutes)
        let nightMinutes = totalMinutes - dayMinutes

        return (dayMinutes, nightMinutes)
    }
}

/// NOAA "low precision" solar position calculator, used internally by
/// `TimeCalculationService` to compute sunrise/sunset. Not part of the public API —
/// `TimeCalculationService` is the intended entry point for all other services/screens.
///
/// Implements the same closed-form approximation as NOAA's published solar calculator
/// spreadsheet: solar geometry via the mean longitude/anomaly of the sun, the equation
/// of center, the obliquity of the ecliptic, the equation of time, and the standard
/// sunrise/sunset hour-angle formula using a 90.833° zenith angle (accounts for
/// atmospheric refraction and the sun's apparent radius at the horizon, matching the
/// conventional definition of sunrise/sunset used by almanacs and NOAA's own tables).
enum SolarCalculator {

    enum SolarDay {
        /// The sun rises and sets this calendar day; both are absolute UTC instants.
        /// Note `sunset` (and, more rarely, `sunrise`) may fall outside the nominal
        /// `[utcDayStart, utcDayStart + 24h)` window — see `TimeCalculationService`.
        case normal(sunrise: Date, sunset: Date)
        /// The sun never rises above the horizon this day (polar night).
        case neverRises
        /// The sun never sets this day (midnight sun).
        case neverSets
    }

    /// Computes sunrise/sunset for the UTC calendar day beginning at `utcDayStart`
    /// (must be a UTC-midnight instant) at the given coordinates.
    static func sunriseSunset(utcDayStart: Date, latitude: Double, longitude: Double) -> SolarDay {
        // Julian Day / Julian Century, evaluated at UTC noon of this calendar day, per
        // standard NOAA practice (the small intra-day drift in solar position is
        // negligible for sunrise/sunset purposes).
        let noonUTC = utcDayStart.addingTimeInterval(12 * 3600)
        let t = (julianDay(for: noonUTC) - 2451545.0) / 36525.0

        let geomMeanLongSun = normalizedDegrees(280.46646 + t * (36000.76983 + t * 0.0003032))
        let geomMeanAnomSun = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let eccentEarthOrbit = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)

        let mRad = radians(geomMeanAnomSun)
        let sunEqOfCenter = sin(mRad) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * mRad) * (0.019993 - 0.000101 * t)
            + sin(3 * mRad) * 0.000289

        let sunTrueLong = geomMeanLongSun + sunEqOfCenter

        let omega = 125.04 - 1934.136 * t
        let sunAppLong = sunTrueLong - 0.00569 - 0.00478 * sin(radians(omega))

        let meanObliqEcliptic = 23.0
            + (26.0 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60.0) / 60.0
        let obliqCorr = meanObliqEcliptic + 0.00256 * cos(radians(omega))

        let sunDeclination = degreesFromRadians(
            asin(sin(radians(obliqCorr)) * sin(radians(sunAppLong)))
        )

        let varY = pow(tan(radians(obliqCorr / 2.0)), 2)
        let equationOfTimeMinutes = 4.0 * degreesFromRadians(
            varY * sin(2 * radians(geomMeanLongSun))
                - 2 * eccentEarthOrbit * sin(mRad)
                + 4 * eccentEarthOrbit * varY * sin(mRad) * cos(2 * radians(geomMeanLongSun))
                - 0.5 * varY * varY * sin(4 * radians(geomMeanLongSun))
                - 1.25 * eccentEarthOrbit * eccentEarthOrbit * sin(2 * mRad)
        )

        let latRad = radians(latitude)
        let declRad = radians(sunDeclination)

        let cosHourAngle = cos(radians(90.833)) / (cos(latRad) * cos(declRad))
            - tan(latRad) * tan(declRad)

        // Solar noon, in minutes after this calendar day's UTC midnight. Longitude is
        // positive-east, so a location further east reaches solar noon *earlier* in
        // absolute UTC time (hence the subtraction).
        let solarNoonMinutesUTC = 720.0 - 4.0 * longitude - equationOfTimeMinutes

        if cosHourAngle > 1 {
            return .neverRises
        }
        if cosHourAngle < -1 {
            return .neverSets
        }

        let hourAngleDegrees = degreesFromRadians(acos(cosHourAngle))
        let sunriseMinutesUTC = solarNoonMinutesUTC - hourAngleDegrees * 4.0
        let sunsetMinutesUTC = solarNoonMinutesUTC + hourAngleDegrees * 4.0

        let sunrise = utcDayStart.addingTimeInterval(sunriseMinutesUTC * 60.0)
        let sunset = utcDayStart.addingTimeInterval(sunsetMinutesUTC * 60.0)

        return .normal(sunrise: sunrise, sunset: sunset)
    }

    // MARK: - Helpers

    private static func julianDay(for date: Date) -> Double {
        date.timeIntervalSince1970 / 86400.0 + 2440587.5
    }

    private static func normalizedDegrees(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 360.0)
        return remainder < 0 ? remainder + 360.0 : remainder
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180.0 }
    private static func degreesFromRadians(_ radians: Double) -> Double { radians * 180.0 / .pi }
}
