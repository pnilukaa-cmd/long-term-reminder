/// Task brief item 5: "Link out to the full policy — leave the URL as a
/// clearly-marked constant to fill in, since hosting is not yet decided."
///
/// This is deliberately a placeholder, not a real, resolvable URL — the
/// full policy text already exists at `docs/legal/privacy-policy.md`, but
/// where (or whether) it gets hosted publicly (GitHub Pages, a static
/// page, the eventual Play Store listing's privacy-policy field, etc.)
/// hasn't been decided. Whoever makes that call updates this one constant;
/// nothing else in the app needs to change. Settings' privacy-policy row
/// deliberately does not pretend this is live — see
/// `lib/ui/settings/settings_screen.dart`'s tap handler.
const String kPrivacyPolicyUrl = 'https://TODO-set-before-store-listing.example/privacy';
