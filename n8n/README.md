# Continuum Health — n8n, Telegram & Audit Log Architecture

This document details the exact root-cause fixes for n8n queries, collection index errors, batch document write collisions, patient-specific Telegram isolation, and the complete audit logging architecture.

---

## 1. Root Causes & Fixes

### A. `Error: "Invalid JSON in 'Query'"`
**Root Cause**:
In n8n's Google Cloud Firestore Node (`n8n-nodes-base.googleCloudFirestore`), the **Query** parameter is passed directly to `JSON.parse()`.
1. **Unquoted expressions**: Writing `"value": { "stringValue": {{ $json.status }} }` evaluates to `"stringValue": approved` (missing quotes), breaking RFC 8259 JSON parsing.
2. **SDK syntax**: Pasting `.where("status", "==", "approved")` into a REST API structured query field throws a parse error.

**Fix**:
Use the validated Firestore `structuredQuery` JSON format below with strict double quoting.

### B. `Error: "The query requires a COLLECTION_GROUP_ASC index..."`
**Root Cause**:
Attempting to run a collection group query (`collectionId: "medications"` or `collectionId: "appointments"`) across patient subcollections with composite filters (`where` + `orderBy`) triggers Firestore's requirement for a `COLLECTION_GROUP_ASC` composite index.

**Fix**:
1. Top-level collections are used canonically: `/appointments` and `/medications`.
2. The Flutter application dual-writes active prescriptions to top-level `/medications/{id}` as well as `/patients/{patientId}/medications/{id}`.
3. n8n queries the top-level collection `/medications` and performs all schedule/time comparisons inside the **n8n Code node**, eliminating any composite index requirement.

### C. `Error: "The same document cannot be written more than once in a single request"`
**Root Cause**:
In n8n, when a Firestore update or batch write node receives an array containing multiple items with the same `documentId`, n8n compiles them into a single Firestore `CommitRequest`. Firestore REST API rejects duplicate document writes within one request with status 400.

**Fix**:
The Code nodes (`Build Notification Tasks` and `Evaluate Reminders & Missed Events`) explicitly deduplicate items by `documentId` and deterministic `eventKey` before any Firestore node is invoked.

---

## 2. Validated n8n Firestore Queries

### Node: "Query Changed Appointments"
```json
{
  "from": [
    {
      "collectionId": "appointments"
    }
  ],
  "where": {
    "fieldFilter": {
      "field": {
        "fieldPath": "status"
      },
      "op": "IN",
      "value": {
        "arrayValue": {
          "values": [
            { "stringValue": "pending" },
            { "stringValue": "approved" },
            { "stringValue": "rejected" },
            { "stringValue": "cancelled" },
            { "stringValue": "completed" },
            { "stringValue": "missed" }
          ]
        }
      }
    }
  }
}
```

### Node: "Query Approved Appointments"
```json
{
  "from": [
    {
      "collectionId": "appointments"
    }
  ],
  "where": {
    "fieldFilter": {
      "field": {
        "fieldPath": "status"
      },
      "op": "EQUAL",
      "value": {
        "stringValue": "approved"
      }
    }
  }
}
```

### Node: "Query Active Medications"
```json
{
  "from": [
    {
      "collectionId": "medications"
    }
  ],
  "where": {
    "fieldFilter": {
      "field": {
        "fieldPath": "active"
      },
      "op": "EQUAL",
      "value": {
        "booleanValue": true
      }
    }
  }
}
```

---

## 3. Production Workflows Overview

The system includes three production workflow JSON files under `n8n/workflows/`:

### 1. `n8n/workflows/Appointment_Status_Notifications.json`
- **Schedule**: Triggers every 1 minute.
- **Deduplication**: Generates deterministic event keys: `${appointmentId}_${status}_${updatedAtSeconds}`.
- **Idempotency**: Checks `processedEvents/{eventKey}`. If already processed, skips.
- **Recipient Resolution**: Reads `users/{recipientUid}` for `telegramChatId` and `telegramConnected`.
- **Telegram Routing**: Routes only to the recipient's isolated `telegramChatId`. Doctor receives doctor notifications; Patient receives patient notifications.
- **Audit Persistence**: Writes in-app notification to `notifications/{id}` and audit log to `activityLogs/{id}`.

### 2. `n8n/workflows/Reminders_and_Missed_Appointments.json`
- **Schedule**: Triggers every 2 minutes.
- **Appointment Reminders**: Detects approved consultations starting within the next 60 minutes (`appt_rem_${apptId}_${hour}`).
- **Missed Appointments**: Detects approved appointments whose duration + 10 minute grace period has passed without being completed or cancelled (`appt_missed_${apptId}`).
  - Updates Firestore status to `missed`.
  - Dispatches Telegram alert to patient.
- **Medication Reminders**: Detects active medications scheduled around current time (+/- 20 minutes) if not yet marked taken.
- **Missed Medications**: Detects scheduled medications whose 60-minute grace period expired without being taken or skipped.
  - Updates `isMissed: true`.
  - Dispatches Telegram alert to patient.
- **Telegram Message Content**:
  - *Patient Missed Appointment*:
    ```
    Continuum Health Alert

    Your appointment with Dr. [Doctor Name]
    scheduled for [Date/Time] was missed.

    Please reschedule your appointment if required.
    ```
  - *Patient Medication Reminder*:
    ```
    Continuum Health Medication Reminder

    Medicine: [Medicine Name]
    Dosage: [Dosage]
    Time: [Time]

    Please take your medication as prescribed.
    ```
  - *Missed Medication*:
    ```
    Continuum Health Alert

    You missed your scheduled medication:

    Medicine: [Medicine Name]
    Dosage: [Dosage]
    Scheduled: [Time]

    Please follow your prescribed medication plan.
    ```

### 3. `n8n/workflows/Telegram_Linking.json`
- **Trigger**: Telegram bot messages (`/start <code>` or `<code>`).
- **Validation**: Looks up `telegramLinkCodes/{code}`.
- **Binding**: Updates authenticated `users/{uid}` with `telegramChatId` and `telegramConnected: true`.
- **Isolation**: Each user possesses their own Telegram Chat ID stored on their own document.
- **Audit Logging**: Records `telegramLinked` in `activityLogs`.
- **Security**: Immediately deletes code from `telegramLinkCodes/{code}`.

---

## 4. Audit Log Schema (`activityLogs` & `patients/{uid}/activityLogs`)

Every activity log written across the app and n8n contains:
- `id` / `eventId`: Unique document ID
- `eventType`: String enum (`patientCreated`, `patientUpdated`, `appointmentRequested`, `appointmentApproved`, `appointmentRejected`, `appointmentCancelled`, `appointmentCompleted`, `appointmentMissed`, `medicineAdded`, `medicationEdited`, `medicationDeleted`, `medicineTaken`, `medicineSkipped`, `medicationMissed`, `telegramLinked`, `telegramUnlinked`, `documentUploaded`, `documentViewed`, `notificationSent`, `notificationFailed`)
- `timestamp`: Firestore Timestamp
- `actorUid`: UID of the user or system performing the action
- `actorRole`: `'patient'`, `'doctor'`, or `'system'`
- `patientUid` / `patientId`: Associated patient UID
- `doctorUid`: Associated doctor UID (where applicable)
- `appointmentId`: Associated appointment ID (where applicable)
- `medicationId`: Associated medication ID (where applicable)
- `reportId`: Associated report ID (where applicable)
- `notificationType`: Notification category (where applicable)
- `deliveryStatus`: `'sent'`, `'failed'`, or `'in_app_only'`
- `title`: Human-readable event title
- `description`: Detailed action description
- `metadata`: Flexible contextual map
