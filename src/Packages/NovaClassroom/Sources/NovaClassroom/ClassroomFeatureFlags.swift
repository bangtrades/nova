import Foundation

/// Runtime feature flags for the classroom surface (V2-S1-06).
///
/// Why this exists: `classroomV2Enabled` shipped as a hard-coded `true`
/// literal in `HomeView.swift` — no way back to the legacy grid Home
/// without recompiling, which the V2 risk register called out ("hard-
/// `true` with no rollback path"). This resolver keeps the default
/// exactly as shipped (`true`, classroom is the Kids experience) while
/// wiring two runtime escape hatches:
///
/// 1. **Environment override** — `NOVA_CLASSROOM_V2=0` in the Xcode
///    scheme / launch environment flips a dev run back to the legacy
///    grid. Same idiom as `NOVA_CLASSROOM_FORCE_AGE_BAND`.
/// 2. **Persisted default** — `defaults write <bundle id>
///    nova.classroomV2Enabled.v1 -bool NO` (or a future parent-settings
///    toggle writing the same key) flips an installed build without a
///    rebuild. Absent key → shipped default.
///
/// Resolution precedence: environment > persisted default > `true`.
/// The flag is read once per launch at `HomeView` load — a restart-level
/// toggle by design; live-swapping the entire Home hierarchy mid-session
/// is not a state transition the kid flow needs.
public enum ClassroomFeatureFlags {
    /// UserDefaults key for the persisted override. Versioned so a
    /// future semantic change can migrate cleanly.
    public static let classroomV2DefaultsKey = "nova.classroomV2Enabled.v1"

    /// Launch-environment override key.
    static let environmentKey = "NOVA_CLASSROOM_V2"

    /// Resolve whether the V2 classroom Home is enabled.
    ///
    /// - Parameters:
    ///   - environment: Injectable for tests; defaults to the process
    ///     environment.
    ///   - defaults: Injectable for tests; defaults to `.standard`.
    public static func classroomV2Enabled(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard
    ) -> Bool {
        if let raw = environment[environmentKey], let parsed = parseFlag(raw) {
            return parsed
        }
        if defaults.object(forKey: classroomV2DefaultsKey) != nil {
            return defaults.bool(forKey: classroomV2DefaultsKey)
        }
        return true
    }

    /// Lenient boolean parsing for the env override. Unrecognized
    /// values return `nil` (treated as "no override") rather than
    /// guessing — a typo'd override must not silently flip the Home.
    static func parseFlag(_ raw: String) -> Bool? {
        switch raw.trimmingCharacters(in: .whitespaces).lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return nil
        }
    }
}
