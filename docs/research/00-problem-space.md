# Problem space research — renewal-reminder v1

Prepared by: researcher
Date: 2026-08-20
Method: live web search (see Sources). `play.google.com`, `apps.apple.com`, and `support.google.com` were blocked by the network egress proxy for direct fetches; all Play/App Store app claims below come from search-engine snippets of store listings, not verified live pages, and install counts/ratings could not be confirmed at all — flagged per claim below.

Routed to: product-manager (scope calls), ux-designer (design implications).

---

## 1. What already exists

**Confidence: moderate.** Based on search-snippet descriptions of store listings, not verified live pages (Play/App Store fetch blocked). No install counts or star ratings were retrievable through this proxy for any competitor — that's a real gap, not a "no data" finding; product-manager should treat exact market size as unknown rather than assume it from this brief.

**Competitor pattern — the "all-in-one" sub-category already exists and is not empty.** Several apps already claim to do documents + warranties + vehicle + subscriptions in one place:
- **Document Expiry Reminder** (Android) — passport, driver's licence, insurance, warranties; local-only, no account.
- **Renewly: Expiry Tracker** (Android, two listings found: `com.dev.renewly` and `com.renewly.datesanddocs.app`) — documents, warranties, subscriptions, medicines, vehicle records, insurance, licences, offline.
- **Doc Reminder: Expiry Tracker** (Android) — vehicle documents, insurance, loans, personal records, offline.
- **Expira: Expiry Date Tracker** (Android) — barcode + expiry-date scanning, passport/visa/ID/licence + insurance/warranties/subscriptions/contracts.
- **DocuAlert** (Android) — general document expiry tracking.
- **Expiro App**, **ExpiNotif**, **Expiry Date Tracker Pro** (iOS) — same general shape: multi-document, local storage, no account, staged reminders (e.g. Expiro: 30/7/1 days before).
- **Doqit** and **Life Admin Automation System** — broader "life admin" framing that folds renewals in alongside bills, appointments, subscriptions.
- **Travel Document Vault** (cross-platform) — narrower than full "all documents" but notably close to a plausible v1 shape: passport/visa/ID only, offline, no cloud, no account, family profiles, and a staggered reminder ladder at 6 months / 3 months / 6 weeks / 2 weeks / 1 week before expiry.

**Competitor pattern — single-purpose apps are also common and UK-vehicle-specific.** Autodue, PitSync, Car Remind, CarFile, AutoMate AI, "Road Tax & MOT Check," DVLA Tax Check — all UK-only, vehicle-only (MOT/VED/tax/insurance), several pulling live MOT/tax data via DVLA lookups (a capability a local-only, document-agnostic app won't have). Separately, warranty-only apps are their own cluster: Warranty Tracker, WarrantyTrackr, Warranty Keeper, Warranty Receipt Tracker, Garanto, Warranty Tracker: Bill Manager — several with receipt-photo/scan storage as the core feature, not just a date field.

**So what:** the space is fragmented *and* the all-in-one niche is already occupied by a handful of small, seemingly low-differentiation apps. "Nobody does the whole category" is not a safe positioning claim — several already attempt it. The actual open question for product-manager is not "does an all-in-one exist" but "why would someone pick this one over Document Expiry Reminder / Renewly / Doqit" — likely on execution (cadence quality, low-friction entry, trust signaling) rather than category coverage. UK vehicle compliance (MOT/tax) is already well served by apps that do live DVLA lookups, which a local-only app structurally cannot match — this is a case for de-scoping deep vehicle-compliance data-pulling from v1, not for building it.

**Monetization — competitor pattern, low confidence (general industry data, not these apps specifically):** general app-monetization research suggests low-frequency utility apps favor one-time purchase or a light IAP over subscription; several of the named competitors advertise as free/offline with no visible ads copy, but actual pricing (free, ad-supported, one-time, subscription) could not be confirmed for any specific competitor because their store pages weren't reachable. This is directly relevant to the project's existing one-time-unlock assumption but does not independently confirm it — flag as unconfirmed, not validated.

---

## 2. The central objection: why not just use a calendar?

**Established practice / research finding — reminders fail for reasons beyond "forgetting."** Classic prospective-memory research (Einstein & McDaniel-lineage work, and later replications) found that reminders which name only the target event, without tying it to an intended action or moment, don't reliably improve follow-through versus no reminder at all — the effective ingredient is linking *what* to do with *when/where* you'll be able to act on it, not just surfacing a date. Source: prospective memory literature summarized via Springer/PubMed and Frontiers in Psychology reviews (see Sources). This is a real, citable psychological finding, not marketing copy.

**Competitor/vendor pattern, moderate confidence — the "calendar events get dismissed and nothing happens next" argument is real but comes mostly from vendor blogs (yougot.ai, licenselogic.co) making the case for buying a reminder tool, so treat as motivated reasoning, not independent research.** The substantive point that does hold up independently: a calendar event, once dismissed or the day passes, leaves no trace and has no escalation — there's no second nudge, no "you still haven't renewed this" follow-up. That structural gap (no escalation, no persistent nag state) is a legitimate mechanical difference between a calendar and a purpose-built tracker, independent of who's saying it.

**Established fact — quantified reminder fatigue exists and cuts both ways.** Business of Apps data (cited across multiple secondary sources) puts push notification opt-in around 60% with reaction rates near 4.6% (Android) / 3.4% (iOS); separate survey data (WiserNotify, Helplama, secondary-sourced) suggests a meaningful share of users disable notifications or uninstall an app after roughly 2–6 unwanted notifications per week. This cuts against a naive "just remind them more/earlier" answer to the calendar objection — a dedicated app that nags more than a calendar does could get uninstalled faster than a calendar gets ignored.

**Gap — could not find real forum/review voices.** Direct search for user-voice evidence (people describing forgetting a renewal despite a calendar reminder, or explicitly preferring a dedicated app) mostly surfaced vendor content marketing (yougot.ai blog posts, app landing pages) rather than organic forum posts or App/Play Store review text — the review text itself was unreachable through this proxy (store pages blocked), and reddit.com results did not surface usable organic threads for this query. **This is a real evidentiary hole, not a settled "calendar is fine" finding or a settled "people hate calendars" finding — say so plainly to product-manager rather than picking a side without evidence.**

**So what — is the calendar objection answerable?** Partially, and with real limits stated up front:
- The psychological case for *why* a bare calendar entry underperforms (no action-binding, no escalation, gets dismissed once and forgotten) is legitimate and citable.
- But the same fatigue data that undercuts calendars also caps how much a dedicated app can lean on notification volume as its answer — "more reminders" is not automatically a win, and could itself get the app uninstalled.
- No direct organic evidence (forum posts, reviews) was found either confirming that real users have been burned by calendar-only tracking for these specific document types, or confirming they'd pick a dedicated app over it. Product-manager should treat "the app's answer is cadence design, not just being a separate app" (already in the project's known constraints) as the right instinct, but shouldn't assume the objection is fully rebutted by evidence gathered here — the strongest honest answer is "a well-designed escalating cadence with follow-through state (done/not done) is mechanically different from a calendar event and there's a real psychological argument for why that matters," not "users have told us calendars fail them."

---

## 3. What people actually forget, and what it costs them

**Established fact, UK-specific, high consequence — MOT.** Driving with no valid MOT (where required) is a criminal offence under the Road Traffic Act 1988 s.47; no grace period exists. Fixed penalty ~£100 on the spot, up to £1,000 maximum fine if prosecuted, and it can also invalidate insurance. Enforcement is largely automated now — ANPR cameras cross-check live DVSA MOT, DVLA vehicle, and Motor Insurance Database records, so being caught isn't dependent on being stopped. Source: motoring-law and insurer summaries (Compare the Market, MoneySuperMarket, MOTCost.com, CPS) — treat trade/insurer sites as reasonably reliable for stated penalty figures but not as primary legal sources.

**Established fact, UK-specific, high consequence — driving without insurance.** Third most common UK motoring offence by volume, with figures cited around 22,000 drivers caught (source didn't specify time period — treat as an order-of-magnitude figure, not a precise annual stat). Fixed penalty £300 + 6 points, or unlimited fine and possible disqualification if it goes to court. UK law requires continuous insurance while a vehicle is kept on public roads (not just "while driving").

**Established fact, geography-agnostic but timing-critical — passport renewal.** US State Department data (cited via secondary press coverage, 2026) reports a record 27.3 million passports issued in 2025, with routine processing at 4–6 weeks plus mail time, and repeated official/travel-industry guidance to renew with 12+ months of validity remaining (many destinations deny boarding or entry with less than 6 months' validity remaining — a widely cited but not independently re-verified rule here). This is the clearest case in the whole research set for "months, not days" lead time being the right cadence — a short-notice reminder is close to useless for a passport given processing time alone.

**Established fact, US-specific, real but slower-moving consequence — professional licence/certification lapse.** Multiple state nursing-board and legal-summary sources confirm: a lapsed licence immediately disqualifies someone from practicing, employers must stop assigning licensed work, and reinstatement after a lapse typically requires back continuing-education hours, fees, and in some cases (e.g., California RN, lapse >8 years) exam retake or interstate verification. Consequence severity scales with how long the lapse runs, unlike MOT/insurance where the first day of lapse is already a criminal exposure.

**Geography flag for product-manager:** MOT/vehicle tax is UK-only; the specific insurance/MOT ANPR enforcement mechanics don't generalize. US passport lead-time guidance and US professional-licence renewal mechanics are US-specific (state-by-state for licences). Warranty expiry has no regulatory consequence anywhere — it's a pure financial-loss category (missed repair/replacement window), which is a different, lower-stakes kind of "cost" than a fine or a criminal offence. This split (regulatory/legal risk vs. pure financial-loss risk) is a real difference in urgency that v1 scoping should account for — it wasn't previously called out in the project's known constraints.

---

## 4. The reminder cadence problem

**Competitor pattern, moderate confidence — staggered, document-type-aware cadence is already the norm among direct competitors,** not a novel idea:
- Autodue (UK MOT/tax): 60, 30, 14, 7 days before.
- DVLA Tax Check (UK, third-party service): 45, 21, 14, 7, 4 days before.
- Travel Document Vault (passport/visa/ID): 6 months, 3 months, 6 weeks, 2 weeks, 1 week before.
- Expiro App (general documents): 30, 7, 1 days before.

The pattern across these: longer-lead-time document types (passport) get a reminder ladder that starts many months out; short-lead-time types (vehicle tax, MOT) start at 30–60 days. No source gave an explanation of *why* those specific numbers were chosen (no A/B data, no stated rationale) — treat these as competitor convention, not validated optimal cadence.

**Established fact — reminder fatigue thresholds are quantified, if imprecise.** Business of Apps and secondary survey sources (WiserNotify, Helplama) converge on: roughly 2–6 unwanted push notifications per week is enough to make a meaningful share of users disable notifications entirely, and a further slice will uninstall the app. Exact percentages varied by source (one source's 46%/32% figures for disable/uninstall at "6+ notifications" specifically should be treated as directional, not precise, since it traces to marketing-oriented aggregator content rather than a named primary study). **So what:** a naive "remind early and often for every item" design risks the app itself becoming the fatigue trigger, especially once a user has more than a handful of tracked items each generating their own multi-stage ladder.

**Established platform constraint — Android exact-alarm scheduling changed materially in Android 13/14 and matters directly here.** Per Android Developers documentation: `SCHEDULE_EXACT_ALARM` is no longer pre-granted by default to apps targeting Android 13+ when installed fresh on Android 14+ devices (calendar/alarm-clock apps are exempted from this default-deny; a generic reminder app is not, unless it qualifies for a listed exemption). The app must call `canScheduleExactAlarms()` and, in the general case, get explicit user grant via a settings redirect — this is a real, user-facing extra permission step beyond the notification runtime permission already noted in the project's known constraints. Source: developer.android.com (official, high confidence).

**Established platform constraint — Doze/App Standby can delay non-exact scheduled work.** Per Android Developers and AOSP docs, Doze defers standard alarms, jobs, and network access while idle, opening periodic "maintenance windows" to catch up — this mainly affects *inexact* alarms/jobs and background sync, less so alarms explicitly scheduled as exact (which are one of the few things designed to fire through Doze). The practical risk for this app is specifically about the exact-alarm permission gate above, not primarily about Doze deferring an already-scheduled exact reminder — worth developer confirming directly against current Android docs before implementation, since this is a fast-moving area of the platform and secondary sources here were mixed in precision.

**So what:** the project's existing known-constraint about the Android 13+ notification runtime permission is necessary but not sufficient — the exact-alarm permission gate is a second, separate permission surface specifically relevant to an app whose entire premise is scheduling far-future notifications reliably. This is a concrete technical risk for developer to scope, not something to discover at implementation time.

---

## 5. Onboarding and data entry

**Competitor pattern, moderate confidence — OCR/scan-to-fill is a common feature claim among named competitors,** not a novel idea: Expira ("barcode + expiry-date scanning"), WarrantyTrackr ("AI-assisted... store invoices and receipts"), several warranty-tracker apps offering receipt-camera capture as a core feature. None of the sources found described how well this actually works in practice (accuracy, failure modes, how much manual correction is typically needed) — this is a claimed feature pattern, not a validated one.

**Speculative/trend idea, no strong precedent found specifically for this document category:** on-device OCR (rather than cloud OCR) to extract a printed expiry date from a passport photo page, MOT certificate, or warranty card, keeping extraction local-only. This would be consistent with the project's local-only architecture, but no competitor source described their OCR as explicitly on-device vs. cloud-based — worth developer/ux-designer treating as an open technical question, not an assumed feature.

**Competitor pattern, low-to-moderate confidence — presets/categories as the low-effort entry point.** Several competitors (Renewly, Doc Reminder, Document Expiry Reminder) describe organizing around named document-type categories (passport, licence, insurance, warranty, etc.) in their marketing copy, which functions as an implicit template — pick a type, get a sensible default form/icon/cadence — rather than a blank generic "add item" form. No source described a first-run wizard, bulk-import, or empty-state-specific onboarding flow in enough detail to call this an established pattern beyond "categorized entry types exist."

**Realistic-for-local-only note (not a design recommendation):** import from existing calendar events or contacts was not observed as a stated feature in any competitor found, and would be a meaningfully bigger technical/privacy scope item (reading another app's data) than scan-to-fill or category presets — worth ux-designer/product-manager treating any import idea as speculative and out of the "cheap to build" bucket unless separately researched.

---

## 6. Trust and privacy positioning

**Established platform fact — the project's local-first architectural argument is confirmed by Google's own definition.** Per Google Play Console Help (support.google.com, indexed content reached via search snippet — direct page fetch was blocked by the proxy, so treat this as search-engine-cached confirmation rather than a verified live read): Play's Data Safety section defines "collection" as data transmitted off-device; data accessed and stored only on-device does not need to be disclosed as "collected." This directly supports the project's existing known constraint that local-only storage shrinks the Data Safety disclosure surface — now confirmed independently rather than inherited only from prior research.

**Competitor pattern, high frequency — "no cloud / no account / offline" is the dominant trust claim across nearly every named competitor in this space,** not a differentiator: Document Expiry Reminder, Doc Reminder, Renewly, Expira, Expiro, Travel Document Vault, and the warranty-tracker cluster all lead with local-only/no-account/offline-first messaging in their own descriptions. **So what for product-manager:** "everything stays on your phone" is table stakes positioning in this category already, not a novel pitch — it may still be necessary to state, but it won't differentiate this app from its nearest competitors, most of whom already say the same thing.

**Gap — no organic user-voice evidence found on whether people actually respond to that claim versus just not caring.** Search did not surface independent reviews, forum posts, or survey data specifically about users choosing (or not choosing) a document-tracking app *because* of its local-only claim, as opposed to general privacy-app commentary (password managers, LLM chat apps) that isn't about this category. The general "privacy-first apps reduce anxiety, users don't trust cloud services with sensitive data" framing found in search results traces mostly to privacy-tool marketing sites (localfile.tools, zerocloudapps.com, voicescriber.com) rather than independent research — treat as speculative/vendor-asserted, not established, when it comes to *this specific claim actually driving downloads or retention* for a renewal-tracker app. The developer-facing benefit (smaller Data Safety disclosure, confirmed above) is solid; the user-facing marketing benefit ("users choose apps because of this claim") is not independently confirmed here.

---

## Sources

External research (with confidence caveats noted inline above):
- [Document Expiry Reminder – Google Play](https://play.google.com/store/apps/details?id=com.ilyas.ilyasapps.documentexpiry&hl=en) (snippet only, page fetch blocked)
- [DocuAlert – Google Play](https://play.google.com/store/apps/details?id=com.docualert.documents_expiry_reminder) (snippet only)
- [Renewly: Expiry Tracker – Google Play](https://play.google.com/store/apps/details?id=com.dev.renewly) (snippet only)
- [Doc Reminder: Expiry Tracker – Google Play](https://play.google.com/store/apps/details?id=com.docureminder) (snippet only)
- [Expira: Expiry Date Tracker – Google Play](https://play.google.com/store/apps/details?id=com.expiraapp.app&hl=en_US) (snippet only)
- [Warranty Tracker family – Google Play search results](https://play.google.com/store/apps/details?id=com.sweekwang.warranty_tracker&hl=en) (snippet only, several similar listings found)
- [Autodue MOT & Tax Reminders](https://autodue.co.uk/mot-and-tax-reminders)
- [PitSync MOT Reminder App](https://www.pitsync.com/mot-reminder-app-uk)
- [CarFile Vehicle Tax Reminder](https://carfile.app/tax-reminder/)
- [DVLA Tax Check](http://dvlataxcheck.uk/)
- [Doqit – life admin app](https://www.doqit.io/life-admin-app)
- [Life Admin Automation System – Google Play](https://play.google.com/store/apps/details?id=com.uikey.lifeadminautomationsystem&hl=en) (snippet only)
- [Travel Document Vault – AlternativeTo](https://alternativeto.net/software/travel-document-vault/about)
- [Expiro App – App Store](https://apps.apple.com/mx/app/expiro-app/id6758278098) (snippet only)
- [Passport.app](https://www.passport.app/)
- [What Happens If I Forget to Tax My Car? – Compare the Market](https://www.comparethemarket.com/car-insurance/content/forget-to-tax-mot-car/)
- [What if I forget to renew my car insurance, tax and MOT? – MoneySuperMarket](https://www.moneysupermarket.com/car-insurance/forgetting-to-tax-mot-insure/)
- [Driving Without MOT Fine – MOTCost.com](https://motcost.com/driving-without-mot-fine)
- [Driving offences – CPS](https://www.cps.gov.uk/types-crime/driving-offences)
- [Driving Without Insurance – Allen Hoole](https://www.allenhoole.co.uk/services/road-traffic-offences/no-insurance/)
- [What's changing about US passport processing in 2026 – MSN/travel press](https://www.msn.com/en-us/travel/news/what-s-changing-about-us-passport-processing-in-2026-and-the-specific-timelines-every-american-needs-to-know/ar-AA23j1X5)
- [Why Passport Wait Times Are Still Long in 2026 – RushMyPassport](https://www.rushmypassport.com/blog/why-are-passport-wait-times-still-long-in-2026/)
- [Lapsed Professional License: Consequences and Reinstatement – LegalClarity](https://legalclarity.org/lapsed-professional-license-consequences-and-reinstatement/)
- [California Board of Nursing – License/Certificate Renewal](https://www.rn.ca.gov/licensees/lic-renewal.shtml)
- [Prospective memory: when reminders fail – PubMed](https://www.ncbi.nlm.nih.gov/pubmed/9584436)
- [Prospective memory: When reminders fail – Springer/Memory & Cognition](https://link.springer.com/article/10.3758/BF03201140)
- [Frontiers in Psychology – Prospective memory assessment](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2022.958458/full)
- [Push Notification Statistics – WiserNotify](https://wisernotify.com/blog/push-notification-stats/)
- [Push Notifications Statistics – Business of Apps](https://www.businessofapps.com/marketplace/push-notifications/research/push-notifications-statistics/)
- [What do Consumers Think About Push Notifications – Helplama](https://helplama.com/what-do-consumers-think-about-push-notifications/)
- [Schedule exact alarms are denied by default – Android Developers](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms)
- [Schedule alarms – Background work – Android Developers](https://developer.android.com/develop/background-work/services/alarms)
- [How Android 13's new restrictions on alarm APIs will improve battery life – Esper](https://www.esper.io/blog/android-13-exact-alarm-api-restrictions)
- [Optimize for Doze and App Standby – Android Developers](https://developer.android.com/training/monitoring-device-state/doze-standby)
- [Platform power management with Doze – AOSP](https://source.android.com/docs/core/power/platform_mgmt)
- [Provide information for Google Play's Data safety section – Play Console Help](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en) (search-snippet confirmed only, direct fetch blocked)
- [Understand app privacy & security practices – Google Play Help](https://support.google.com/googleplay/answer/11416267?hl=en&co=GENIE.Platform%3DAndroid) (search-snippet confirmed only, direct fetch blocked)

Blocked/unreachable for direct verification during this research (per environment constraints): `play.google.com`, `apps.apple.com`, `support.google.com` — all app store install counts, ratings, review text, and pricing details above are therefore search-snippet-derived, not independently verified against live pages. Organic Reddit/forum threads did not surface usable content for the calendar-objection query; that section is flagged as an evidentiary gap rather than answered from a single unverifiable source.
