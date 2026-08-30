# Continuum Health 🏥

AI-powered continuous healthcare coordination platform built with Flutter, Riverpod, and GoRouter.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Architecture & State Management](#architecture--state-management)
- [Getting Started](#getting-started)

---

## 🌟 Overview

**Continuum Health** is an intelligent healthcare platform designed to bridge the gap between patient self-care, family health coordination, and clinical decision-making. By leveraging a multi-agent AI assistant, real-time vital monitoring, and seamless consent-driven data sharing, Continuum Health delivers proactive and personalized healthcare management.

---

## ✨ Key Features

### 👤 Patient Portal
- **Dashboard**: Real-time vital metrics tracking (Heart Rate, Blood Pressure, SpO2, Sleep), activity streaks, and daily medication alerts.
- **AI Health Assistant**: Intelligent triage and continuous health conversational agent powered by multi-agent intelligence.
- **Family Health Tree**: Multi-generational family member profiles, vital tracking, and shared medical records.
- **Appointment Scheduling**: Doctor discovery, specialty filtering, and integrated booking calendar.
- **Profile & Medical ID**: Digital health pass, QR-based sharing, and permission consent logs.

### 🩺 Doctor Portal
- **Clinical Dashboard**: Patient caseload overview, incoming appointment queues, and critical vital alerts.
- **Patient Management**: In-depth medical history review, treatment plans, prescriptions, and lab reports.
- **QR Scanner Integration**: Instant patient profile retrieval via QR code consent scanning.
- **Schedule Management**: Interactive calendar for tracking daily, weekly, and monthly consultations.

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (Material 3)
- **State Management**: [Riverpod 2.x](https://riverpod.dev) (`flutter_riverpod`)
- **Navigation & Routing**: [GoRouter](https://pub.dev/packages/go_router) with `StatefulShellRoute` for role-based navigation shells
- **Design & UI**:
  - `lucide_icons` & `cupertino_icons`
  - `google_fonts` (Inter / Outfit)
  - `flutter_animate` & `shimmer` for fluid micro-animations and loading states
  - `glass_card` custom frosted-glass styling
- **Utilities**:
  - `table_calendar` for appointment & schedule management
  - `qr_flutter` for patient record sharing
  - `intl` for localization and date formatting
  - `uuid` for unique identifier generation

---

## 📂 Project Structure

```
bang_lore/
├── pubspec.yaml                      # Dependencies, assets, and app metadata
├── analysis_options.yaml              # Linting rules & analyzer configuration
├── README.md                          # Project documentation
│
├── lib/
│   ├── main.dart                      # Application entrypoint & ProviderScope setup
│   │
│   ├── core/                          # Cross-cutting shared modules & UI library
│   │   ├── router/
│   │   │   └── app_router.dart        # GoRouter configuration & shell branch routing
│   │   ├── theme/
│   │   │   ├── app_colors.dart        # Unified color palette & semantic tokens
│   │   │   └── app_theme.dart         # Material 3 light/dark theme data
│   │   └── widgets/                   # Reusable atomic UI components
│   │       ├── glass_card.dart
│   │       ├── notification_sheet.dart
│   │       ├── primary_button.dart
│   │       ├── secondary_button.dart
│   │       ├── section_header.dart
│   │       ├── shimmer_loading.dart
│   │       ├── status_chip.dart
│   │       └── vital_card.dart
│   │
│   ├── data/                          # Data layer (models, providers, repositories)
│   │   ├── mock/
│   │   │   └── mock_data.dart         # Mock datasets for offline prototyping
│   │   ├── models/                    # Domain data models & serializable entities
│   │   │   ├── appointment_model.dart
│   │   │   ├── chat_message_model.dart
│   │   │   ├── doctor_model.dart
│   │   │   ├── family_member_model.dart
│   │   │   ├── medication_model.dart
│   │   │   ├── notification_model.dart
│   │   │   ├── patient_model.dart
│   │   │   ├── permission_request_model.dart
│   │   │   ├── reminder_model.dart
│   │   │   └── user_model.dart
│   │   ├── providers/
│   │   │   └── providers.dart         # Global Riverpod state providers
│   │   ├── repositories/              # Business logic & data access layer
│   │   │   ├── ai_repository.dart
│   │   │   ├── appointment_repository.dart
│   │   │   ├── auth_repository.dart
│   │   │   ├── doctor_repository.dart
│   │   │   ├── family_repository.dart
│   │   │   ├── medication_repository.dart
│   │   │   ├── patient_repository.dart
│   │   │   └── reminder_repository.dart
│   │   └── services/
│   │       └── multi_agent_service.dart # Multi-agent AI triage & chat logic
│   │
│   └── features/                      # Feature-first & role-based UI screens
│       ├── auth/                      # Authentication & Onboarding
│       │   └── screens/
│       │       ├── login_screen.dart
│       │       └── role_selection_screen.dart
│       │
│       ├── patient/                   # Patient Experience
│       │   ├── patient_shell.dart     # Patient navigation shell & bottom bar
│       │   ├── ai/screens/
│       │   │   └── ai_chat_screen.dart
│       │   ├── dashboard/screens/
│       │   │   ├── patient_dashboard_screen.dart
│       │   │   ├── doctor_search_screen.dart
│       │   │   └── doctor_detail_screen.dart
│       │   ├── family/screens/
│       │   │   ├── family_tree_screen.dart
│       │   │   └── family_member_detail_screen.dart
│       │   ├── schedule/screens/
│       │   │   ├── patient_schedule_screen.dart
│       │   │   └── book_appointment_screen.dart
│       │   └── profile/screens/
│       │       └── patient_profile_screen.dart
│       │
│       └── doctor/                    # Doctor Experience
│           ├── doctor_shell.dart      # Doctor navigation shell & bottom bar
│           ├── dashboard/screens/
│           │   └── doctor_dashboard_screen.dart
│           ├── patients/screens/
│           │   ├── doctor_patients_screen.dart
│           │   ├── patient_detail_screen.dart
│           │   └── scan_qr_screen.dart
│           ├── calendar/screens/
│           │   └── doctor_calendar_screen.dart
│           └── profile/screens/
│               └── doctor_profile_screen.dart
│
├── android/                           # Android native configuration
├── ios/                               # iOS native configuration
└── test/                              # Unit and widget test suite
```

---

## 🏗️ Architecture & State Management

- **Clean Architecture Pattern**: Separation of concerns between Data (models, repositories, services), Core (theming, routing, shared UI), and Features (presentation & screen widgets).
- **Declarative Navigation**: Centralized in `AppRouter` using `GoRouter`, supporting deep linking and stateful nested navigation branches for both Patient and Doctor modes.
- **Modular Data Providers**: Riverpod providers isolate state mutations, enabling clean testability and asynchronous data fetching.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version `>=3.11.0`)
- Android Studio / Xcode / VS Code with Flutter extension

### Installation & Run

1. **Clone the repository and navigate to the project directory:**
   ```bash
   cd bang_lore
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   ```bash
   flutter run
   ```

4. **Run static analysis & tests:**
   ```bash
   flutter analyze
   flutter test
   ```
