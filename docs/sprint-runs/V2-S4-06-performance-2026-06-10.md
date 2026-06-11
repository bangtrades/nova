# V2-S4-06 — performance pass (apply the May 11 audit recommendations)

> Slice run summary, 2026-06-10. Single slice, executed directly by the
> session lead on the Mac — build-verified locally. Reconciled against
> [`SPRINT-V2-classroom-tracker.md`](../SPRINT-V2-classroom-tracker.md)
> and the May 11 audit
> (`cortana-vault/projects/novai/slices/2026-05-11--…--v2-classroom-swiftui-performance-code-audit.md`).

---

## Meta

- **Slice:** V2-S4-06 (plan acceptance: "Classroom home scrolls/interacts smoothly on target iPad. Large background images are compressed and do not cause memory warnings.")
- **Agent:** session lead (Fable 5), direct execution.
- **Run window:** 2026-06-10.
- **Status:** ✅ code recommendations applied, build-verified, committed. Device Instruments pass folds into V2-S4-F4 (post-art) per the audit's own follow-up #4.

---

## 1. Goal restated

Apply the May 11 perf audit's outstanding recommendations: (1) art-slot
resolution caching, (2) trophy date-formatter caching, (3) off-main
remote-image decode + downsampling with `CGImageSourceCreateThumbnailAtIndex`,
converting the `AsyncImage` call sites.

## 2. Findings + files changed (161 insertions, 89 deletions)

**Rec #1 (art-slot caching) was already done.** All three slot enums
(`LessonArtSlot`, `ClassroomLibraryArtSlot`, `ClassroomRewardArtSlot`)
ship a `static resolvedNameCache` populated once per process — it landed
with the art-slot hook commits after the audit was written. Verified,
zero change. The tracker note "caching … not yet applied" was stale.

**Rec #2 (date formatters) — applied:**

| File | What |
|---|---|
| `Views/Trophies/BadgeView.swift` | `formatDate` now uses a `static let` cached `DateFormatter` (was allocating per call inside grid-tile recomputation). |
| `Views/Trophies/TrophyRoomView.swift` | Same fix in `BadgeDetailSheet`'s `formatDate`. |

**Rec #3 (off-main decode/downsample) — applied:**

| File | What |
|---|---|
| `Views/Common/PerformanceOptimizers.swift` | `ImageLoader` rebuilt: no longer `@MainActor`; decode + downsample happen in **one ImageIO pass** (`CGImageSourceCreateThumbnailAtIndex` with `ShouldCacheImmediately` + `CreateThumbnailWithTransform`) on the cooperative pool. The old path decoded the full bitmap on main **and** distorted aspect ratio (`UIGraphicsImageRenderer` drew into a fixed 800×800 rect). `LazyImageView` is now phase-based (`loading`/`success`/`failure`, mirroring `AsyncImage.phase`), takes a `maxPixelSize` cap, uses `.task(id:)` (auto-cancel on disappear), and serves cache hits synchronously. Cache keys include the size cap so a 300px tile decode is never served to a 1600px hero. |
| `Views/Flipbook/CardHeroImage.swift` | `AsyncImage` → `LazyImageView` (1600px cap). Spinner-over-placeholder loading state preserved. |
| `Views/Trophies/TrophyRoomView.swift` | Trophy shelf tile `AsyncImage` → `LazyImageView` (300px cap). |
| `Views/Flipbook/LessonCompleteCelebration.swift` | Celebration trophy `AsyncImage` → `LazyImageView` (400px cap; usually a cache hit from the deck). |
| `Views/Flipbook/ExperimentCardView.swift` | Migrated the one legacy `LazyImageView` call site to the phase API (128px cap for the 32pt drag tile). |

## 3. Acceptance criteria

| Criterion | Met |
|---|---|
| Art-slot resolution cached | ✅ (pre-existing, verified) |
| Formatter allocations out of render path | ✅ |
| Remote decode/downsample off-main | ✅ — `nonisolated async` static funcs run on the global executor; main actor only receives the finished `UIImage`. |
| No `AsyncImage` left on kid surfaces | ✅ — all 3 sites converted (audit named 2; celebration was the same pattern). |
| "No memory warnings on target iPad" | ⏳ device-verified in V2-S4-F4 — but every remote decode is now capped (128–1600px) where previously `AsyncImage` kept full-resolution bitmaps. |

## 4. In-plan vs drift

In-plan. Two notes: (a) rec #1 turned out to be already-landed — half the
tracker's "not yet applied" was stale bookkeeping, now corrected; (b) the
audit's "watch" item about aspect distortion wasn't called out explicitly,
but the old downsampler genuinely stretched non-square images into
800×800 — the ImageIO path fixes that as a side effect.

## 5. Validation

- `xcodebuild … build` → **BUILD SUCCEEDED**, no new warnings on touched files.
- No unit-test surface exists for view-layer loaders (pre-existing gap); the behavioral contract (phase progression, cache keying) is documented in code. Instruments (Time Profiler / Allocations / Core Animation) on hardware folds into V2-S4-F4 per the audit's follow-up #4.

## 6. Reviewer / next-agent notes

- `LazyImageView`'s phase API is intentionally `AsyncImage`-shaped —
  future conversions are mechanical.
- `MemoryWarningHandler.clearCaches()` still empties the image cache
  (the `ImageLoader.clearCache()` same-file extension survived the
  rework).
- Pick `maxPixelSize` ≈ 2× the rendered point size for Retina; the
  cache treats different caps as different entries by design.
