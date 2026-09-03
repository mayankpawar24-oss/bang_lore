# Continuum Health — Reusable Component Architecture Specification
### *Senior Flutter Component Architecture & Design System Integration*
**Document Version:** 2.0.0-PROD  
**Target Platform:** Flutter 3.x (Material 3 + Cupertino Haptics)  
**Reference Source:** `reference/zedoc-design-bible (1).md` & UI Reference Kit  

---

## Architecture Overview & Component Principles

All 20 atomic, molecular, and organismic components adhere strictly to the following architectural contracts:
1. **Zero Domain Model Coupling:** Components receive primitive or lightweight UI view entities (e.g., `String title`, `VoidCallback? onTap`, `Widget? leading`), ensuring they can be reused across both Patient and Doctor portals without coupling to specific backend DTOs.
2. **Theme Token Consumption:** Direct color or style hardcoding is forbidden; all components resolve colors, radiuses, elevations, and typography dynamically through `Theme.of(context)` and `AppThemeExtension`.
3. **Ergonomic Hit Targets:** Every clickable area guarantees an absolute minimum of 48×48 dp hit bounds.
4. **Semantics & Accessibility:** All widgets declare explicit screen reader labels, action traits, and live region semantics for clinical safety.

---

## Component Specifications (1–20)

---

### 1. `AppCard`
* **Purpose:** Universal foundation container providing consistent surface background, 1px optical stroke border, elevation, and squircle corner geometry.
* **States:** Default (Resting), Hovered, Pressed (0.985 scale), Disabled (0.45 opacity).
* **Padding:** Configurable via `EdgeInsetsGeometry` — defaults to `AppPadding.defaultPadding` (16dp).
* **Typography:** Inherits parent or sets `textTheme.bodyMedium` as fallback.
* **Spacing:** Internal child spacing managed by composition; margin defaults to `EdgeInsets.zero`.
* **Animation:** Scale and opacity transitions on press using `150ms Curves.easeOutCubic`.
* **Accessibility:** Semantic container; if `onTap` is supplied, announces as a button with `semanticLabel`.
* **Dark Mode:** Surface switches from `#FFFFFF` (border `#E2E8F0`) to `#131C2E` (border `rgba(255, 255, 255, 0.08)`).
* **Variants:** `flat`, `outlined`, `elevated`, `interactive`.
* **Flutter API:**
  ```dart
  AppCard({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    double radius = 20.0,
    Color? backgroundColor,
    Color? borderColor,
    double elevation = 0.0,
    VoidCallback? onTap,
    String? semanticLabel,
  })
  ```
* **Reusability:** Base wrapper for all list items, dashboards, summaries, and dialogs.
* **Naming Convention:** `AppCard`
* **Component Tree:**
  ```
  Semantics
  └── GestureDetector / InkWell
      └── AnimatedContainer (Scale & Opacity)
          └── DecoratedBox (BoxDecoration: surface color, squircle border, shadow)
              └── Padding
                  └── child
  ```

---

### 2. `GlassCard`
* **Purpose:** Frosted-glass translucent surface for floating docks, sticky navigation headers, and modal overlays.
* **States:** Resting, Scrolled-Under Active (increased blur & border contrast).
* **Padding:** Default `16dp` horizontal, `12dp` vertical.
* **Typography:** `textTheme.titleMedium` / `textTheme.bodyMedium` with high-contrast text.
* **Spacing:** 8dp inner item spacing.
* **Animation:** Smooth opacity / sigma transition over 250ms when scrolling activates blur.
* **Accessibility:** Includes backdrop barrier semantics if used as an overlay.
* **Dark Mode:** 70% opacity `#1E293B` with `rgba(255, 255, 255, 0.12)` border (vs. Light Mode 80% `#FFFFFF` with `rgba(255, 255, 255, 0.6)` border).
* **Variants:** `dock`, `header`, `sheetOverlay`, `subtle`.
* **Flutter API:**
  ```dart
  GlassCard({
    Key? key,
    required Widget child,
    double blurSigma = 16.0,
    double opacity = 0.80,
    double radius = 24.0,
    Border? border,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  })
  ```
* **Reusability:** Persistent navigation shells, AI Assistant overlay dock, modal drag sheets.
* **Naming Convention:** `GlassCard`
* **Component Tree:**
  ```
  ClipRRect (Squircle Radius)
  └── BackdropFilter (ImageFilter.blur)
      └── DecoratedBox (Color with Alpha + Gradient Border)
          └── Padding
              └── child
  ```

---

### 3. `HealthCard` (Vital Metric Tile)
* **Purpose:** Displays real-time clinical biomarkers (Heart Rate, BP, SpO2, Glucose, Sleep) with status indicators, trends, and micro-sparklines.
* **States:** Normal/Stable (Green tint), Attention/Elevated (Amber tint), Critical (Rose tint/glow), Stale/Syncing (Shimmer).
* **Padding:** `16dp` all sides.
* **Typography:** Value: `Outfit SemiBold 24pt`; Unit: `Inter Medium 11pt`; Title: `Inter Medium 13pt`.
* **Spacing:** 4dp between value and unit; 8dp between icon header and metric value.
* **Animation:** Value counter morphing (300ms) + status color pulse for critical alerts.
* **Accessibility:** High-priority live announcement: *"Heart Rate: 72 beats per minute, Normal status."*
* **Dark Mode:** Status container fills use 12% alpha tinted surfaces with bright semantic icons.
* **Variants:** `compact` (grid 2x2), `expanded` (with mini sparkline chart), `banner` (full-width alert).
* **Flutter API:**
  ```dart
  HealthCard({
    Key? key,
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    HealthStatus status = HealthStatus.stable,
    String? trendText,
    bool isTrendingUp = true,
    List<double>? sparklineData,
    VoidCallback? onTap,
  })
  ```
* **Reusability:** Patient Dashboard, Doctor Patient Detail, Family Vital Monitor.
* **Naming Convention:** `HealthCard`
* **Component Tree:**
  ```
  AppCard (Interactive)
  └── Column
      ├── Row [Icon Squircle Container, Spacer, StatusChip / TrendPill]
      ├── SizedBox (height: 12)
      ├── Row [Text(value, 24pt), SizedBox(width: 4), Text(unit, 11pt)]
      └── Text(title, 13pt muted)
  ```

---

### 4. `RecoveryCard` (Post-Discharge Care Progress)
* **Purpose:** Multi-phase progress tracker for surgery recovery, physical therapy milestones, and treatment protocol adherence.
* **States:** In-Progress (active step glowing), Milestone Reached (celebration check), Delayed/Off-track (warning chip).
* **Padding:** `20dp` horizontal, `18dp` vertical.
* **Typography:** Title: `Outfit SemiBold 18pt`; Milestone: `Inter SemiBold 14pt`; Body: `Inter Regular 13pt`.
* **Spacing:** 12dp vertical step gap; 16dp between progress ring and narrative text.
* **Animation:** Progress fill animation (600ms `Curves.easeOutCubic`) on screen entrance.
* **Accessibility:** Structured heading hierarchy with descriptive progress ratio (*"Day 12 of 30, Step 3 Active"*).
* **Dark Mode:** Deep slate background with vibrant progress gradient fill (`#2563EB` to `#06B6D4`).
* **Variants:** `compactSummary`, `stepByStepDetailed`.
* **Flutter API:**
  ```dart
  RecoveryCard({
    Key? key,
    required String protocolName,
    required int currentDay,
    required int totalDays,
    required double progressPercentage,
    required String currentPhaseTitle,
    required String nextMilestone,
    VoidCallback? onViewProtocol,
  })
  ```
* **Reusability:** Patient Post-op Dashboard, Doctor Clinical Care Overview.
* **Naming Convention:** `RecoveryCard`
* **Component Tree:**
  ```
  AppCard
  └── Column
      ├── Row [Title, Spacer, Phase Badge]
      ├── SizedBox (height: 16)
      ├── Row [ProgressRing (56dp), SizedBox(width: 16), Column [Progress Text, Days Remaining]]
      └── Divider + Action TextButton ("View Protocol")
  ```

---

### 5. `DoctorCard`
* **Purpose:** Comprehensive clinical specialist card featuring avatar, credentials, ratings, patient count, experience, and instant booking CTA.
* **States:** Resting, Verified (blue check badge), Available Today (emerald dot), Offline, Booked.
* **Padding:** `16dp` all around.
* **Typography:** Doctor Name: `Inter SemiBold 16pt`; Specialty: `Inter Regular 13pt`; Stats/Price: `Outfit SemiBold 15pt`.
* **Spacing:** 12dp avatar gap; 8dp between stat pills; 12dp spacing before action footer.
* **Animation:** Smooth scale-in on list load (35ms stagger).
* **Accessibility:** Reads full credential string and instant booking action.
* **Dark Mode:** Dark surface with high-contrast text and crisp border.
* **Variants:** `carouselItem` (fixed width 280dp), `listFullWidth`, `compactRow`.
* **Flutter API:**
  ```dart
  DoctorCard({
    Key? key,
    required String name,
    required String specialty,
    required String avatarUrl,
    required double rating,
    required int reviewsCount,
    required String experienceYears,
    required double consultationFee,
    bool isOnline = true,
    bool isFavorite = false,
    VoidCallback? onFavoriteToggle,
    VoidCallback? onBookNow,
    VoidCallback? onTap,
  })
  ```
* **Reusability:** Doctor Search, Dashboard "Our Specialists" Carousel, Appointment Booking Flow.
* **Naming Convention:** `DoctorCard`
* **Component Tree:**
  ```
  AppCard (Elevated)
  └── Column
      ├── Row [Avatar with OnlineDot, SizedBox(12), Column(Name, Specialty, Rating), Spacer, IconToggleButton(Heart)]
      ├── SizedBox(height: 14)
      ├── Row [StatPill(Experience), StatPill(Patients), Spacer, PriceTag]
      └── SizedBox(height: 12) + PrimaryButton.compact("Book Appointment")
  ```

---

### 6. `MedicationCard`
* **Purpose:** Interactive prescription & schedule tile tracking dosage, timing, meal instructions, and one-tap taken/missed confirmation.
* **States:** Pending (Resting), Taken (Strikethrough / Green check), Missed (Amber alert), Snoozed.
* **Padding:** `16dp` horizontal, `14dp` vertical.
* **Typography:** Med Name: `Inter SemiBold 15pt`; Dosage & Timing: `Inter Medium 13pt`; Instructions: `Inter Regular 12pt`.
* **Spacing:** 12dp leading icon gap; 4dp between timing and instructions.
* **Animation:** Checkmark morph & smooth color crossfade (200ms) on status toggle.
* **Accessibility:** Accessible checkbox role with dynamic status voiceover.
* **Dark Mode:** Muted border on taken state, vibrant alert border on missed state.
* **Variants:** `dailyTimelineRow`, `prescriptionSummaryCard`.
* **Flutter API:**
  ```dart
  MedicationCard({
    Key? key,
    required String medicationName,
    required String dosage,
    required String scheduledTime,
    required String instruction,
    bool isTaken = false,
    bool isCritical = false,
    ValueChanged<bool>? onStatusChanged,
    VoidCallback? onTap,
  })
  ```
* **Reusability:** Patient Daily Regimen, Doctor Prescription Review, Family Health Summary.
* **Naming Convention:** `MedicationCard`
* **Component Tree:**
  ```
  AppCard
  └── Row
      ├── SquircleIcon (Pill Icon, 40dp)
      ├── SizedBox(width: 14)
      ├── Column [Row(Med Name, CriticalBadge), Text(Dosage • Time), Text(Instruction)]
      ├── Spacer
      └── StatusCheckbox / ToggleIconButton
  ```

---

### 7. `AppointmentCard`
* **Purpose:** Displays consultation schedule details, doctor/patient info, video-call/in-person badge, countdown pill, and action buttons.
* **States:** Upcoming (Active blue highlight), In-Progress (Live blinking badge), Completed (Muted), Cancelled.
* **Padding:** `16dp` all sides.
* **Typography:** Date/Time: `Outfit SemiBold 15pt`; Clinician/Patient: `Inter SemiBold 15pt`; Location/Mode: `Inter Regular 13pt`.
* **Spacing:** 12dp header rhythm; 16dp divider gap; 12dp button row gap.
* **Animation:** Slide-in from bottom when new appointment booked.
* **Accessibility:** Calendar entry role with explicit date/time announcements.
* **Dark Mode:** Dynamic card surface with themed calendar badge background (`#1E293B`).
* **Variants:** `heroUpcoming`, `compactListTile`, `doctorQueueItem`.
* **Flutter API:**
  ```dart
  AppointmentCard({
    Key? key,
    required String doctorOrPatientName,
    required String subtitle,
    required String avatarUrl,
    required DateTime appointmentDateTime,
    AppointmentType type = AppointmentType.videoCall,
    AppointmentStatus status = AppointmentStatus.upcoming,
    VoidCallback? onJoinCall,
    VoidCallback? onReschedule,
    VoidCallback? onCancel,
  })
  ```
* **Reusability:** Patient Schedule Tab, Doctor Dashboard Queue, Doctor Calendar.
* **Naming Convention:** `AppointmentCard`
* **Component Tree:**
  ```
  AppCard
  └── Column
      ├── Row [DateBadge (Month/Day), SizedBox(12), Column(Time, TypeBadge), Spacer, StatusChip]
      ├── SizedBox(height: 12)
      ├── Row [Avatar, SizedBox(12), Column(Name, Subtitle), Spacer, ActionIconButton]
      └── if (isUpcoming) ...[SizedBox(height: 12), Row(PrimaryButton("Join Call"), SecondaryButton("Reschedule"))]
  ```

---

### 8. `AIInsightCard`
* **Purpose:** Displays multi-agent clinical triage summaries, anomalous vital correlations, and proactive lifestyle suggestions from AI ("Robinson").
* **States:** Resting, Expanding, Analyzing (ambient pulse gradient).
* **Padding:** `18dp` all sides.
* **Typography:** Header: `Outfit SemiBold 16pt`; Summary: `Inter Regular 14pt (150% line height)`; Disclaimer: `Inter Regular 11pt`.
* **Spacing:** 12dp between gradient header and body; 14dp before prompt action chips.
* **Animation:** Shimmering gradient border / breathing scale on AI Orb icon.
* **Accessibility:** Explicit AI-generated content disclaimer tag read by screen reader.
* **Dark Mode:** 1px Cyan-tinted glowing border (`rgba(6, 182, 212, 0.3)`) on deep slate background.
* **Variants:** `triageSummary`, `vitalAnomalyAlert`, `suggestedFollowup`.
* **Flutter API:**
  ```dart
  AIInsightCard({
    Key? key,
    required String agentName,
    required String insightText,
    required InsightSeverity severity,
    List<String>? actionableSuggestions,
    ValueChanged<String>? onSuggestionSelected,
    VoidCallback? onDismiss,
  })
  ```
* **Reusability:** Patient Home Dashboard, Doctor Diagnostic Co-pilot Panel.
* **Naming Convention:** `AIInsightCard`
* **Component Tree:**
  ```
  DecoratedBox (Mesh Gradient Accent Border)
  └── AppCard
      └── Column
          ├── Row [FloatingAIOrb.micro(28dp), SizedBox(8), Text("Robinson Insight"), Spacer, SeverityBadge]
          ├── SizedBox(height: 12)
          ├── Text(insightText, 14pt)
          ├── SizedBox(height: 12)
          └── Wrap [ActionablePromptChips]
  ```

---

### 9. `TimelineCard` (Clinical Journey Event)
* **Purpose:** Chronological medical history node tracking admissions, labs, doctor notes, prescription updates, and discharge events.
* **States:** First Node, Intermediate Node, Terminal Node, Highlighted/Active Node.
* **Padding:** `14dp` horizontal, `12dp` vertical.
* **Typography:** Event Title: `Inter SemiBold 14pt`; Timestamp: `Inter Regular 12pt muted`; Doctor Notes: `Inter Regular 13pt`.
* **Spacing:** 16dp timeline node offset; 8dp vertical card spacing.
* **Animation:** Expand/collapse animation (250ms) for detailed clinical attachments.
* **Accessibility:** Linear sequence semantics (*"Step 2 of 5: Blood Panel Completed"*).
* **Dark Mode:** Continuous connecting line uses `#334155` with glowing current-event indicator.
* **Variants:** `compactMedicalHistory`, `expandedDiagnosticLog`.
* **Flutter API:**
  ```dart
  TimelineCard({
    Key? key,
    required String title,
    required String timestamp,
    required String description,
    required IconData nodeIcon,
    Color? nodeColor,
    bool isFirst = false,
    bool isLast = false,
    List<Widget>? attachmentChips,
    VoidCallback? onTap,
  })
  ```
* **Reusability:** Patient Medical History, Doctor Patient Longitudinal Record.
* **Naming Convention:** `TimelineCard`
* **Component Tree:**
  ```
  IntrinsicHeight
  └── Row
      ├── TimelineNodeLine [ConnectingLine, SquircleIconBadge, ConnectingLine]
      ├── SizedBox(width: 14)
      └── Expanded [AppCard(Column(Title, Timestamp, Description, Attachments))]
  ```

---

### 10. `ProgressRing`
* **Purpose:** Circular biometric completion tracker (Daily recovery goal, water intake, medication adherence, health score).
* **States:** Idle, Animating Progress Fill, Goal Completed (Glow ring).
* **Padding:** `4dp` inner margin.
* **Typography:** Value: `Outfit Bold 18pt`; Sub-label: `Inter Regular 11pt`.
* **Spacing:** Centered stack alignment.
* **Animation:** Custom sweep arc animation (700ms `Curves.easeOutCubic`).
* **Accessibility:** Declares percentage progress semantics value (`value: 0.75`).
* **Dark Mode:** Track background uses `#1E293B`; progress gradient uses high-luminance tokens.
* **Variants:** `monochrome`, `gradientMesh`, `multiSegmentRing`.
* **Flutter API:**
  ```dart
  ProgressRing({
    Key? key,
    required double progress, // 0.0 to 1.0
    double size = 80.0,
    double strokeWidth = 8.0,
    Gradient? progressGradient,
    Color? trackColor,
    Widget? centerChild,
  })
  ```
* **Reusability:** Recovery Cards, Dashboard Health Score, Vitals Overview.
* **Naming Convention:** `ProgressRing`
* **Component Tree:**
  ```
  SizedBox(width: size, height: size)
  └── CustomPaint (RingPainter: background track + sweep gradient arc)
      └── Center (child / Text percentage)
  ```

---

### 11. `HealthGraph`
* **Purpose:** Lightweight, high-precision sparkline and trend curve for tracking heart rate variability, blood pressure, and glucose fluctuations.
* **States:** Static Trend, Interactive Scrubber (touch point tooltip), Loading Skeleton.
* **Padding:** `12dp` vertical, `8dp` horizontal.
* **Typography:** Axis Labels: `Inter Regular 10pt`; Tooltip Value: `Outfit SemiBold 13pt`.
* **Spacing:** 8dp spacing between chart surface and date range selector.
* **Animation:** Path bezier draw animation (500ms) on load.
* **Accessibility:** Accessible summary table provided as semantic equivalent for screen readers.
* **Dark Mode:** Gradient area fill under curve transitions from 25% alpha to 0% on dark slate background.
* **Variants:** `sparklineMini` (no axes), `interactiveAreaChart` (with scrub line).
* **Flutter API:**
  ```dart
  HealthGraph({
    Key? key,
    required List<double> dataPoints,
    required List<String> xLabels,
    Color lineColor = AppColors.primaryBlue,
    Gradient? areaGradient,
    double height = 120.0,
    bool showAxes = true,
    ValueChanged<int>? onPointSelected,
  })
  ```
* **Reusability:** Vital Detail Sheets, Doctor Vitals Analyzer, Recovery Progress.
* **Naming Convention:** `HealthGraph`
* **Component Tree:**
  ```
  GestureDetector (Touch scrub)
  └── SizedBox(height: height)
      └── CustomPaint (SmoothBezierCurvePainter + GradientFill + DataPoints)
  ```

---

### 12. `AppSearchBar`
* **Purpose:** Unified search input with instant voice/filter actions, clear button, and debounce callback support.
* **States:** Inactive (Resting), Focused (1.5px brand stroke), Searching/Loading (Spinner), HasQuery.
* **Padding:** `16dp` horizontal, `12dp` vertical.
* **Typography:** Input & Placeholder: `Inter Regular 15pt`.
* **Spacing:** 12dp leading search icon gap; 8dp trailing action gap.
* **Animation:** Focus border transition (150ms).
* **Accessibility:** SearchField role with clear button semantic action.
* **Dark Mode:** Background `#131C2E` with `#334155` border and `#F8FAFC` input text.
* **Variants:** `standardField`, `triggerButtonOnly` (navigates on tap).
* **Flutter API:**
  ```dart
  AppSearchBar({
    Key? key,
    TextEditingController? controller,
    String hintText = "Search doctors, symptoms, medications...",
    ValueChanged<String>? onChanged,
    VoidCallback? onFilterTap,
    VoidCallback? onClear,
    bool readOnly = false,
    VoidCallback? onTap,
  })
  ```
* **Reusability:** Doctor Search Screen, Patient Directory, Symptom Lookup.
* **Naming Convention:** `AppSearchBar`
* **Component Tree:**
  ```
  DecoratedBox (Radius-MD, Border, Fill)
  └── Row
      ├── Icon (Search, 20dp)
      ├── SizedBox(width: 10)
      ├── Expanded (TextField / ReadOnlyText)
      ├── if (hasText) IconToggleButton.clear
      └── if (showFilter) IconToggleButton.filter
  ```

---

### 13. `PrimaryButton`
* **Purpose:** High-contrast authoritative CTA for definitive actions (Booking, Confirming, Sending).
* **States:** Resting (Solid near-black `#0B0C0E` in light mode / `#2563EB` in dark mode), Pressed (0.98 scale), Loading (Spinner), Disabled (0.4 opacity).
* **Padding:** Standard: `16dp` vertical, `24dp` horizontal; Compact: `10dp` vertical, `16dp` horizontal.
* **Typography:** `Inter SemiBold 15pt` (White label).
* **Spacing:** 8dp icon-to-text spacing; full-width default.
* **Animation:** Tactile scale-down (100ms) with haptic feedback on touch.
* **Accessibility:** Button trait with loading state announcement.
* **Dark Mode:** Shifts to vibrant medical blue `#2563EB` for high-contrast visibility against dark canvas.
* **Variants:** `fullWidthPill`, `compactPill`, `withIcon`.
* **Flutter API:**
  ```dart
  PrimaryButton({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isFullWidth = true,
    IconData? leadingIcon,
    IconData? trailingIcon,
    double height = 52.0,
  })
  ```
* **Reusability:** Global primary CTA across all screens, sheets, and dialogs.
* **Naming Convention:** `PrimaryButton`
* **Component Tree:**
  ```
  Semantics (Button)
  └── GestureDetector / InkWell
      └── AnimatedContainer (Scale, Color)
          └── SizedBox (height: height, width: isFullWidth ? double.infinity : null)
              └── Center [if (isLoading) Spinner else Row(Icon, Text, Icon)]
  ```

---

### 14. `SecondaryButton`
* **Purpose:** Low-emphasis alternative action (Cancel, Back, Secondary Filters, View More).
* **States:** Resting (Outlined / Light tinted background), Pressed, Disabled.
* **Padding:** `14dp` vertical, `20dp` horizontal.
* **Typography:** `Inter SemiBold 14pt` (Brand Blue / Slate).
* **Spacing:** 8dp icon-to-text spacing.
* **Animation:** Scale-down (100ms).
* **Accessibility:** Button trait.
* **Dark Mode:** Slate border with transparent surface; white text.
* **Variants:** `outlined`, `ghost/textOnly`, `softTinted`.
* **Flutter API:**
  ```dart
  SecondaryButton({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    bool isFullWidth = false,
    IconData? icon,
    Color? foregroundColor,
  })
  ```
* **Reusability:** Modal action rows, card secondary actions, filter resets.
* **Naming Convention:** `SecondaryButton`
* **Component Tree:**
  ```
  AppCard (Outlined / Ghost)
  └── Center [Row(Icon, Text)]
  ```

---

### 15. `FloatingAIOrb`
* **Purpose:** Visual anchor & interactive avatar for the "Robinson" AI Health Assistant.
* **States:** Idle (Gentle breathing float), Listening (Audio wave ripple), Thinking (Rotating iridescent gradient), Speaking (Pulse).
* **Padding:** `0dp` (Self-contained geometric orb).
* **Typography:** None (Pure graphical avatar).
* **Spacing:** Floats 24dp from right and bottom edges.
* **Animation:** 4-second continuous sine-wave vertical float + multi-stop sweep gradient rotation.
* **Accessibility:** Accessible button role: *"Robinson AI Health Assistant, Double tap to ask health questions."*
* **Dark Mode:** Enhanced ambient cyan/purple glow (`Blur-Deep`).
* **Variants:** `floatingActionOrb` (60dp), `chatHeaderAvatar` (36dp), `heroAssistant` (100dp).
* **Flutter API:**
  ```dart
  FloatingAIOrb({
    Key? key,
    double size = 56.0,
    AIOrbState state = AIOrbState.idle,
    VoidCallback? onTap,
    bool showGlow = true,
  })
  ```
* **Reusability:** Patient Dashboard Floating Launcher, AI Chat Screen Avatar.
* **Naming Convention:** `FloatingAIOrb`
* **Component Tree:**
  ```
  GestureDetector
  └── AnimatedBuilder (Sine wave float & rotation)
      └── DecoratedBox (Multi-stop Mesh Gradient: Purple -> Green -> Blue)
          └── BoxShadow (Ambient Cyan Glow)
  ```

---

### 16. `AppNavigationBar` (Custom Floating Glass Dock)
* **Purpose:** Persistent 4-item navigation dock with animated active icon background capsules.
* **States:** 4 items; Active item features filled black pill capsule indicator (icon turns white).
* **Padding:** `8dp` vertical, `16dp` horizontal; dock floats 16dp above bottom screen edge.
* **Typography:** Icon-only (No text labels, preserving clean visual rhythm).
* **Spacing:** Evenly spaced flex items (`MainAxisAlignment.spaceAround`).
* **Animation:** AnimatedContainer / position morphing for the active capsule background (250ms `Curves.easeOutCubic`).
* **Accessibility:** Labeled navigation destinations with selected state semantics.
* **Dark Mode:** Glass surface `#131C2E` at 85% opacity; active capsule turns `#2563EB` or `#FFFFFF` with black icon.
* **Variants:** `patientDock` (4 items), `doctorDock` (4 items).
* **Flutter API:**
  ```dart
  AppNavigationBar({
    Key? key,
    required int currentIndex,
    required ValueChanged<int> onItemSelected,
    required List<NavigationItemSpec> items,
  })
  ```
* **Reusability:** `patient_shell.dart`, `doctor_shell.dart`.
* **Naming Convention:** `AppNavigationBar`
* **Component Tree:**
  ```
  Padding (Floating Margins)
  └── GlassCard (Radius-2XL, Blur-Standard)
      └── Row (spaceAround)
          └── For each item: GestureDetector [AnimatedContainer(Active Capsule Fill, Icon)]
  ```

---

### 17. `AppBottomSheet`
* **Purpose:** Modal bottom sheet for notifications, vital entry, appointment booking confirmation, and quick triage.
* **States:** Collapsed, Expanded, Dragging (interactive drag handle).
* **Padding:** `24dp` horizontal, `16dp` top, `32dp` bottom safe area.
* **Typography:** Sheet Title: `Outfit SemiBold 20pt`; Subtitle: `Inter Regular 14pt`.
* **Spacing:** 8dp below drag pill; 16dp header-to-content gap.
* **Animation:** Slide up + backdrop fade (300ms `Curves.easeOutCubic`).
* **Accessibility:** Modal barrier semantics with autofocus on sheet title.
* **Dark Mode:** `#131C2E` surface with light drag handle.
* **Variants:** `staticSheet`, `scrollableDraggableSheet`.
* **Flutter API:**
  ```dart
  AppBottomSheet.show({
    required BuildContext context,
    required String title,
    required Widget content,
    Widget? actionButton,
    bool isDismissible = true,
  })
  ```
* **Reusability:** Notification Sheet, Medication Log Sheet, Consent Request Sheet.
* **Naming Convention:** `AppBottomSheet`
* **Component Tree:**
  ```
  ModalBarrier
  └── SlideTransition
      └── ClipRRect (Top Radius-XL)
          └── Material (Surface Color)
              └── Column [DragHandlePill, TitleRow, Flexible(Content), ActionRow]
  ```

---

### 18. `AppDialog`
* **Purpose:** Urgent modal dialogs for critical vital alerts, prescription cancellations, and emergency contact triggers.
* **States:** Alert, Confirmation, Clinical Warning.
* **Padding:** `24dp` all around.
* **Typography:** Title: `Outfit SemiBold 18pt`; Message: `Inter Regular 14pt`.
* **Spacing:** 16dp between icon and title; 20dp before button actions.
* **Animation:** Scale-up from center (200ms `Curves.easeOutCubic`).
* **Accessibility:** `AlertDialog` role with urgent accessibility focus.
* **Dark Mode:** High-contrast border with semantic accent icon.
* **Variants:** `confirmation`, `criticalAlert`, `permissionPrompt`.
* **Flutter API:**
  ```dart
  AppDialog.show({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    String? cancelLabel,
    DialogType type = DialogType.standard,
    VoidCallback? onConfirm,
  })
  ```
* **Reusability:** Data Deletion Confirmation, Emergency SOS Trigger, QR Access Revoke.
* **Naming Convention:** `AppDialog`
* **Component Tree:**
  ```
  Dialog (Radius-XL, Elevation-4)
  └── Padding
      └── Column [IconSquircle, SizedBox(12), TitleText, SizedBox(8), MessageText, SizedBox(20), ActionButtonsRow]
  ```

---

### 19. `AppChip` / `FilterChipGroup`
* **Purpose:** Category selectors (Specialty, Time Slots, Vitals Filter, AI Prompt Pills).
* **States:** Unselected (Grey border / soft fill), Selected (Black fill + white text OR Blue fill + white text), Disabled.
* **Padding:** `8dp` vertical, `14dp` horizontal.
* **Typography:** `Inter Medium 13pt`.
* **Spacing:** 8dp horizontal gutter between chips in a horizontal list.
* **Animation:** Color crossfade & scale morph (150ms).
* **Accessibility:** Toggle chip role with explicit selected trait.
* **Dark Mode:** Unselected: `#1E293B` fill; Selected: `#2563EB` fill.
* **Variants:** `filterPill`, `choiceToggle`, `aiPromptSuggestion`.
* **Flutter API:**
  ```dart
  AppChip({
    Key? key,
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
    IconData? leadingIcon,
    Color? activeColor,
  })
  ```
* **Reusability:** Specialty Filter, Doctor Availability Slots, AI Quick Suggestions.
* **Naming Convention:** `AppChip`
* **Component Tree:**
  ```
  GestureDetector
  └── AnimatedContainer (Radius-Full, Border, Fill)
      └── Row(Icon, Text)
  ```

---

### 20. `AppTextField`
* **Purpose:** Standardized form input for credentials, search queries, patient clinical notes, and chat input dock.
* **States:** Resting, Focused (1.5px brand outline), Error (Rose border + caption error message), Disabled.
* **Padding:** Content padding: `16dp` horizontal, `14dp` vertical.
* **Typography:** Input: `Inter Regular 15pt`; Hint: `Inter Regular 15pt muted`; Error: `Inter Regular 12pt`.
* **Spacing:** 6dp vertical gap between label, input box, and error caption.
* **Animation:** Focus transition (150ms).
* **Accessibility:** Text field role with live error narration.
* **Dark Mode:** `#131C2E` background with `#334155` border.
* **Variants:** `singleLine`, `multilineNotes`, `chatInputDock` (with microphone & send action).
* **Flutter API:**
  ```dart
  AppTextField({
    Key? key,
    TextEditingController? controller,
    String? label,
    String? hintText,
    String? errorText,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefixIcon,
    Widget? suffixIcon,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  })
  ```
* **Reusability:** Login & Role Selection, Patient Clinical Notes, AI Chat Input Dock.
* **Naming Convention:** `AppTextField`
* **Component Tree:**
  ```
  Column (crossAxis: start)
  ├── if (label != null) Text(label, TitleSmall)
  ├── SizedBox(height: 6)
  ├── TextField (InputDecoration: squircle border, fill, icons)
  └── if (errorText != null) Text(errorText, CaptionRose)
  ```

---

## Component Matrix & Portal Mapping

| # | Component Name | Atomic Level | Patient Portal | Doctor Portal | Shared / Core |
|---|---|---|:---:|:---:|:---:|
| 1 | `AppCard` | Atom | ✅ | ✅ | `core/widgets/` |
| 2 | `GlassCard` | Atom | ✅ | ✅ | `core/widgets/` |
| 3 | `HealthCard` | Molecule | ✅ | ✅ | `core/widgets/` |
| 4 | `RecoveryCard` | Organism | ✅ | ✅ | `core/widgets/` |
| 5 | `DoctorCard` | Molecule | ✅ | ❌ | `core/widgets/` |
| 6 | `MedicationCard` | Molecule | ✅ | ✅ | `core/widgets/` |
| 7 | `AppointmentCard` | Molecule | ✅ | ✅ | `core/widgets/` |
| 8 | `AIInsightCard` | Organism | ✅ | ✅ | `core/widgets/` |
| 9 | `TimelineCard` | Molecule | ✅ | ✅ | `core/widgets/` |
| 10 | `ProgressRing` | Atom | ✅ | ✅ | `core/widgets/` |
| 11 | `HealthGraph` | Molecule | ✅ | ✅ | `core/widgets/` |
| 12 | `AppSearchBar` | Molecule | ✅ | ✅ | `core/widgets/` |
| 13 | `PrimaryButton` | Atom | ✅ | ✅ | `core/widgets/` |
| 14 | `SecondaryButton` | Atom | ✅ | ✅ | `core/widgets/` |
| 15 | `FloatingAIOrb` | Molecule | ✅ | ✅ | `core/widgets/` |
| 16 | `AppNavigationBar` | Organism | ✅ | ✅ | `core/widgets/` |
| 17 | `AppBottomSheet` | Organism | ✅ | ✅ | `core/widgets/` |
| 18 | `AppDialog` | Organism | ✅ | ✅ | `core/widgets/` |
| 19 | `AppChip` | Atom | ✅ | ✅ | `core/widgets/` |
| 20 | `AppTextField` | Molecule | ✅ | ✅ | `core/widgets/` |

---
*End of Reusable Component Architecture Specification.*
