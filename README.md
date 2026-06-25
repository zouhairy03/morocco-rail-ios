<div align="center">

# 🚆 Morocco Rail — iOS App (Concept)

**A native SwiftUI companion app for high-speed train travel in Morocco.**
Search · book · multi-passenger · seat map · e-ticket with QR · live train tracking on a map · loyalty · real auth.

![iOS](https://img.shields.io/badge/iOS-16%2B-000?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5-FA7343?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0A84FF)
![Supabase](https://img.shields.io/badge/Auth-Supabase-3FCF8E?logo=supabase&logoColor=white)
![i18n](https://img.shields.io/badge/i18n-FR%20·%20EN%20·%20AR%20+%20RTL-F2660A)

</div>

---

## ✨ Features

- 🎟 **Full booking flow** — search → results (sort/filter) → multi-passenger → **seat map** → payment → **e-ticket with QR** + sharable **PDF**.
- 🗺 **Live tracking** — real-time train status (on-time / delay / disruption / stopped) with a **moving train on a MapKit map** (tap to go full-screen).
- 🔐 **Real authentication** — email/password + **Google Sign-In** (OAuth + PKCE), **Supabase** backend with code-based email verification & password reset, **Face ID / Touch ID** app lock.
- 💳 **Payments sandbox** — card brand detection, saved (masked) cards, test cards for every outcome.
- 🎖 **Loyalty & cards** — points, redemption, a verifiable **reduction card** (Tarifa) linked to the account.
- 🌍 **Trilingual** — **FR / EN / AR** with full **RTL**, dark mode, onboarding, accessibility (VoiceOver + Dynamic Type).
- 🔔 Local departure reminders · service alerts · offline banner · haptics · App Store **privacy manifest**.

## 🛠 Tech stack

**SwiftUI** (iOS 16+), **Swift 5**, MapKit, PassKit, LocalAuthentication, CryptoKit, UserNotifications — no third-party SDKs (Supabase & Google via REST / `ASWebAuthenticationSession`).

## 🚀 Build

```bash
open ONCFVoyages.xcodeproj   # then ⌘R in Xcode
```
Real backend keys (Supabase URL + anon key, Google client ID) live in `SupabaseAuth.swift` / `GoogleAuth.swift`; the app falls back to a fully working on-device demo when they're absent.

## ⚠️ Disclaimer

This is an **independent, non-commercial concept / portfolio project**. It is **not affiliated with, endorsed by, or connected to ONCF** (Office National des Chemins de Fer du Maroc) or any railway operator. All timetables, prices, and bookings are **simulated mock data**, all imagery is **AI-generated**, and **no official logos, photos, source code, or trademarks** are used. Any brand-like wording appears only as placeholder text for a UI/UX design demonstration.

## 📝 License

[MIT](LICENSE) for the code. Generated images are provided for demonstration purposes only.
