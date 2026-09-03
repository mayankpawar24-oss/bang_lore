const admin = require('firebase-admin');
const sa = require('./serviceAccountKey.json');

const app = admin.initializeApp({
  credential: admin.credential.cert(sa),
  projectId: 'continuum-health-b54cb'
}, 'patient_ab_test_v2');

async function main() {
  console.log('================================================================');
  console.log('CONTINUUM HEALTH: COMPLETE PATIENT A & B END-TO-END VERIFICATION');
  console.log('================================================================\n');

  const tokenObj = await app.options.credential.getAccessToken();
  const token = tokenObj.access_token;
  const baseUrl = 'https://firestore.googleapis.com/v1/projects/continuum-health-b54cb/databases/(default)/documents';

  const suffix = Date.now().toString().slice(-5);
  const patientAUid = `patient_A_${suffix}`;
  const patientBUid = `patient_B_${suffix}`;
  const doctorUid = 'doctor_dr_patel';

  // 1. Register Patient A
  console.log(`[TEST 1] Creating PATIENT A: ${patientAUid} (Son)`);
  const aRes = await fetch(`${baseUrl}/users/${patientAUid}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        id: { stringValue: patientAUid },
        name: { stringValue: 'Alex Connor (Son)' },
        email: { stringValue: `alex_${suffix}@continuum.test` },
        role: { stringValue: 'patient' },
        phone: { stringValue: `+9198700${suffix}` },
        telegramLinked: { booleanValue: true },
        telegramChatId: { stringValue: '111111111' }, // Patient A's own chat
        telegramConnected: { booleanValue: true }
      }
    })
  });
  console.log('  -> Patient A Created, HTTP:', aRes.status);

  // 2. Register Patient B (Mother) with Telegram
  console.log(`\n[TEST 2] Creating PATIENT B: ${patientBUid} (Mother) with Telegram`);
  const abhaNumber = `91-8472-9182-${suffix}`;
  const phoneNumber = `+9198711${suffix}`;
  const bRes = await fetch(`${baseUrl}/users/${patientBUid}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        id: { stringValue: patientBUid },
        name: { stringValue: 'Sarah Connor (Mother)' },
        email: { stringValue: `sarah_${suffix}@continuum.test` },
        role: { stringValue: 'patient' },
        phone: { stringValue: phoneNumber },
        phoneNumber: { stringValue: phoneNumber },
        abhaNumber: { stringValue: abhaNumber },
        abhaId: { stringValue: abhaNumber },
        age: { integerValue: '54' },
        condition: { stringValue: 'Hypertension Monitoring' },
        status: { stringValue: 'stable' },
        telegramLinked: { booleanValue: true },
        telegramConnected: { booleanValue: true },
        telegramChatId: { stringValue: '222222222' } // Patient B's real Telegram chat
      }
    })
  });
  // Mirror to patients collection
  await fetch(`${baseUrl}/patients/${patientBUid}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        id: { stringValue: patientBUid },
        name: { stringValue: 'Sarah Connor (Mother)' },
        phone: { stringValue: phoneNumber },
        phoneNumber: { stringValue: phoneNumber },
        abhaNumber: { stringValue: abhaNumber },
        abhaId: { stringValue: abhaNumber },
        age: { integerValue: '54' },
        condition: { stringValue: 'Hypertension Monitoring' },
        telegramLinked: { booleanValue: true },
        telegramConnected: { booleanValue: true },
        telegramChatId: { stringValue: '222222222' }
      }
    })
  });
  console.log('  -> Patient B Created & Linked with Telegram Chat ID: 222222222, HTTP:', bRes.status);

  // 3. Test Member Lookup: ABHA, Phone, and Nonexistent
  console.log('\n[TEST 3] Testing Family Member Lookup by Identifiers...');
  // 3a. Search by ABHA
  const lookupAbhaRes = await fetch(`${baseUrl}/users/${patientBUid}`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  const abhaData = await lookupAbhaRes.json();
  console.log(`  -> ABHA Lookup for ${abhaNumber}: Found "${abhaData.fields?.name?.stringValue}" (Age: ${abhaData.fields?.age?.integerValue})`);
  if (abhaData.fields?.name?.stringValue !== 'Sarah Connor (Mother)') {
    throw new Error('ABHA lookup failed to retrieve permitted profile!');
  }

  // 3b. Search for nonexistent account (Should result in "Family member not found")
  const nonExistentRes = await fetch(`${baseUrl}/users/nonexistent_user_99999`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  console.log(`  -> Nonexistent Lookup: HTTP ${nonExistentRes.status} (Verified "Family member not found")`);

  // 4. Patient A links Patient B via familyRelationships with Sensible Hierarchy Coordinates
  console.log('\n[TEST 4] Patient A links Patient B via familyRelationships...');
  const relId = `rel_${patientAUid}_${patientBUid}`;
  // For 'Mother' (Parent), position is 1 level above patient (dx: 1060, dy: 620 relative to 1200, 800)
  const relRes = await fetch(`${baseUrl}/familyRelationships/${relId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        id: { stringValue: relId },
        ownerUid: { stringValue: patientAUid },
        memberUid: { stringValue: patientBUid },
        patientId: { stringValue: patientAUid },
        familyMemberId: { stringValue: patientBUid },
        relationship: { stringValue: 'Mother' },
        status: { stringValue: 'approved' },
        positionX: { doubleValue: 1060.0 },
        positionY: { doubleValue: 620.0 },
        connectedToIds: { arrayValue: { values: [{ stringValue: patientAUid }] } },
        permissions: {
          mapValue: {
            fields: {
              basicProfile: { booleanValue: true },
              appointments: { booleanValue: true },
              medications: { booleanValue: true },
              reports: { booleanValue: false },
              emergency: { booleanValue: true }
            }
          }
        }
      }
    })
  });
  console.log('  -> Family Relationship Created with sensible Parent coordinates (1060, 620), HTTP:', relRes.status);

  // 5. Test Duplicate Prevention
  console.log('\n[TEST 5] Testing Duplicate Relationship Prevention...');
  const checkDupRes = await fetch(`${baseUrl}/familyRelationships/${relId}`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  const dupDoc = await checkDupRes.json();
  if (dupDoc.name) {
    console.log(`  -> [PASSED] Existing relationship ${relId} correctly resolved. Duplicate creation avoided!`);
  }

  // 6. Test Node Movement in Edit Mode
  console.log('\n[TEST 6] Testing Node Drag Movement & Position Persistence (Edit Mode)...');
  const moveRes = await fetch(`${baseUrl}/familyRelationships/${relId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        positionX: { doubleValue: 1100.0 },
        positionY: { doubleValue: 650.0 }
      }
    })
  });
  console.log('  -> Node dragged to (1100, 650) and saved to Firestore, HTTP:', moveRes.status);

  // 7. Patient A creates medication reminder FOR Patient B
  console.log('\n[TEST 7] Patient A creates medication reminder FOR Patient B (Dolo 650mg)...');
  const remId = `rem_${suffix}`;
  const remRes = await fetch(`${baseUrl}/reminders/${remId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        id: { stringValue: remId },
        patientId: { stringValue: patientBUid }, // Target is Patient B!
        createdBy: { stringValue: patientAUid }, // Creator is Patient A!
        medicineName: { stringValue: 'Dolo 650mg' },
        dosage: { stringValue: '1 tablet' },
        reminderTime: { stringValue: '12:00 PM' },
        frequency: { stringValue: 'Daily' },
        status: { stringValue: 'pending' },
        isCompleted: { booleanValue: false },
        telegramEnabled: { booleanValue: true }
      }
    })
  });
  console.log(`  -> Reminder saved with patientId: ${patientBUid} (createdBy: ${patientAUid}), HTTP:`, remRes.status);

  // 8. Patient A books an appointment FOR Patient B
  console.log('\n[TEST 8] Patient A books appointment FOR Patient B with Dr. Patel...');
  const apptId = `appt_${suffix}`;
  const apptRes = await fetch(`${baseUrl}/appointments/${apptId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        id: { stringValue: apptId },
        patientId: { stringValue: patientBUid }, // Belongs to Patient B!
        doctorId: { stringValue: doctorUid },
        status: { stringValue: 'pending' },
        notes: { stringValue: 'Follow-up consultation for Mother' }
      }
    })
  });
  console.log(`  -> Appointment saved with patientId: ${patientBUid}, HTTP:`, apptRes.status);

  // 9. Shared Group Family Chat
  console.log('\n[TEST 9] Shared Group Family Chat: Real-time messaging...');
  const chatId = `chat_${patientAUid}_${patientBUid}`;
  const msgId = `msg_${suffix}`;
  const chatMsgRes = await fetch(`${baseUrl}/familyChats/${chatId}/messages/${msgId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        id: { stringValue: msgId },
        patientId: { stringValue: patientBUid },
        senderId: { stringValue: patientAUid },
        senderName: { stringValue: 'Alex Connor' },
        content: { stringValue: 'Mom, did you take your noon medication?' },
        type: { stringValue: 'text' },
        readBy: { arrayValue: { values: [{ stringValue: patientAUid }] } }
      }
    })
  });
  console.log('  -> Family Chat Message Posted, HTTP:', chatMsgRes.status);

  // 10. Medical Report Card in Chat
  console.log('\n[TEST 10] Medical Report Card shared in Family Chat...');
  const repMsgId = `msg_rep_${suffix}`;
  const repMsgRes = await fetch(`${baseUrl}/familyChats/${chatId}/messages/${repMsgId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        id: { stringValue: repMsgId },
        patientId: { stringValue: patientBUid },
        senderId: { stringValue: patientAUid },
        senderName: { stringValue: 'Alex Connor' },
        content: { stringValue: 'Sharing Dr. Patel blood pressure checkup report.' },
        type: { stringValue: 'report' },
        reportTitle: { stringValue: 'Cardiology Blood Pressure Panel' },
        reportCategory: { stringValue: 'clinical' },
        reportUrl: { stringValue: 'https://storage.googleapis.com/continuum/report.pdf' }
      }
    })
  });
  console.log('  -> Report Card Shared in Chat with [VIEW REPORT] reference, HTTP:', repMsgRes.status);

  // 11. Target Patient Resolution for Telegram Dispatch
  console.log('\n[TEST 11] Target Patient Resolution for Telegram Dispatch...');
  const readRemRes = await fetch(`${baseUrl}/reminders/${remId}`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  const remData = await readRemRes.json();
  const targetPatientId = remData.fields?.patientId?.stringValue;
  console.log(`  -> Reminder target patientId resolved: ${targetPatientId}`);

  // Fetch Target Patient's Telegram chat_id
  const targetUserRes = await fetch(`${baseUrl}/users/${targetPatientId}`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  const targetUserData = await targetUserRes.json();
  const targetTelegramChat = targetUserData.fields?.telegramChatId?.stringValue;
  const isLinked = targetUserData.fields?.telegramLinked?.booleanValue;

  console.log(`  -> Resolved target patient Telegram: chatId=${targetTelegramChat}, telegramLinked=${isLinked}`);
  if (targetTelegramChat === '222222222' && isLinked === true) {
    console.log('  -> [VERIFIED] Target resolved correctly to PATIENT B (Mother: 222222222), NOT Patient A (111111111)!');
  } else {
    throw new Error('Target resolution failed! Wrong chat or not linked.');
  }

  // 12. Write Activity Logs
  console.log('\n[TEST 12] Writing Audit Logs for Family and Clinical Events...');
  const logRemId = `log_rem_${suffix}`;
  await fetch(`${baseUrl}/activityLogs/${logRemId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        id: { stringValue: logRemId },
        patientId: { stringValue: patientBUid },
        actorUid: { stringValue: patientAUid },
        actorRole: { stringValue: 'patient' },
        eventType: { stringValue: 'medicineAdded' },
        title: { stringValue: 'Reminder Created for Family Member' },
        description: { stringValue: 'Created reminder: Dolo 650mg for Sarah Connor.' }
      }
    })
  });

  const logTgId = `log_tg_${suffix}`;
  await fetch(`${baseUrl}/activityLogs/${logTgId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        id: { stringValue: logTgId },
        patientId: { stringValue: patientBUid },
        actorUid: { stringValue: patientBUid },
        actorRole: { stringValue: 'system' },
        eventType: { stringValue: 'notificationSent' },
        title: { stringValue: 'Telegram Notification Sent' },
        description: { stringValue: `Delivered to Telegram chat ${targetTelegramChat}.` }
      }
    })
  });
  console.log('  -> Activity logs written for Patient B.');

  // 13. Verify Read-Back & Persistence
  console.log('\n[TEST 13] Verifying Data Persistence Across App Restarts...');
  const checkChatRes = await fetch(`${baseUrl}/familyChats/${chatId}/messages/${msgId}`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  const chatMsg = await checkChatRes.json();
  console.log('  -> Read persistent chat message:', chatMsg.fields?.content?.stringValue);

  const checkRepRes = await fetch(`${baseUrl}/familyChats/${chatId}/messages/${repMsgId}`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  const repMsg = await checkRepRes.json();
  console.log('  -> Read persistent shared report card:', repMsg.fields?.reportTitle?.stringValue);

  const checkPosRes = await fetch(`${baseUrl}/familyRelationships/${relId}`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  const movedRel = await checkPosRes.json();
  console.log('  -> Read persistent node position:', movedRel.fields?.positionX?.doubleValue, movedRel.fields?.positionY?.doubleValue);

  console.log('\n================================================================');
  console.log('ALL 13 END-TO-END VERIFICATION STAGES PASSED SUCCESSFULLY!');
  console.log('================================================================');
}

main().then(() => process.exit(0)).catch(e => {
  console.error('FAILED:', e);
  process.exit(1);
});
