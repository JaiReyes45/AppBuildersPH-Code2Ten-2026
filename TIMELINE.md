# Delivery timeline

All times are **Asia/Manila (UTC+8)**. Planning baseline: October 9, 2026, approximately 2:15 PM. Deadline: **October 10, 2026, 10:00 AM**. About 19 hours 45 minutes remain, including rest and submission buffer.

Target an installable complete MVP tonight. Tomorrow is for regression, packaging, and submission. This is an aggressive schedule for four people; visual search and large-model features are outside the required scope.

## Friday, October 9

| Time | Steps | Owners | Exit criterion |
| --- | --- | --- | --- |
| 2:15–2:30 PM | Confirm judging rules, submission format, private repo visibility, Android demo phone, and available teammates. Choose synthetic GCash-like receipts, order screenshots, student announcements, and unrelated gallery images with known answers. | All; D checks rules | Required AI/offline criteria recorded; target phone connected. |
| 2:30–3:00 PM | Create Flutter scaffold; pin dependencies; commit lockfile. Agree data models and service signatures. Add navigation and interfaces. Assign branches. | A leads; all agree contracts | Everyone runs the same app; interfaces merged to main. |
| 3:00–4:30 PM | A builds gallery/helpdesk/list/detail UI; B enumerates permitted gallery assets and proves bundled OCR on fresh offline install; C implements ObjectBox repository, exact fields and keyword ranking while separately spiking embeddings; D builds helpdesk response templates, reminder/notification spike and test fixtures. | A/B/C/D in parallel | OCR works offline; search/storage prototype; reminder delivered. |
| **4:30 PM checkpoint** | Decide whether semantic search passes device, memory, tokenizer, latency, and offline checks. Review judging requirements. Drop it from delivery scope if it fails unless mandatory; adjust scope explicitly. | C reports; all decide | Written feature decision; working keyword search remains. |
| 4:30–6:00 PM | Wire app-owned image copies, OCR blocks, indexing progress, persistent storage, and search UI. Add candidate order/receipt/announcement fields, deletion and exact duplicate handling. | A+B+C; D verifies | End-to-end import -> OCR -> search -> source view on main. |
| 6:00–6:30 PM | Meal break; stagger if necessary. Review blockers and remaining scope. | All | No unowned blocker. |
| 6:30–7:45 PM | Map OCR boxes to image preview; add explicit deadline candidate parser and editable confirmation. Integrate reminder service. Add optional proven semantic backend. | A source UI; B OCR; C search; D reminders | Find -> verify -> act works in airplane mode. |
| 7:45–8:30 PM | First full integration checkpoint. Restart persistence test, cancel/denied import, no-text image, ambiguous dates, notification denied, and deletion. Fix blockers. | All; D coordinates | HP-01–HP-12 exercised; failures logged with owners. |
| 8:30–9:30 PM | Handle indexing interruption, bounded batches, error states, empty search, and permission messaging. Test search examples against labeled fixtures. | A/B/C; D retests | Demo fixtures produce verifiable results; no crash on major edge cases. |
| 9:30–10:15 PM | Build first release APK; install fresh on phone offline. Check native/model assets in release, image permissions, reminders, and persistence. | A release; B/C runtime; D QA | First usable release artifact exists. |
| **10:15 PM feature freeze** | Stop adding features. Record known limitations. Only fix correctness, stability, and demo blockers. | All | Feature list matches actual implementation. |
| 10:15–11:00 PM | Prepare 3–5 slides: problem, workflow, on-device architecture, offline proof, limitations. Record a short backup demo using synthetic data. Update README and installation steps. | D pitch; A recording; B/C docs | Backup demo and draft submission materials ready. |
| 11:00–11:30 PM | Run targeted tests/analyzer; merge final blockers; tag release candidate. Make next-morning fix list and verify repo access for judges. | All | Reproducible release candidate; clean working tree. |
| 11:30 PM–6:30 AM | Rest. Charge demo phone and laptop; keep release artifact and recording available locally. No mandatory overnight feature work. | All | Team returns with a working baseline. |

## Saturday, October 10

| Time | Steps | Owners | Exit criterion |
| --- | --- | --- | --- |
| 6:30–7:15 AM | Fresh install/restart regression on the target phone; repeat critical offline paths. Test notification delivery. | D leads; all fix assigned issues | Only documented minor limitations remain. |
| 7:15–8:00 AM | Resolve release blockers; run analyzer and targeted tests once after final edits. Produce final release APK. | A+B+C; D verifies | Final artifact built from committed source. |
| **8:00 AM code freeze** | No new features. Keep the known-good APK. Changes after this point require a demonstrated submission blocker and a full affected-path retest. | All | Commit/version identified. |
| 8:00–8:45 AM | Rehearse 3-minute demo; record final backup. Finalize slides, README, model attribution, build/install instructions, and limitations. | D leads | Pitch makes accurate feature claims. |
| 8:45–9:15 AM | Upload deliverables; test download/install and repository permissions. Grant judge access if required and authorized. Fill submission fields. | A artifacts; D submission | Reviewer can access every required deliverable. |
| 9:15–9:30 AM | Submit and capture submission confirmation. | D submits; A verifies | Submission accepted before buffer starts. |
| 9:30–10:00 AM | Buffer for upload delays, access issues, or form corrections. Keep internet available for submission, while product demo remains offline. | All available | Deadline met. |

## Critical path

1. Rules and phone validation.
2. Shared contracts and scaffold.
3. Bundled offline OCR.
4. Permitted gallery scan, ObjectBox index, and extracted field candidates.
5. Helpdesk results for orders, GCash-like receipts and announcements, with source verification.
6. Confirmed local reminders.
7. Fresh offline release verification.
8. Accurate demo materials and accessible submission.

## Scope cuts if delayed

- At 4:30 PM: remove unproven semantic search; keep OCR AI and keyword search, subject to judging rules.
- At 6:00 PM: keep foreground paged gallery scanning and selected-photo fallback; remove continuous background scanning.
- At 8:30 PM: remove grouping, collections, and cosmetic animations. Never remove honest error states or source verification.
- At 10:15 PM: no extra model integration; retain evidence templates if Gemma is unproven. Preserve the working release.
- If reminders fail: clearly label the limitation and keep a confirmed in-app deadline list. Do not demonstrate a fake notification or claim delivery. Decide whether the fallback still meets submission rules.


## Updated scope checkpoints

- This remains the original delivery baseline; completed/past blocks are not claims of implementation. If starting later, collapse setup time, preserve release/submission buffers, and cut optional models first.
- By the model checkpoint, verify ObjectBox persistence and gallery enumeration alongside bundled OCR. Semantic retrieval and Gemma are independently gated; never delay exact identifier search for them.
- By integration, the helpdesk must answer one order-number request, one GCash-like receipt request, and one announcement request with real screenshot evidence.

