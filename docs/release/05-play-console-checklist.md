# Google Play release checklist

**Confidence note:** the Play policy facts below were gathered during this project's research phase from secondary sources — `support.google.com` and `play.google.com` were blocked by the research environment's network proxy, so nothing here was read from Google's own documentation directly. The high-confidence items (the $25 fee, the 12-tester/14-day rule) had three or more independent sources converging. Treat everything as a map, not the territory: verify each step against the actual Play Console as you reach it, and correct this file when reality differs.

**The one scheduling fact that governs everything:** a personal developer account created after November 2023 must run a closed test with **12 testers, continuously opted in for 14 consecutive days**, before it can apply for production access. That is calendar time on the critical path. Nothing else in this document can shorten it.

---

## Phase 0 — Start now, in parallel with development

None of this needs finished code, and some of it has multi-day turnaround. Doing it while the app is still being built costs nothing and removes it from the critical path later.

- [ ] **Recruit 12 testers.** Real people with Android devices and Google accounts, willing to install the app and *leave it installed* for 14 straight days. Collect the Google account email address each will use — that is what the closed track needs, not their phone number or usual email.
- [ ] **Run the monetisation concept check** with those same people while you have their attention. Describe the free tier (one well-timed reminder per item) against the paid unlock (the escalating ladder plus overdue follow-through), and ask whether that is worth £3–5. This tests the weakest-evidenced assumption in the project — see `docs/product/01-v1-scope.md` §4 — and it costs one extra sentence in a conversation you are already having.
- [ ] **Create the Play Console developer account.** One-time $25 registration fee.
- [ ] **Complete identity verification.** Personal accounts require government-issued photo ID and proof of address. This can take days and blocks everything downstream, so start it early.
- [ ] **Set up a payment profile** and choose local-currency electronic payouts if offered — the payout threshold drops from $100 (wire) to around $1.
- [ ] **Write and host a privacy policy.** A live, reachable URL is a submission requirement. For a local-only app this is short and honest: what is stored, that it stays on the device, that nothing is transmitted. See the caveat below about purchase verification.

---

## Phase 1 — Signing (do once, get it right)

- [ ] **Generate an upload keystore.** Play needs a release build signed with an upload key; the debug key `flutter run` uses will be rejected.
- [ ] **Back the keystore up somewhere you will still have in two years.** Not only in the project folder. Losing it partway through is a genuinely bad day.
- [ ] **Never commit the keystore or its passwords.** Put `key.properties` in `.gitignore` and keep the `.jks` outside the repo entirely.
- [ ] **Enrol in Play App Signing** at first upload. Google then holds the app signing key and your upload key becomes recoverable if lost — which converts "catastrophe" into "support ticket".
- [ ] Wire the signing config into `android/app/build.gradle.kts` so `flutter build appbundle` produces a signed release.

---

## Phase 2 — Store listing

Play requires this before a closed track will accept a build. It can be rough and revised later.

- [ ] App name, short description, full description
- [ ] App icon (512×512), feature graphic (1024×500)
- [ ] Phone screenshots — at least two, and they should show the real app
- [ ] Category and contact details
- [ ] **Content rating questionnaire**
- [ ] **Data Safety form.** For a local-only app this is mostly negative declarations, which is exactly the advantage of the architecture — Play defines "collection" as data leaving the device.
- [ ] **Target audience declaration.** Your users are adults managing their own documents. Declaring an adult audience keeps you out of the Families programme's heavier requirements.

---

## Phase 3 — The closed test

- [ ] **Build an App Bundle**, not an APK: `flutter build appbundle`. Play has required AAB for new apps since 2021.
- [ ] Create a **closed testing** track and upload the bundle.
- [ ] Add all 12 testers by their Google account email addresses.
- [ ] Send them the opt-in link. **Each must actually accept it and install** — an invited tester who never opts in does not count.
- [ ] **Confirm all 12 show as opted in, then note the date.** The 14-day clock starts from continuous enrolment, not from upload.
- [ ] Keep polishing while the clock runs. Uploading new builds to the track does not reset the timer; testers dropping out does.

---

## Phase 4 — Production

- [ ] After 14 days with 12 testers continuously enrolled, **apply for production access**.
- [ ] Answer Google's questions about the app and your testing.
- [ ] Once granted, promote a build to production and submit for review.
- [ ] Budget slack for review turnaround.

---

## Things that bite people

**Sideloaded APKs count for nothing.** Testers must install through Play from the closed track. Emailing your friends an APK builds zero progress toward the gate.

**"Invited" is not "opted in."** The requirement is 12 testers *continuously enrolled*. Recruit more than 12 so a dropout doesn't reset your progress.

**The privacy claim needs care once billing exists.** Purchase verification makes a network call, so "nothing ever leaves your phone" stops being literally true the moment the paywall ships. `developer` flagged this against REQ-15.2 and it is routed to business-analyst — the honest phrasing is about *your renewal data* never leaving the device, which remains true.

**Target API level deadlines recur annually.** Play enforces a minimum target API for new submissions, on a yearly cycle. Miss it and you cannot ship updates until you upgrade.
