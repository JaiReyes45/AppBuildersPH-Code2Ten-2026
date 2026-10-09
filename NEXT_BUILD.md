# Code2Ten collaborator handoff ? October 10, 2026

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
