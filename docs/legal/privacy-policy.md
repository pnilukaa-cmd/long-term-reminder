# Privacy Policy — renewal-reminder

**Last updated: 23 August 2026**

## The short version

renewal-reminder stores the renewal dates, labels, and notes you enter — insurance, MOT, passport, licence, warranty, health check, and anything else you add — entirely on your own phone. We don't have a server that holds your data, we don't ask you to create an account, and we don't share, sell, or analyze what you track. The only thing that ever leaves your device is a purchase-verification check with Google Play if you buy the one-time unlock — and that check doesn't include any of your renewal data. Details below.

## What this app stores, and where

Everything you enter into renewal-reminder — item types, labels, due dates, notes, the reminder intervals you set, and whether you've marked something done — is saved in a database that lives only on your phone. It is never uploaded, synced, backed up to a cloud service, or transmitted anywhere. There is no account to create and no server for this app to talk to for any of that data.

This also means: if you uninstall the app, or lose or reset your phone, that data is gone unless you've backed it up some other way (for example, your phone manufacturer's own device backup, which we don't control and don't participate in). We're saying this plainly because "local-only" is a real trade-off, not just a privacy feature — nothing about this app can recover that data for you.

## Health check reminders

One of the seven renewal types you can track is "Health check" — a general-purpose reminder for things like a physical, a dental checkup, an eye test, or a vaccination booster. To be clear about what this does and doesn't mean:

- The only information stored for a Health check item is whatever you type in yourself — a label you choose, a date you choose, and a reminder interval you choose. The app doesn't ask about, store, or infer anything about your actual health, diagnosis, medical history, or medications.
- This isn't sourced from, or connected to, any health record, health app, wearable, or healthcare provider. It's the same plain reminder mechanism used for every other type in this app — insurance, passport, vehicle, and so on — just with a label that happens to be about a checkup.
- We don't treat this as, and you shouldn't treat this as, medical data in any regulatory or clinical sense. It stays on your device with everything else, under the same local-only handling described above — nothing about it is transmitted anywhere or looked at by anyone, including us.

## What we don't do

- No account or sign-in.
- No analytics, crash-reporting, or advertising SDKs that track your usage or your device.
- No ads.
- No sharing or selling of any data to anyone — there's no data leaving your device to share in the first place.
- No access, by us, to what you've entered. We built the app; we don't have a way to see inside your copy of it.

## The one thing that does involve a network call: buying the unlock

renewal-reminder offers a one-time paid unlock (the full reminder schedule and overdue follow-through, instead of the single free reminder per item). When you buy it, that purchase is handled directly by Google Play's own billing system, and your device checks in with Google's servers to confirm the purchase went through and stays valid.

Two things worth being precise about, so this section doesn't quietly go stale as the app changes:

- **This is the only network call this app makes that we're aware of shipping.** It exists to verify that a purchase happened — it is not your renewal data. Your items, labels, due dates, and notes are never included in it and never leave your device as part of it. Everything described in the sections above stays true even with this in place.
- **We (the developer) never see your payment details.** Your card details, billing address, and everything else about the transaction are handled entirely by Google Play, under Google's own privacy policy — not ours. We receive confirmation that an entitlement exists, not your payment information.

If a future version of this app ever adds a feature that sends renewal data anywhere — which isn't planned — this policy would be updated first, and that update would say so plainly, in this same section, rather than being buried elsewhere.

## Permissions this app asks for, and why

- **Notifications** — so the app can actually remind you. If you say no, the app still works for tracking and viewing status; you just won't get pushed reminders until you turn this on, either in the app or in your phone's settings.
- **Run at startup / receive boot events** — so your reminders get correctly re-armed after your phone restarts, without needing you to reopen the app first.
- **Keep the device briefly awake for background checks** — used only so the app's own periodic check-in (which re-confirms your reminders are still correctly scheduled) can finish running; not used to keep your phone awake generally.

None of these permissions give the app, or us, access to anything beyond what's needed to schedule and deliver your own reminders on your own device.

## A limit worth knowing about

Android cancels an app's pending reminders if you force-stop it, and won't run them again until you open the app yourself — this is how Android works for every app, not something specific to us or something we can override. If you rely on this app for something you can't afford to miss, don't force-stop it, and check in on it now and then. (The in-app Settings screen says the same thing, for the same reason.)

## Children

This app isn't directed at children and isn't designed to appeal to them. We don't knowingly collect information from children — in practice, we don't collect personal information from anyone, of any age, since nothing you enter leaves your device.

## Changes to this policy

If this policy changes, we'll update the "Last updated" date at the top and the change will be reflected here. There's no mailing list or account to notify, since the app doesn't collect an email address or any other contact detail from you.

## Contact

Questions about this policy or the app: **pnilukaa@gmail.com**
