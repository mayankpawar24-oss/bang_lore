# Continuum Health — n8n & Telegram Integration Architecture

This document details the exact root-cause fix for n8n's **`Error: "Invalid JSON in 'Query'"`**, the real Firestore schema, and the three automated production workflows.

---

## 1. Root Cause of `Error: "Invalid JSON in 'Query'"`

### Why the error occurred
In n8n, the Google Cloud Firestore Node (`n8n-nodes-base.googleCloudFirestore`) evaluates the **Query** parameter using `JSON.parse()`.

The query fails with `Error: "Invalid JSON in 'Query'"` due to two specific syntax mistakes:
1. **Unquoted n8n Expressions**:
   When entering expressions in JSON mode, writing:
   ```json
   {
     "from": [{ "collectionId": "appointments" }],
     "where": {
       "fieldFilter": {
         "field": { "fieldPath": "status" },
         "op": "EQUAL",
         "value": { "stringValue": {{ $json.status }} }
       }
     }
   }
   ```
   n8n substitutes `{{ $json.status }}` with literal unquoted text: `"value": { "stringValue": approved }`. Because `approved` lacks enclosing double quotes (`"`), `JSON.parse` crashes with `Unexpected token a in JSON`.
2. **JavaScript / SDK Method Syntax in a JSON Field**:
   Entering query clauses like:
   ```javascript
   db.collection("appointments").where("status", "==", "approved")
   ```
   or JavaScript object notation without strict double-quoted JSON keys and values.

---

## 2. Fixed & Validated Firestore Queries for n8n

### Node A: "Query Changed Appointments"
Use either of the two formats below:

#### Option 1: Standard JSON (Direct Paste)
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

#### Option 2: n8n Dynamic Expression (Guaranteed Valid JSON)
In the n8n Query input field, toggle to **Expression** (`=`) and paste:
```javascript
={{ JSON.stringify({
  from: [{ collectionId: "appointments" }],
  where: {
    fieldFilter: {
      field: { fieldPath: "status" },
      op: "IN",
      value: {
        arrayValue: {
          values: [
            { stringValue: "pending" },
            { stringValue: "approved" },
            { stringValue: "rejected" },
            { stringValue: "cancelled" },
            { stringValue: "completed" },
            { stringValue: "missed" }
          ]
        }
      }
    }
  }
}) }}
```

---

### Node B: "Query Approved Appointments"

#### Option 1: Standard JSON (Direct Paste)
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

#### Option 2: n8n Dynamic Expression (Guaranteed Valid JSON)
In the n8n Query input field, toggle to **Expression** (`=`) and paste:
```javascript
={{ JSON.stringify({
  from: [{ collectionId: "appointments" }],
  where: {
    fieldFilter: {
      field: { fieldPath: "status" },
      op: "EQUAL",
      value: { stringValue: "approved" }
    }
  }
}) }}
```

---

## 3. Real Firestore Schema Reference

| Collection / Path | Field Name | Type | Notes |
| :--- | :--- | :--- | :--- |
| `users/{uid}` | `uid` / `id` | String | Firebase Auth UID |
| `users/{uid}` | `role` | String | `"patient"` or `"doctor"` |
| `users/{uid}` | `telegramChatId` | String | Telegram Chat ID when linked |
| `users/{uid}` | `telegramConnected`| Boolean | `true` when verified |
| `appointments/{id}` | `appointmentId` | String | Primary document key |
| `appointments/{id}` | `patientId` | String | Patient Firebase Auth UID |
| `appointments/{id}` | `doctorId` | String | Doctor Firebase Auth UID |
| `appointments/{id}` | `patientName` | String | e.g. "Margaret Chen" |
| `appointments/{id}` | `doctorName` | String | e.g. "Aisha Patel" |
| `appointments/{id}` | `dateTime` | Timestamp | Scheduled appointment time |
| `appointments/{id}` | `durationMinutes` | Number | Consultation duration (30) |
| `appointments/{id}` | `status` | String | `pending`, `approved`, `rejected`, `cancelled`, `completed`, `missed` |
| `notifications/{id}` | `recipientUid` | String | Enforces user-specific scoping |
| `notifications/{id}` | `recipientRole`| String | `"patient"` or `"doctor"` |
| `notifications/{id}` | `senderUid` | String | Sender UID |
| `notifications/{id}` | `type` | String | `appointment_request`, `appointment_approved`, etc. |
| `notifications/{id}` | `title` | String | Notification header |
| `notifications/{id}` | `message` | String | Notification body |
| `notifications/{id}` | `isRead` / `read`| Boolean | Default `false` |
| `notifications/{id}` | `timestamp` | Timestamp | Delivery time |
| `processedEvents/{key}`| `eventKey` | String | Deterministic idempotency key |

---

## 4. Idempotency & Duplicate Protection

Every appointment status event generates a deterministic key:
```javascript
const eventKey = `${appointmentId}_${status}_${updatedAtSeconds}`;
```
- The workflow checks `processedEvents/{eventKey}` in Firestore.
- If it exists, the workflow halts immediately (prevents duplicate push notifications and messages).
- If absent, it records `processedEvents/{eventKey}` and dispatches the notification.

---

## 5. Telegram Privacy & Safe Message Format

In accordance with medical safety constraints, Telegram notifications contain **zero private health data** (no medical history, symptoms, lab reports, OCR results, or diagnoses).

**Format**:
```text
🏥 Continuum Health

Appointment Approved
Your appointment with Dr. Aisha Patel has been approved.

Doctor: Dr. Aisha Patel
Patient: Margaret Chen
Date & Time: 05 Sep, 10:30 AM
```

---

## 6. Importing the Pre-built Workflows into n8n

The 3 workflows are ready to import directly from this directory:
1. `n8n/workflows/Appointment_Status_Notifications.json`
2. `n8n/workflows/Reminders_and_Missed_Appointments.json`
3. `n8n/workflows/Telegram_Linking.json`

To import:
1. Open your n8n workspace.
2. Click **Workflows** → **Add Workflow** → `...` menu in top right → **Import from File**.
3. Select the respective `.json` file.
4. Select your configured Google Cloud Firestore and Telegram credentials.
5. Click **Save** and toggle the workflow to **Active**.
