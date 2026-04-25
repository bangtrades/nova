import Foundation

/// S12-12 — Generic envelope wrapper for paginated list responses.
///
/// The Nova backend wraps every list endpoint in a `{ data, total, ... }`
/// envelope (varies by endpoint — `/lessons` adds `page`/`limit`/`totalPages`,
/// `/paths` adds just `total`, etc.). iOS only ever needs the `data` array;
/// the count/pagination metadata is consumed by the Dev Console and any
/// future infinite-scroll surface, but not the current Tier 1 VMs.
///
/// This wrapper lets `APIRouter`'s `fetch*` methods stay typed as `[Lesson]`,
/// `[LearningPath]`, etc. by decoding the envelope internally and returning
/// the bare array. Callers don't see the envelope at all.
///
/// ## Why a custom struct instead of a tuple or anonymous decode
///
/// Tuples can't be `Decodable`. Anonymous decode (e.g.
/// `decoder.decode([String: Any].self)`) loses the type-safe T binding.
/// A named generic struct preserves the per-endpoint element type all the
/// way through, so the compiler still catches mismatches between e.g.
/// `[Lesson]` and `[LearningPath]`.
///
/// ## Why `data` is the only non-optional field
///
/// Different endpoints return different metadata shapes:
/// - `/lessons` ships `{ data, total, page, limit, totalPages }`
/// - `/paths`   ships `{ data, total }`
/// - `/badges`  ships `{ data }` (just the array)
///
/// Codable ignores wire keys it doesn't know about, so a struct with only
/// `data` decodes cleanly against all three shapes. If a future caller
/// needs `total` (e.g., to render a count badge), add it as an optional
/// `public let total: Int?` here without breaking existing callers.
public struct PaginatedResponse<T: Decodable>: Decodable {
    /// The actual array of resources for this page.
    public let data: [T]
}
