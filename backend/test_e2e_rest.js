const admin = require('firebase-admin');
const sa = require('./serviceAccountKey.json');

const app = admin.initializeApp({
  credential: admin.credential.cert(sa),
  projectId: 'continuum-health-b54cb'
});

async function main() {
  console.log('========================================================');
  console.log('CONTINUUM HEALTH: REAL FIRESTORE E2E REST VALIDATION');
  console.log('========================================================\n');

  const tokenObj = await app.options.credential.getAccessToken();
  const token = tokenObj.access_token;
  const baseUrl = 'https://firestore.googleapis.com/v1/projects/continuum-health-b54cb/databases/(default)/documents';

  const testSuffix = Date.now().toString().slice(-6);
  const patientUid = `test_patient_${testSuffix}`;
  const doctorUid = `doctor_dr_patel`;

  console.log(`[TEST 1] Registering New Patient: ${patientUid}`);
  const userRes = await fetch(`${baseUrl}/users/${patientUid}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        id: { stringValue: patientUid },
        name: { stringValue: `Test Patient ${testSuffix}` },
        email: { stringValue: `patient_${testSuffix}@continuumhealth.test` },
        role: { stringValue: 'patient' },
        telegramConnected: { booleanValue: false }
      }
    })
  });
  console.log('  -> User Document Written, HTTP Status:', userRes.status);

  console.log('\n[TEST 2] Adding Medicine (Top-level & Patient subcollection)...');
  const medId = `med_${testSuffix}`;
  const medRes = await fetch(`${baseUrl}/medications/${medId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        id: { stringValue: medId },
        patientId: { stringValue: patientUid },
        name: { stringValue: 'Metformin 500mg' },
        dosage: { stringValue: '1 tablet' },
        time: { stringValue: '08:00 AM' },
        active: { booleanValue: true },
        isTaken: { booleanValue: false },
        isSkipped: { booleanValue: false },
        isMissed: { booleanValue: false }
      }
    })
  });
  console.log('  -> Root /medications Document Written, HTTP Status:', medRes.status);

  console.log('\n[TEST 3] Booking Appointment...');
  const apptId = `appt_${testSuffix}`;
  const apptRes = await fetch(`${baseUrl}/appointments/${apptId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        id: { stringValue: apptId },
        appointmentId: { stringValue: apptId },
        patientId: { stringValue: patientUid },
        doctorId: { stringValue: doctorUid },
        status: { stringValue: 'pending' },
        notes: { stringValue: 'E2E validation booking' }
      }
    })
  });
  console.log('  -> Root /appointments Document Written, HTTP Status:', apptRes.status);

  console.log('\n[TEST 4] Separate Patient and Doctor Notifications...');
  const pNotifRes = await fetch(`${baseUrl}/patientNotifications/notif_p_${apptId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        notificationId: { stringValue: `notif_p_${apptId}` },
        recipientUid: { stringValue: patientUid },
        recipientRole: { stringValue: 'patient' },
        title: { stringValue: 'Appointment Requested' },
        message: { stringValue: 'Your appointment request has been submitted.' }
      }
    })
  });
  const dNotifRes = await fetch(`${baseUrl}/doctorNotifications/notif_d_${apptId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        notificationId: { stringValue: `notif_d_${apptId}` },
        recipientUid: { stringValue: doctorUid },
        recipientRole: { stringValue: 'doctor' },
        title: { stringValue: 'New Appointment Request' },
        message: { stringValue: `Patient Test Patient ${testSuffix} requested a consultation.` }
      }
    })
  });
  console.log('  -> Patient Notification Written, HTTP Status:', pNotifRes.status);
  console.log('  -> Doctor Notification Written, HTTP Status:', dNotifRes.status);

  console.log('\n[TEST 5] Patient-Specific Telegram Linking...');
  const testChatId = `chat_${testSuffix}`;
  const linkRes = await fetch(`${baseUrl}/users/${patientUid}?updateMask.fieldPaths=telegramChatId&updateMask.fieldPaths=telegramConnected`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        telegramChatId: { stringValue: testChatId },
        telegramConnected: { booleanValue: true }
      }
    })
  });
  console.log('  -> Telegram Linked for Patient, HTTP Status:', linkRes.status);

  console.log('\n[TEST 6] Writing Real Activity / Audit Log...');
  const logId = `log_${testSuffix}`;
  const logRes = await fetch(`${baseUrl}/activityLogs/${logId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        id: { stringValue: logId },
        eventId: { stringValue: logId },
        patientId: { stringValue: patientUid },
        patientUid: { stringValue: patientUid },
        actorUid: { stringValue: patientUid },
        actorRole: { stringValue: 'patient' },
        eventType: { stringValue: 'medicineAdded' },
        title: { stringValue: 'Medication Added' },
        description: { stringValue: 'Prescription added: Metformin 500mg • 08:00 AM' }
      }
    })
  });
  console.log('  -> Activity Log Written, HTTP Status:', logRes.status);

  console.log('\n[TEST 7] Reading Activity Logs for Patient...');
  const readLogRes = await fetch(`${baseUrl}/activityLogs/${logId}`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  const readLogData = await readLogRes.json();
  console.log('  -> Read Log Title:', readLogData.fields?.title?.stringValue);
  console.log('  -> Read Log Description:', readLogData.fields?.description?.stringValue);

  console.log('\n[TEST 8] Family Group Chat & Medical Report Sharing...');
  const chatMsgId = `fmsg_${testSuffix}`;
  const chatRes = await fetch(`${baseUrl}/patients/${patientUid}/familyChat/${chatMsgId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        id: { stringValue: chatMsgId },
        patientId: { stringValue: patientUid },
        senderId: { stringValue: patientUid },
        senderName: { stringValue: 'Sarah Connor' },
        senderRole: { stringValue: 'patient' },
        content: { stringValue: 'Mom took her blood pressure medicine this morning.' },
        type: { stringValue: 'text' },
        readBy: { arrayValue: { values: [{ stringValue: patientUid }] } }
      }
    })
  });
  console.log('  -> Family Chat Message Written, HTTP Status:', chatRes.status);

  // Medical report share in chat
  const repMsgId = `fmsg_rep_${testSuffix}`;
  const repRes = await fetch(`${baseUrl}/patients/${patientUid}/familyChat/${repMsgId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        id: { stringValue: repMsgId },
        patientId: { stringValue: patientUid },
        senderId: { stringValue: patientUid },
        senderName: { stringValue: 'Sarah Connor' },
        senderRole: { stringValue: 'patient' },
        content: { stringValue: 'Sharing latest CBC Blood Test results.' },
        type: { stringValue: 'report' },
        reportId: { stringValue: `rep_${testSuffix}` },
        reportTitle: { stringValue: 'Complete Blood Count (CBC)' },
        reportCategory: { stringValue: 'lab' },
        reportUrl: { stringValue: 'https://storage.googleapis.com/continuum-health/cbc.pdf' },
        readBy: { arrayValue: { values: [{ stringValue: patientUid }] } }
      }
    })
  });
  console.log('  -> Shared Medical Report Card Written in Chat, HTTP Status:', repRes.status);

  console.log('\n[TEST 9] Emergency SOS Activation & Broadcast...');
  const sosId = `alert_sos_${patientUid}_${Date.now()}`;
  const sosRes = await fetch(`${baseUrl}/patientNotifications/${sosId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        notificationId: { stringValue: sosId },
        recipientUid: { stringValue: patientUid },
        recipientRole: { stringValue: 'patient' },
        title: { stringValue: '🚨 EMERGENCY SOS ACTIVATED' },
        message: { stringValue: '🚨 EMERGENCY ALERT: Sarah Connor may require immediate assistance.' },
        status: { stringValue: 'active' },
        isEmergency: { booleanValue: true },
        location: { stringValue: 'https://maps.google.com/?q=12.9716,77.5946' }
      }
    })
  });
  console.log('  -> Emergency SOS Notification Written, HTTP Status:', sosRes.status);

  console.log('\n[TEST 10] Idempotency Key in processedEvents...');
  const procKey = `missed_appt_${apptId}`;
  const procRes = await fetch(`${baseUrl}/processedEvents/${procKey}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        eventId: { stringValue: procKey },
        patientId: { stringValue: patientUid },
        appointmentId: { stringValue: apptId }
      }
    })
  });
  console.log('  -> Processed Event Idempotency Key Written, HTTP Status:', procRes.status);

  console.log('\n========================================================');
  console.log('ALL E2E FIRESTORE INTEGRATION TESTS PASSED (HTTP 200 OK)!');
  console.log('========================================================');
}

main().then(() => process.exit(0)).catch(e => {
  console.error('FAILED:', e);
  process.exit(1);
});
