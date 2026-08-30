# Zedoc — Design Bible
### Smart Healthcare Consultation & Booking App
*Reference source: 9 provided reference screenshots (brand deck + UI kit). Version 1.0 — draft for review.*

---

## 0. How to use this document
This is a reverse-engineered design system built from your reference screenshots. Every section marked **[CONFIRM]** is my best read of a compressed screenshot, not a verified spec — flag those against your source Figma/AI file before your engineers hard-code them. Section 12 lists everything I need from you to close the gaps.

---

## 1. Brand Foundation

**Product:** Zedoc — "Smart Healthcare Consultation & Booking App"
**Tagline (from marketing screen):** "Connect with top doctors instantly, book online consultations, explore specialists nearby, and manage appointments effortlessly from your mobile device."
**Logo lockup:** Wordmark "Zedoc" (lowercase "z", rounded geometric letterforms), shown on splash screen centered on a soft gradient field, high-contrast (near-black on pastel gradient).

**Brand personality (inferred from visual language):**
- Calm, clinical-but-warm, minimal, trustworthy
- Pastel gradient + off-white surfaces → "wellness," not "hospital"
- Black as the sole high-contrast accent (buttons, active nav, text) → confidence and clarity against a soft palette
- Rounded geometry throughout (cards, icons, avatars) → approachability, low threat

**Emotional design goal:** A patient opening this app is often anxious, in pain, or managing a chronic condition. Every visual decision below should reduce cognitive/emotional load, not add delight for its own sake.

---

## 2. Color System

### 2.1 Palette (as sampled — verify hex in source file)
| Token | Hex [CONFIRM] | Role |
|---|---|---|
| `brand/purple-100` | `#BCA9ED` | Secondary accent — AI/assistant surfaces, gradient stop |
| `brand/green-100` | `#BDEEAD` | Secondary accent — wellness/positive states, gradient stop |
| `brand/blue-100` | `#ABC4EB` | Secondary accent — informational chips, gradient stop |
| `neutral/ink` | `#0B0C0E` (approx.) | Primary text, primary buttons (Book Now, Ask anything, active nav) |
| `neutral/grey-500` | `#5D5D5D` (approx.) | Secondary text, placeholder text |
| `surface/white` | `#FFFFFF` | Card backgrounds, base surface |
| `surface/off-white` | `#F5F6F5` (approx.) | Screen background |

### 2.2 Gradient system
A signature 3-to-4 stop pastel mesh gradient (purple → green → blue, occasionally + white) appears in three places:
1. Splash screen background
2. The "AI orb" (Robinson assistant avatar) — a glossy iridescent sphere
3. Hero illustration on the brand/onboarding slide (soft abstract wave form)

This gradient is your **most reusable brand asset** — treat it as a component, not a one-off illustration. It should be the *only* place saturated color appears; everywhere else color is used sparingly as small accent chips or status dots.

### 2.3 Color psychology rationale (why this palette works for healthcare)
- **Low-saturation blue/green/purple** are consistently shown in health-UX research to lower perceived stress and read as "clinical + calm" rather than "alarming." Avoid saturated red except for true error/critical states — reserve it exclusively for destructive actions and vitals-out-of-range alerts so it retains signal value.
- **Near-black instead of brand-blue for CTAs** is a deliberate, less common choice — it reads as authoritative/premium and, importantly, doesn't compete with the pastel gradient for attention. Keep this consistent: only one CTA color in the whole app.
- **White space discipline** (large card padding, generous line-height) reduces the "cluttered clinic form" feeling that erodes trust in digital health products.

### 2.4 Semantic colors — **[CONFIRM — not visible in screenshots]**
Not shown anywhere in the references. You need to define, at minimum:
- Success / confirmed appointment
- Warning / pending approval, low balance
- Error / destructive, missed appointment, critical vitals
- Info
- Disabled states
- Online/offline doctor status (a green dot is used in Image 6 — confirm this is `success`, not a third accent)

---

## 3. Typography

**Typeface:** Lufga — geometric sans-serif, described in-brand as "modern geometric sans-serif known for its clean design and readability."
**Weights available (confirmed):** Light, Regular, Medium, SemiBold
**[CONFIRM]:** Is Lufga licensed for commercial/production use, and is it a variable font? Flutter needs static weight files (`Lufga-Light.ttf`, `Lufga-Regular.ttf`, etc.) registered in `pubspec.yaml` — confirm you have a license that covers app distribution, not just a design-file trial.

### 3.1 Proposed type scale — **[PROPOSED, not shown]**
The reference deck shows the family but not a documented scale. Based on visible screen hierarchy (greeting text, price tags, body copy, labels), I'd propose:

| Style | Weight | Size / Line-height | Usage |
|---|---|---|---|
| Display | SemiBold | 32/40 | Splash wordmark, hero headlines |
| H1 | SemiBold | 24/32 | Screen titles ("Good Afternoon, Eva Smith") |
| H2 | Medium | 18/26 | Section headers ("Our Specialist", "Components") |
| Body | Regular | 15/22 | Paragraph copy, chat messages |
| Body-Strong | Medium | 15/22 | Doctor names, emphasized inline text |
| Caption | Regular | 12/16 | Timestamps, metadata (experience, ratings) |
| Label/Button | Medium | 14/20, uppercase or sentence case (confirm) | Button text, chips |
| Price | SemiBold | 20/24 | `$120`-style price tags — given visual weight in every doctor card |

**[CONFIRM]** this against your actual Figma type styles before engineering locks a `TextTheme`.

---

## 4. Layout, Grid & Spacing

### 4.1 Grid (from "Spacing & Grid System" reference)
- **5-column grid**, column width driven by content, **16px gutters** between columns
- **84px module/row height** used as the vertical rhythm unit for card rows (visible as the repeating green band on the spec sheet)
- Base spacing unit appears to be **8px**, scaling as 8 / 16 / 24 / 32 / 48 — standard 8pt grid, consistent with the 16px gutter shown

### 4.2 Safe areas / margins
- Screen horizontal margin: **~20px** (consistent across all mock screens)
- Card internal padding: **~16px**
- Card corner radius: **large and consistent** — approx. **20–24px** on primary cards (doctor cards, chat bubbles, buttons), **12px** on small chips/icon containers. **[CONFIRM exact radius tokens]**

### 4.3 Component sizing patterns
- Primary CTA buttons: full-width, pill-shaped (radius = height/2), height ≈ 52–56px, black fill, white label — appears identically as "Book Appointment," "Book Now," and the Ask-Robinson input's send affordance
- Bottom navigation: 4-item, icon-only, active state = filled black circle around the icon (not a color swap) — a nice touch that keeps the palette calm even in the persistent nav

---

## 5. Iconography

**Style:** Outline/stroke icons, rounded terminals, consistent ~1.5–2px stroke weight, no fill except in active/selected state.
**Confirmed icon set from reference:** home, bell/notification, person/profile, calendar, heart (favorite), search, envelope/message, bag/briefcase, block/no-entry, people/group, chevron-left (back), arrow-right.

**Interaction states (from the "Components" sheet):** Every icon-button appears in a 2-state pair — **unselected (grey outline, white/light fill)** vs **selected (solid blue fill, white icon)**. This state pattern is used identically for: favorite/heart, bookmark, share, notification-bell, add-person, and calendar icons. Standardize this as a single reusable `IconToggleButton` component rather than one-off styling per icon — it appears at least 6 times in the kit.

**[CONFIRM]:** Icon source (Phosphor / Feather / Lucide / custom)? This determines whether Flutter can pull from an existing icon package (fast) or needs custom SVG assets (slower, needs export from design file).

---

## 6. Core Components

### 6.1 Doctor Card (list variant)
- Avatar (rounded square, ~56–64px) + online-status green dot overlay
- Name (Body-Strong) + specialty (Caption, grey)
- Price tag, right-aligned, SemiBold
- Rating (star icon + numeral, e.g. "4.8") and credential badge (e.g. "MBBS") as small pill/tag
- Favorite heart icon, top-right corner
- Used in: Home "Our Specialist" carousel, Search results list

### 6.2 Doctor Detail Card (expanded)
- Large photo (portrait crop, right-aligned or full-bleed top)
- Name, specialty, price/session
- **Stat trio row**: patients served (e.g. "9k+"), years experience (e.g. "7y+"), rating (e.g. "4.9 ★") — icon + number + label, evenly spaced
- Calendar strip (month view, single row of selectable day pills, current selection filled black)
- "Today Availability" time-slot chips (selectable, similar toggle pattern to icons)
- Sticky bottom CTA: "Book Now"
- Share icon in top bar (secondary action)

### 6.3 Appointment / History Row
- Compact variant of doctor card: avatar, name, specialty, date + time, years experience — used for past-visit / upcoming-appointment lists.

### 6.4 Chat Interface
- Standard two-column bubble chat: incoming (light grey, left) / outgoing (black, right, white text)
- Timestamp under each bubble, small caption grey text
- **File-attachment bubble variant**: shows filename + type icon (e.g. "ECG result.pdf") with an explicit **Download** button — critical for medical-report sharing; treat as its own component, not a generic file chip, since download confirmation matters for trust
- Video-call variant card seen in Components sheet (Image 9): doctor thumbnail with a live camera icon overlay + rating badge + two circular action buttons (likely accept/decline or mute/camera) — needed for telehealth call initiation

### 6.5 AI Assistant ("Robinson")
- Distinct named persona, not "AI Chatbot" — deliberate humanizing choice, keep this in copy everywhere
- Entry screen: greeting ("Hi, I'm Robinson"), sub-line explaining scope of help, 4 suggested-prompt pills (e.g. "How can I find nearby doctors?", "Which doctors accept my insurance?"), free-text input pinned to bottom labeled "Ask anything"
- Visual identity = the gradient orb (see 2.2), used consistently as its "face"/avatar in both the assistant entry screen and inline in chat

### 6.6 Home / Dashboard
- Greeting header ("Good Afternoon, [Name]") — time-of-day aware, personalized
- Health-query search bar ("Ask anything about your health") sitting directly under the greeting — blends search + AI entry point into one affordance
- Category filter chips (Primary care, Dentist, Physio, etc.) — horizontally scrollable
- "Our Specialist" carousel (Doctor Card, 6.1)

### 6.7 Profile Screen
- Avatar + name + email header, inline edit-pencil icon
- Grouped settings list under section headers: **Account** (Account information, Notification, Personal information), **Privacy** (single line: "Protecting your data with care")
- Standard `>` chevron affordance on every row

### 6.8 Payment / Checkout
- Payment method **radio list**: PayPal, Apple Pay, Google Pay/Phone Pay — icon + label + radio, one selectable at a time
- Saved card summary row: card network logo, masked number, cardholder name, small "Add Address" link/button
- Voucher/promo code: text input + adjacent "Apply" button — **[CONFIRM]** validation/error states (invalid code, expired code) since none are shown

### 6.9 Bottom Navigation
4 destinations, icon-only, no labels, active state = filled black circular pill background behind the icon (not a color/label change) — keep exactly 4 items; adding a 5th will break the visual rhythm shown across every mock.

---

## 7. Screen Inventory (what exists vs. what's implied)

**Shown in references:**
1. Splash screen
2. Onboarding/brand slide (illustrative, no UI)
3. Home / Dashboard
4. Search / "Expert Medical Help Anytime" (specialty filter + doctor list)
5. Doctor Detail + Booking (calendar + time slots)
6. Chat (patient ↔ doctor)
7. AI Assistant (Robinson)
8. Profile / Account settings
9. Payment / Checkout

**Implied but not shown — [CONFIRM if in scope]:**
- Onboarding flow steps (sign-up, permissions, insurance capture)
- Appointment confirmation screen
- Video call in-progress UI (only a card teaser is shown, not the live call layout)
- Notifications list/center (icon exists, screen doesn't)
- Search empty-states / no-results
- Error states (payment failure, no internet, no doctors available)
- Prescription / e-Rx viewing
- Lab result viewer (only the download chip is shown, not the result rendering)
- Insurance verification flow (referenced in an AI suggested-prompt, no screen)
- Reviews/ratings detail screen
- Dark mode

---

## 8. Motion & Micro-interactions — **[NOT SHOWN — needs your input]**
Static screenshots can't tell me:
- Screen transition style (push/fade/shared-element for doctor-card → doctor-detail?)
- Loading states for AI responses (typing indicator style for Robinson?)
- The gradient orb — is it animated/alive (subtle rotation, breathing scale) in the live product? This matters a lot for perceived "AI-ness" and should almost certainly have *some* idle animation.
- Button press feedback, skeleton loaders for doctor list, pull-to-refresh behavior

---

## 9. Accessibility — gaps to close before this is production-ready
1. **Contrast:** pastel palette (`#BCA9ED`, `#BDEEAD`, `#ABC4EB`) is unlikely to pass WCAG AA as text-on-white at small sizes — confirm these are used only as large fills/backgrounds/gradient, never as body text color.
2. **Color-only status signals:** the green online-dot and red-implied error states need a secondary indicator (icon/text) for color-blind users — common failure point in healthcare apps specifically because misreading a status (e.g., "urgent" vs "routine") has real consequences.
3. **Touch targets:** icon-toggle buttons (6.5) must hit ≥44x44pt regardless of visual icon size — check against Image 8's tight icon grid.
4. **Text scaling:** healthcare users skew older/lower-vision on average — verify layouts survive iOS/Android large text settings without truncating doctor names or prices.
5. **Screen reader labeling:** every icon-only nav/action needs a semantic label (Flutter `Semantics` widget) — none of this is visible in a screenshot but must be planned now, not retrofitted later.

---

## 10. Healthcare UX Psychology — principles this system should encode

1. **Reduce anxiety through information transparency, not information volume.** The "Spent $580 / Available $830" pattern in the reference (Image 1) is a strong pattern — surfacing cost/coverage status *before* the user has to ask reduces a top-3 source of healthcare-app anxiety (surprise billing). Extend this pattern anywhere money or coverage is ambiguous.
2. **Social proof placement builds trust fast.** Rating + patient-count + years-experience shown together, right at first glance of a doctor card, mirrors how patients evaluate trust offline (reputation, tenure) — keep all three together as a unit; don't split them across screens.
3. **Named, humanized AI (Robinson) lowers the barrier to disclosure.** People share more honestly with a named assistant than a generic "Chatbot" — but this also raises the ethical bar: be explicit in copy that Robinson is AI, not a clinician, and cannot give diagnoses. This should be a persistent, unmissable disclaimer, not a one-time onboarding line.
4. **Hick's Law — reduce choice at decision points.** The specialty filter chips and 4 suggested AI prompts are good examples of constrained choice. Keep any given screen to ≤5–7 primary choices; healthcare decision fatigue is real and directly reduces task completion (booking, medication adherence).
5. **Progressive disclosure for medical data.** Chat file attachments show filename + explicit download action rather than auto-rendering results inline — correct instinct. Sensitive results (labs, imaging) should always require an intentional tap, never auto-preview, both for privacy-in-public-view (someone glancing at the phone) and for emotional pacing (patient controls when they're ready to see a result).
6. **Consistent, low-arousal color = perceived competence.** Calm palettes are empirically associated with higher trust ratings for health brands vs. high-saturation/urgent palettes — reserve saturation exclusively for true urgency so it isn't diluted.
7. **Default-safe payment/voucher flows.** No destructive action (e.g., removing a saved card) should be a single tap — require confirmation, consistent with how the black CTA is otherwise reserved for positive/forward actions (Book, Ask, Send).
8. **Autonomy-supportive language.** Section headers like "Protecting your data with care" (Privacy row) are a good tone template — extend this considerate, non-clinical voice into empty states, errors, and permission requests (e.g., camera/mic access for video calls) rather than generic system copy.

---

## 11. Flutter Implementation Notes (engineering handoff)

- **Theming:** Centralize palette + type scale in a single `ThemeExtension` (not scattered `Color(0xFF...)` literals) so the near-black CTA color and the 3 pastel accents are the *only* hardcoded brand colors in the codebase; everything else should reference semantic tokens (`Colors.error`, `Colors.success`) once you define them (Section 2.4).
- **Gradient orb:** Build as a reusable widget (`AiOrb`), likely `Container` + `RadialGradient`/`SweepGradient` stack, or a small Rive/Lottie asset if animated — don't recreate as a static PNG per screen; you'll want it in multiple sizes (avatar-small in chat, hero-large on the assistant entry screen).
- **IconToggleButton:** One widget, `bool selected`, drives fill/outline + color swap — used for favorite, bookmark, share, notification, add-person per Section 5.
- **DoctorCard / DoctorDetailCard:** Model these as two variants of one data model (`Doctor`) rather than duplicating fields, since every screen (home, search, chat header, detail) references the same doctor entity.
- **Bottom nav:** `CupertinoTabBar`/`BottomNavigationBar` won't natively give you the "filled circle behind active icon" look — plan a custom nav bar widget from the start.
- **Fonts:** Register all 4 Lufga weights explicitly in `pubspec.yaml`; don't rely on `FontWeight.w600` synthesis on a Regular-only file — it'll look wrong and inconsistent across Android/iOS.

---

## 12. Open Questions — please answer or point me to source material

**Design source**
1. Do you have the original Figma (or other design tool) file? Hex values, exact type scale, and corner-radius tokens in this doc are estimates from compressed screenshots — I'd rather pull exact values than guess.
2. Is "Zedoc" your actual product name, or is this reference kit from a different product (e.g. a Dribbble/UI8 template) that you're adapting for **Continuum Health**? Worth confirming since your app-in-progress is the post-discharge care coordination app — if this kit is inspiration rather than final brand, I should reframe this bible around *your* product name/scope, not "Zedoc."

**Scope**
3. Which of the screens in Section 7's "implied but not shown" list are actually in your MVP scope? I don't want to spec 15 screens if you only need 6.
4. Is video consultation an MVP feature, or future/phase-2? It changes how much of Section 6.4's video-call component needs to be built out now.
5. Dark mode: required for launch, or later?

**Brand/legal**
6. Do you hold a commercial license for the Lufga font covering app distribution?
7. Icon library source — a named package (Phosphor/Feather/Lucide) or custom SVGs I should treat as brand-owned assets?

**Content**
8. Real copy for empty/error states, permission-request dialogs, and the AI disclaimer — I can draft these in the calm/considerate voice from Section 10 if you'd like, but want your sign-off on tone first.
9. Any existing accessibility or compliance requirements (HIPAA-adjacent data handling, WCAG level target) I should design against explicitly?

---

*End of v1.0. Tell me which sections to expand, correct, or turn into implementation-ready Flutter widget specs next.*
