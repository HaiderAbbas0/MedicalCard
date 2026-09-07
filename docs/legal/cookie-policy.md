# Cookie & Local Storage Policy

**Version:** 2026-09-07 · **Last updated:** 7 September 2026

> ⚠️ **Template — pending review by qualified legal counsel.**

## Summary
The web portals use **only strictly-necessary browser storage** and set **no
advertising or third-party tracking cookies**. Because we use only essential
storage, a cookie-consent banner is **not required** under typical rules — but
this must be confirmed for your jurisdictions.

## What we store in the browser
| Item | Type | Purpose | Essential? |
| --- | --- | --- | --- |
| Supabase auth session (`hayaat_admin_auth` / `hayaat_staff_auth`) | localStorage | Keeps you signed in; without it you'd log in on every page | Yes (essential) |

No analytics, marketing, or cross-site tracking cookies are set.

## The mobile app
The Flutter app stores the auth session in the platform's secure storage and a few
non-sensitive UI preferences (theme, language) on-device. It sets no cookies.

## If this changes
If we later add analytics or any non-essential cookie, we will add a cookie-consent
banner with granular opt-in **before** any such cookie is set, and update this
policy.
