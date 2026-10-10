# Code2Ten collaborator handoff ? October 10, 2026
## Session 3 known gaps (Oct 10)

1. **Yes stops the scan immediately** — user only sees the accepted image.
   If they want related matches, they must re-run the query and tap No
   repeatedly. Consider a post-accept "Find related matches" button.

2. **Scan cap of 160 images** may not reach all matches on a 600+ gallery.
   Session 4's query-aware priority is expected to help.

3. **Thumbnail OCR at 800px may miss small text** — if Diancie #2/#3 have
   smaller or lower-contrast card names than #1, they wouldn't promote.
   Diagnostic logging to add in Session 4.
## What changed in this commit

SSeeker branding and information/team screen; Balik-inspired UI and magnifier opening; preserved chatbot animations; cleaned greeting/demo controls; gallery search without uploads/picker; structured OCR responses; sentence/typo handling; bundled MiniLM semantic retrieval and confirmed-query memory; ObjectBox vectors and shared-store lifecycle fixes; screenshot-first incremental scan catalog; resized OCR with fallback; stage timing diagnostics; compact gallery folders and persistent frequent-query shortcuts. README now describes the current build rather than mixing historical targets with completed work.

## Update your checkout

Preserve your local changes first, pull main, run `flutter pub get`, and run on an ARM64 Android phone. For the standalone core, run `dart pub get` inside `packages/gallery_helpdesk_ai`. Models/tokenizer and generated ObjectBox files ship in this commit. Keep the installed app data: update the APK rather than uninstalling it.

Do not remove the path_provider_android 2.2.23 pin, replace ObjectBox model IDs, change the application ID, or upgrade native dependencies without device validation. Scan data must remain intact. Model similarity and typo matches remain tentative. Keep source evidence visible.

## Next build priorities and suggested ownership

These are proposed assignments for the team to confirm, not existing commitments.

| Priority / suggested owner | Work | Acceptance evidence |
| --- | --- | --- |
| 1 ? Kyle Israel Concepcion: gallery/OCR | Benchmark metadata, loading, copying, resize, OCR and embedding separately on varied galleries; compare OCR sizes; test additions/edits/deletions and permission changes | Cold/repeat scan timing, OCR accuracy comparison, no unchanged-image OCR, safe cancellation/resume |
| 2 ? Ralph Abaya: search/data | Create synthetic labeled queries for receipts/orders/announcements, paraphrases, typos, Taglish and same-amount distractors; calibrate semantic thresholds and exact constraints; improve change detection/deduplication | Recall/precision and latency report; no wrong amount/ID treated as exact; model/version migration keeps data |
| 3 ? Patrick Gengania: UI/accessibility | Refine folder browsing and empty states; expose safe individual saved-record deletion; screen-reader labels, large text, reduced motion; evaluate persistent recent-find history | Source navigation, clear/history/delete paths and narrow-phone layouts verified; originals preserved |
| 4 ? Guienne Jairo Reyes: release/QA | Configure release signing privately; build ARM64 release; clean-install airplane-mode gallery/OCR/search checks; QA notes and demo | Installed signed release, all permission modes and restart persistence tested, documented limitations and demo |

After these gates: decide whether reminders/notifications belong in the next release. Implement explicit date confirmation and verify real notification delivery before advertising reminders. A generative LLM or visual recognition model is a separate scoped experiment after retrieval quality and scan latency are measured.

## Acceptance checklist

- First install in airplane mode reads permitted local screenshots without model downloads; repeated search reuses cached OCR.
- Full, selected-only, denied, revoked and restored permissions behave clearly.
- Exact IDs/amounts/quoted constraints remain literal; no unsupported fields or random OCR labeled as an exact answer.
- Semantic results and misspellings offer verifiable candidates; no-match and partial indexing remain explicit.
- Add/edit/delete images, interrupt scans, restart and hot restart: no duplicate-store error, lost index or original-photo deletion.
- Folders handle empty and large collections; frequent-search counts persist, repeat and clear correctly; session-only recent finds are accurately described.
- Full tests and analysis pass; device release and accessibility checks recorded. Current baseline: 75 Flutter tests, 25 core tests, clean Flutter analysis and installed Android debug APK.

Use branches and small PRs for the next build. Coordinate changes to `home.dart`, native build files, dependency lockfile and ObjectBox entities/generated IDs. Do not commit personal gallery images, extracted personal text, credentials, private keys or APK binaries.


---

## Issue found Oct 10 — semantic fallback doesn't rescue zero-hit framing words

**Reproduced on:** Samsung A54 (SM-A546E), Android 16, ~600+ gallery items partially indexed.

**Test queries:**

| Query | Result |
| --- | --- |
| `Diancie` | ✅ Instant, correct — keyword path works |
| `screenshit of charizard card` | ✅ Works — typo tolerance and short framing words (`of`, `card`) tolerated |
| `pokemon card called Diancie` | ❌ Triggers endless scan, never resolves |
| `pokemon card called Diancie that I screenshotted in September` | ❌ Same |
| `pokemon card called Diancie` (after partial 600-image scan) | ❌ Same |

**Root cause (narrowed):** The failing query contains `pokemon`, which likely has **zero hits** in the current OCR index (the card says "Diancie", not "Pokemon"). The two-phase search runs keyword/exact-field retrieval first and keeps extending the OCR scan in 40-image passes looking for a token that will never match. The semantic backfill that would understand *"pokemon card" ≈ "Diancie"* is deferred until the OCR loop exhausts — which, on a 1,000+ image gallery, effectively never happens.

The typo test proves the parser and matcher work when tokens are findable. The failure is specifically about **zero-hit tokens blocking semantic fallback.**

**Requested change (Priority 2 — search/data):**

1. **Early semantic fallback:** if any keyword token returns zero hits in the current index, immediately run a bounded semantic pass for the whole query rather than scanning deeper.
2. **Framing word stripping:** expand the existing stop-word list to include `called`, `named`, `that I screenshotted`, `the one where`, `show me`, `find me`. ("of" and "card" already appear to be handled.)
3. **Cap on scan extension:** consider capping total scan extension per query at, say, 3 batches (120 images) before forcing semantic fallback and returning whatever candidates exist, rather than scanning indefinitely.

**Acceptance test:** `pokemon card called Diancie` must return the Diancie screenshot without scanning beyond the current index depth on a 600+ image gallery.

**Impact:** Compound natural-language queries are the primary UX judges will try. The `screenshit of charizard card` result shows the pipeline *can* work — the gap is specifically zero-hit framing words.

**Workaround for demo:** Tap **This is the one** on a `Diancie` result once, then re-run the compound query — memory should short-circuit the scan. (Not yet verified.)


---

## Follow-up needed — zero-hit short-circuit doesn't trigger semantic search

**Found by Kyle on branch `fix/zero-hit-semantic-fallback`, Oct 10.**

**What works on this branch:**
- `Diancie` → 3 results, instant ✅
- `screenshit of charizard card` → 1 result, instant ✅
- Scan cap at 3 extensions (160 images max) works ✅

**What still fails:**
- `pokemon card called Diancie` → still scans, doesn't return the Diancie card
- `unicorn dragon` (no matching images) → returns WHITECLOAK photos (neither word in OCR)

**Root cause (probable):**
The short-circuit at `home.dart:494-503` calls `_searchWith(parsed, dateHint)` with default `prepareSemantic: true` (line 609). But `_searchWith` appears to run semantic retrieval against *currently computed* embeddings, while prep at line 683 (`prepareMissing: prepareSemantic`) is queued asynchronously. So the search returns before prep completes — finds nothing — and the outer loop falls through to scanning.

**Requested fix (Priority 2 — search/data):**
1. Await semantic prep before running the search inside the zero-hit short-circuit branch (or return after prep completes and re-search).
2. Fix `nearWord` fuzzy matching so `unicorn` / `dragon` don't spuriously match `WHITECLOAK`.
3. Verify `pokemon card called Diancie` returns the Diancie card without further scanning on a 600+ image gallery.

**Branch context:** `fix/zero-hit-semantic-fallback` at commit [push hash]. Preserve `card`/`cards` as context words (`_contextWords` in `search_service.dart`); do not re-add the parser-level stripping.