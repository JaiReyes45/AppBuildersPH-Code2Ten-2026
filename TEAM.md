# Four-person task allocation

Assign actual names at kickoff. Each person owns a vertical area and an explicit handoff. This plan divides human work; it does not dispatch agents or notify teammates.

| Person | Role | Main tasks | Required handoff |
| --- | --- | --- | --- |
| A | Flutter UI + integration/release lead | Scaffold, navigation, import/list/search screens, image detail/highlights, loading/error states, build configuration, APK packaging, main-branch integration | Shared interfaces by 3 PM; source UI by 7:45 PM; first release APK by 10:15 PM |
| B | Offline image processing | Bundled OCR setup, physical-phone offline proof, image copies/preprocessing, OCR boxes, batch queue, cancellation/retry, exact hash dedupe | OCR contract and sample output by 3 PM; offline proof by 4:30 PM; persistent indexing by 6 PM |
| C | Local data + search | Drift schema/migrations, repositories, exact and keyword search, ranking, optional embedding feasibility spike, vector persistence, incremental updates/deletion, search tests | Repository contract by 3 PM; semantic go/no-go at 4:30 PM; integrated search by 6 PM |
| D | Deadline/reminder + QA/pitch | Explicit date parser, ambiguity confirmation, notification permissions/scheduling, synthetic fixtures, acceptance checklist, pitch/slides, README accuracy, submission preparation | Notification spike by 4:30 PM; reminders by 7:45 PM; QA report by 8:30 PM; materials tonight |

## Suggested code ownership

- A: `lib/app/`, `lib/features/import/presentation/`, `lib/features/search/presentation/`, `lib/features/detail/presentation/`, build/release wiring.
- B: `lib/services/import/`, `lib/services/ocr/`, native OCR dependencies and preprocessing.
- C: `lib/data/`, `lib/services/search/`, `lib/services/embedding/`.
- D: `lib/features/reminders/`, `lib/services/deadlines/`, QA fixtures, docs and pitch.
- Shared models/interfaces: agree together, then A merges changes. Generated database code stays with C; notification native settings stay with D. A coordinates all manifest/build changes to avoid conflicting edits.

## First 45 minutes

1. A creates the Flutter app scaffold in the repository root after this planning commit.
2. All agree the data contract from README and name methods/return types.
3. B produces a real OCR output fixture; C can code ranking/storage against it while B integrates the plugin.
4. D produces synthetic screenshot fixtures containing explicit dates, ambiguous dates, IDs, and no readable text.
5. A creates screens against agreed interfaces. Test stubs must not be shipped as AI results.

## Git collaboration

- Branches: `codex/ui-release`, `codex/offline-ocr`, `codex/storage-search`, `codex/reminders-qa` (or agreed personal branches).
- Small commits and PRs; notify A when a handoff is ready. Avoid four people editing the same screen or dependency manifest.
- A owns dependency additions and lockfile updates; teammates request needed packages early.
- Integrate working slices every 60–90 minutes. Never leave all integration until tomorrow.
- Run `flutter analyze` before merging; run relevant tests when behavior changes.
- Each PR states behavior, verification, offline assets, and known limitations.
- Keep screenshots synthetic. Do not commit passwords, tokens, personal messages, or APK binaries.

## Validation responsibilities

| Area | Implementer | Independent verifier |
| --- | --- | --- |
| Import/OCR and first-run offline assets | B | D |
| Ranking, persistence, deletion | C | B |
| UI/source highlights and release packaging | A | C |
| Dates, reminders, notification permissions | D | A |
| Final airplane-mode demo | All | D runs checklist; A records release commit |

## Final deliverables

- Working Android release APK from a committed/tagged version.
- Private GitHub repository with access arranged according to judging instructions.
- Updated README with real setup steps, implemented features, and limitations.
- Synthetic demo data and a short offline demo recording.
- Slides and completed submission with confirmation before 9:30 AM.

