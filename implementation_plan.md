# Ardius Care — High-Fidelity Patient Home/Dashboard Redesign

Redesign the Ardius Care patient Home/Dashboard screen with a high-fidelity, clinical, patient-centric interface adhering to the authoritative design references (`reference/zedoc-design-bible (1).md` and `reference/component_architecture_specification.md`). The redesign introduces a refined header, compact search, a prominent clinical blue action carousel with pagination, "Today's Health Insights" with a personalized health summary card and supporting insight cards, a floating glassmorphic bottom navigation dock with an elevated emerged central blue action button, and moves the introductory video from the home dashboard to the app opening/splash screen.

---

## User Review Required

> [!IMPORTANT]
> **Video Placement Update**: As requested, the introductory video player (`assets/video/intro.mp4`) has been removed from the Home dashboard. It will now be featured on the app opening screen (`AppOpeningScreen` / splash flow) with a skip/proceed affordance and fallback handling, ensuring the Home dashboard remains focused on real-time care coordination.

> [!NOTE]
> **Central Navigation Action**: In accordance with Step 9, the floating bottom navigation will feature an elevated, emerged circular blue button positioned symmetrically at the center. This launches Ardius Care's core clinical feature — Branch 2 (AI Care / Robinson Co-pilot) — while Home, Family, Timeline, and Profile remain accessible around it.

---

## Proposed Changes

### 1. New Modular Components for Home Dashboard

#### [NEW] [home_action_carousel.dart](file:///c:/Users/Sam/Code/BANGLORE%20SMART/final/bang_lore/lib/features/patient/dashboard/widgets/home_action_carousel.dart)
- Prominent rounded rectangular card utilizing the established Ardius clinical blue gradient (`AppColors.heroGradient` / `blueToIndigo`).
- 3–4 contextual, action-oriented slides representing Ardius Care capabilities:
  1. **Daily Care Protocol**: Complete today's prescribed tasks & medications (navigates to Timeline).
  2. **AI Health Co-Pilot**: Review Robinson's vital analysis & personalized health insight (navigates to AI Care).
  3. **Clinical Record Ingestion**: Upload discharge summaries, lab reports, or prescriptions (triggers upload modal).
  4. **Care Coordination**: Check upcoming specialist consultation & follow-up milestones (navigates to Schedule/Timeline).
- Horizontal swipeable `PageView` with smooth page controller, tactile press states, and small pagination pill indicators below the card with the active indicator visually emphasized.
- Controlled responsive height (155–165dp) to ensure subsequent health insight cards are clearly visible above the fold.

#### [NEW] [health_insights_summary_card.dart](file:///c:/Users/Sam/Code/BANGLORE%20SMART/final/bang_lore/lib/features/patient/dashboard/widgets/health_insights_summary_card.dart)
- Premium "Personalized Health" card with subtle white/glass surface, soft elevation, and 24dp rounded corners.
- Header with health icon, "Personalized Health" title, and real-time clinical status pill ("STABLE" / "ATTENTION").
- Circular/semi-circular progress visualization (`ProgressRing`) indicating recovery adherence or protocol completion.
- Balanced metric metrics (Recovery Protocol Day, Medication Adherence %, Vitals Stability Index) powered by real Riverpod streams (`vitalsStreamProvider`, `medicationsStreamProvider`, `reportsStreamProvider`).
- Integrated "View Details" action connecting to the care timeline.

#### [NEW] [supporting_insight_cards.dart](file:///c:/Users/Sam/Code/BANGLORE%20SMART/final/bang_lore/lib/features/patient/dashboard/widgets/supporting_insight_cards.dart)
- Responsive 2-column grid of modular health insight cards:
  1. **Vitals Status**: Real-time heart rate & blood pressure with trend indicators.
  2. **Medication Regimen**: Today's active doses and completion status.
  3. **Care Coordination**: Next scheduled doctor consultation or upcoming follow-up.
  4. **Health Records**: Ingested clinical documents count with one-tap upload shortcut.

---

### 2. Refactor Patient Dashboard Screen

#### [MODIFY] [patient_dashboard_screen.dart](file:///c:/Users/Sam/Code/BANGLORE%20SMART/final/bang_lore/lib/features/patient/dashboard/screens/patient_dashboard_screen.dart)
- Refactor layout into natural document flow with responsive layout constraints (centered container on tablet/desktop, max-width 680px).
- **Step 3 (Top Header)**: Ardius Care wordmark & logo on top-left; notification bell with subtle unread dot + user profile avatar on top-right with accessible 48×48 hit targets.
- **Step 4 (Search Section)**: Compact rounded search bar ("Ask anything about your health...") opening the AI Care assistant.
- **Step 5**: Prominent Blue Action Carousel with pagination.
- **Step 6**: "Today's Health Insights" section with subtle right-aligned "View All" action and the Personalized Health summary card.
- **Step 7**: Supporting 2-column health insight cards.
- **Step 8**: Patient-centric narrative addressing "How am I doing?", "What changed?", and "What should I do next?".
- Remove `_buildVideoIntroSection` from Home.
- Preserve all existing functionality: record upload bottom sheet, real data streams, navigation destinations.

---

### 3. Redesign Floating Bottom Navigation with Emerged Central Action

#### [MODIFY] [patient_shell.dart](file:///c:/Users/Sam/Code/BANGLORE%20SMART/final/bang_lore/lib/features/patient/patient_shell.dart)
- Recreate bottom navigation as a floating glassmorphism dock (`sigma: 16`, 88% translucency, 1px low-opacity border, soft shadows, 28dp radius).
- Implement the elevated circular blue button for Branch 2 (AI Care / Robinson Co-Pilot) emerged -18dp above the navigation bar with Ardius blue gradient and refined depth shadow.
- Symmetrical 4 standard navigation items (Home, Family, Timeline, Profile) around the central action with clean active-state capsule indicators.
- Safe-area bottom padding so the dock never collides with device home indicators.

---

### 4. Opening / Splash Video Screen

#### [NEW] [app_opening_screen.dart](file:///c:/Users/Sam/Code/BANGLORE%20SMART/final/bang_lore/lib/features/intro/screens/app_opening_screen.dart)
- Dedicated opening screen playing `assets/video/intro.mp4`.
- Ardius Care branding overlay, video playback controls (skip/proceed, mute/unmute), and seamless transition to login or dashboard.

#### [MODIFY] [app_router.dart](file:///c:/Users/Sam/Code/BANGLORE%20SMART/final/bang_lore/lib/core/router/app_router.dart)
- Register `/intro` or handle initial opening route directing to `AppOpeningScreen` before login/auth.

---

## Verification Plan

### Automated Tests
1. Run `flutter analyze` to verify clean compilation with zero warnings or errors.
2. Run `flutter test` to ensure all existing unit tests and updated widget tests pass cleanly.

### Responsive & Visual Verification
1. Inspect Home screen layout on mobile widths (360px, 390px, 412px) to ensure:
   - Action carousel does not overflow horizontally.
   - Pagination dots align properly.
   - Health insight cards wrap cleanly in 2 columns without clipping.
   - Floating navigation bar and emerged central button render with proper clearance.
2. Inspect on desktop/tablet widths (>600px) to verify max-width container centering.
