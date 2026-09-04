import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/activity_log_model.dart';
import '../models/appointment_model.dart';
import '../models/medication_model.dart';
import '../models/reminder_model.dart';
import '../repositories/telegram_repository.dart';
import 'activity_log_service.dart';

class MissedEventsService {
  final FirebaseFirestore? _db;
  final TelegramRepository? _telegramRepository;
  final ActivityLogService? _activityLogService;

  MissedEventsService({
    FirebaseFirestore? db,
    TelegramRepository? telegramRepository,
    ActivityLogService? activityLogService,
  })  : _db = db,
        _telegramRepository = telegramRepository,
        _activityLogService = activityLogService;

  Future<void> checkAndProcessMissedEvents(String patientUid) async {
    final db = _db;
    if (patientUid.isEmpty || db == null) return;

    try {
      // 1. Fetch Target Patient Info
      String patientName = 'Patient';

      final uDoc = await db.collection('users').doc(patientUid).get();
      if (uDoc.exists && uDoc.data() != null) {
        final uData = uDoc.data()!;
        patientName = uData['name'] as String? ?? patientName;
      } else {
        final pDoc = await db.collection('patients').doc(patientUid).get();
        if (pDoc.exists && pDoc.data() != null) {
          final pData = pDoc.data()!;
          patientName = pData['name'] as String? ?? patientName;
        }
      }

      final now = DateTime.now();

      // 2. CHECK MISSED APPOINTMENTS (Threshold: 2 minutes after scheduled time)
      final apptsSnap = await db
          .collection('patients')
          .doc(patientUid)
          .collection('appointments')
          .get();

      for (final doc in apptsSnap.docs) {
        final appt = AppointmentModel.fromFirestore(doc);
        final isPastTwoMinutes = now.difference(appt.dateTime).inMinutes >= 2;

        if (isPastTwoMinutes &&
            (appt.status == AppointmentStatus.approved || appt.status == AppointmentStatus.pending)) {
          final eventKey = 'missed_appt_${appt.id}';
          final processedDoc = await db.collection('processedEvents').doc(eventKey).get();

          if (!processedDoc.exists) {
            dev.log('[MISSED_EVENTS] Flagging missed appointment ${appt.id}', name: 'MissedEventsService');

            final batch = db.batch();
            batch.update(db.collection('appointments').doc(appt.id), {
              'status': 'missed',
              'missedNotificationSent': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            batch.update(db.collection('patients').doc(patientUid).collection('appointments').doc(appt.id), {
              'status': 'missed',
              'missedNotificationSent': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            batch.set(db.collection('processedEvents').doc(eventKey), {
              'eventId': eventKey,
              'patientId': patientUid,
              'appointmentId': appt.id,
              'notificationSent': true,
              'processedAt': FieldValue.serverTimestamp(),
            });

            // Patient-facing Notification
            final pNotifId = 'notif_p_$eventKey';
            final apptDateStr = DateFormat('MMM d, h:mm a').format(appt.dateTime);
            final patientMsg = '''
⚠️ Missed Appointment
Your appointment with Dr. ${appt.doctorName} scheduled for $apptDateStr was marked as missed.
Please reschedule or contact your care provider.
'''.trim();

            batch.set(db.collection('patientNotifications').doc(pNotifId), {
              'notificationId': pNotifId,
              'recipientUid': patientUid,
              'recipientRole': 'patient',
              'title': '⚠️ Missed Appointment',
              'message': patientMsg,
              'appointmentId': appt.id,
              'status': 'sent',
              'createdAt': FieldValue.serverTimestamp(),
            });

            // Clinician Doctor Notification
            final dNotifId = 'notif_d_$eventKey';
            final doctorMsg = 'Patient $patientName missed the scheduled appointment on $apptDateStr.';

            batch.set(db.collection('doctorNotifications').doc(dNotifId), {
              'notificationId': dNotifId,
              'recipientUid': appt.doctorId,
              'recipientRole': 'doctor',
              'title': 'Patient Missed Appointment',
              'message': doctorMsg,
              'appointmentId': appt.id,
              'patientId': patientUid,
              'status': 'sent',
              'createdAt': FieldValue.serverTimestamp(),
            });

            await batch.commit();

            // Send targeted Telegram to target patient
            await _telegramRepository?.sendTargetedTelegramNotification(
              targetPatientId: patientUid,
              text: patientMsg,
              notificationType: 'missed_appointment',
              eventId: eventKey,
            );

            // Audit log
            await _activityLogService?.logEvent(
              patientId: patientUid,
              doctorId: appt.doctorId,
              appointmentId: appt.id,
              eventType: ActivityEventType.appointmentMissed,
              title: 'Appointment Missed',
              description: 'Consultation with Dr. ${appt.doctorName} was marked as missed.',
              actorUid: patientUid,
              actorRole: 'system',
              metadata: {'scheduledTime': appt.dateTime.toIso8601String()},
            );
          }
        }
      }

      // 3. CHECK MISSED MEDICATIONS (Threshold: 2 minutes after scheduled time)
      final medsSnap = await db
          .collection('patients')
          .doc(patientUid)
          .collection('medications')
          .get();

      for (final doc in medsSnap.docs) {
        final med = MedicationModel.fromFirestore(doc);
        final isPastTwoMinutes = now.difference(med.date).inMinutes >= 2;

        if (isPastTwoMinutes && !med.isTaken && !med.isSkipped && !med.isMissed) {
          final dateStr = DateFormat('yyyy-MM-dd').format(med.date);
          final eventKey = 'medication:${med.id}:$dateStr';
          final processedDoc = await db.collection('processedEvents').doc(eventKey).get();

          if (!processedDoc.exists) {
            dev.log('[MISSED_EVENTS] Flagging missed medication ${med.name} (${med.id})', name: 'MissedEventsService');

            final batch = db.batch();
            final updateData = {
              'isMissed': true,
              'status': 'missed',
              'missedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            };

            batch.update(db.collection('patients').doc(patientUid).collection('medications').doc(med.id), updateData);
            batch.update(db.collection('medications').doc(med.id), updateData);
            batch.set(db.collection('processedEvents').doc(eventKey), {
              'eventId': eventKey,
              'patientId': patientUid,
              'medicationId': med.id,
              'notificationSent': true,
              'processedAt': FieldValue.serverTimestamp(),
            });

            // Exact requested format
            final medMsg = '''
⚠️ Medication Reminder

${med.name} — ${med.dosage}

Your scheduled medication was not marked as taken.

Please check your medication schedule.
'''.trim();

            final pNotifId = 'notif_p_${med.id}_$dateStr';
            batch.set(db.collection('patientNotifications').doc(pNotifId), {
              'notificationId': pNotifId,
              'recipientUid': patientUid,
              'recipientRole': 'patient',
              'title': '⚠️ Medication Reminder (Missed)',
              'message': medMsg,
              'medicationId': med.id,
              'status': 'sent',
              'createdAt': FieldValue.serverTimestamp(),
            });

            await batch.commit();

            // Send Telegram directly to the TARGET patient
            await _telegramRepository?.sendTargetedTelegramNotification(
              targetPatientId: patientUid,
              text: medMsg,
              notificationType: 'missed_medication',
              eventId: eventKey,
            );

            // Write to Activity Logs
            await _activityLogService?.logEvent(
              patientId: patientUid,
              medicationId: med.id,
              eventType: ActivityEventType.medicationMissed,
              title: 'Medication Missed',
              description: 'Dose not marked as taken: ${med.name} (${med.dosage}) at ${med.time}.',
              actorUid: patientUid,
              actorRole: 'system',
              metadata: {'medicineName': med.name, 'time': med.time, 'eventKey': eventKey},
            );
          }
        }
      }

      // 4. CHECK TARGET-SPECIFIC REMINDERS (Root reminders collection)
      final remsSnap = await db
          .collection('reminders')
          .where('patientId', isEqualTo: patientUid)
          .get();
      final targetRemsSnap = await db
          .collection('reminders')
          .where('targetUid', isEqualTo: patientUid)
          .get();

      final allReminderDocs = <String, DocumentSnapshot>{};
      for (final d in remsSnap.docs) {
        allReminderDocs[d.id] = d;
      }
      for (final d in targetRemsSnap.docs) {
        allReminderDocs[d.id] = d;
      }

      for (final doc in allReminderDocs.values) {
        final rem = Reminder.fromFirestore(doc);
        final isPastTwoMinutes = now.difference(rem.dateTime).inMinutes >= 2;

        if (isPastTwoMinutes && !rem.isCompleted && rem.status == 'pending') {
          final dateStr = DateFormat('yyyy-MM-dd').format(rem.dateTime);
          final eventKey = 'medication:${rem.id}:$dateStr';
          final processedDoc = await db.collection('processedEvents').doc(eventKey).get();

          if (!processedDoc.exists) {
            dev.log('[MISSED_EVENTS] Flagging missed reminder ${rem.id}', name: 'MissedEventsService');

            final batch = db.batch();
            final updateData = {
              'status': 'missed',
              'isMissed': true,
              'updatedAt': FieldValue.serverTimestamp(),
            };

            batch.update(db.collection('reminders').doc(rem.id), updateData);
            try {
              batch.update(db.collection('patients').doc(patientUid).collection('reminders').doc(rem.id), updateData);
            } catch (_) {}

            batch.set(db.collection('processedEvents').doc(eventKey), {
              'eventId': eventKey,
              'patientId': patientUid,
              'reminderId': rem.id,
              'notificationSent': true,
              'processedAt': FieldValue.serverTimestamp(),
            });

            final medName = rem.medicineName ?? rem.title;
            final dose = rem.dosage ?? '1 dose';
            final isFromFamily = (rem.createdBy != null && rem.createdBy!.isNotEmpty && rem.createdBy != patientUid) ||
                (rem.creatorUid != null && rem.creatorUid!.isNotEmpty && rem.creatorUid != patientUid);

            // Exact requested format for family missed reminders per Requirement 7
            final remMsg = isFromFamily
                ? '''
⚠️ Missed Medication

Medicine: $medName
Dosage: $dose

This medication was not marked as taken.
'''.trim()
                : '''
⚠️ Medication Reminder

$medName — $dose

Your scheduled medication was not marked as taken.

Please check your medication schedule.
'''.trim();

            final pNotifId = 'notif_p_rem_${rem.id}_$dateStr';
            batch.set(db.collection('patientNotifications').doc(pNotifId), {
              'notificationId': pNotifId,
              'recipientUid': patientUid,
              'recipientRole': 'patient',
              'title': isFromFamily ? '⚠️ Missed Medication' : '⚠️ Medication Reminder (Missed)',
              'message': remMsg,
              'reminderId': rem.id,
              'status': 'sent',
              'createdAt': FieldValue.serverTimestamp(),
            });

            await batch.commit();

            final targetUid = rem.targetUid ?? rem.patientId ?? patientUid;

            if (isFromFamily) {
              dev.log('''
[FAMILY_REMINDER]
creatorUid = ${rem.creatorUid ?? rem.createdBy}
targetUid = $targetUid
patientId = $targetUid
reminderId = ${rem.id}
reminderTime = ${rem.reminderTime ?? ''}
'''.trim(), name: 'FamilyReminder');
            }

            // Send targeted Telegram to target patient ONLY (NEVER creator)
            final tgSuccess = await _telegramRepository?.sendTargetedTelegramNotification(
              targetPatientId: targetUid,
              text: remMsg,
              notificationType: isFromFamily ? 'missed_family_reminder' : 'missed_reminder',
              eventId: eventKey,
            );

            if (isFromFamily) {
              dev.log('''
[FAMILY_TELEGRAM]
targetUid = $targetUid
sendResult = $tgSuccess
'''.trim(), name: 'FamilyReminder');
            }

            // Log event
            await _activityLogService?.logEvent(
              patientId: targetUid,
              eventType: ActivityEventType.medicationMissed,
              title: 'Medication Missed',
              description: isFromFamily
                  ? 'Scheduled dose ($medName) created by family caregiver was not marked as taken.'
                  : 'Scheduled dose ($medName) was not marked as taken.',
              actorUid: targetUid,
              actorRole: 'system',
              metadata: {
                'reminderId': rem.id,
                'medicineName': medName,
                'createdBy': rem.createdBy,
                'creatorUid': rem.creatorUid,
                'targetUid': targetUid,
                'isFromFamily': isFromFamily,
              },
            );
          }
        }
      }
    } catch (e, st) {
      dev.log('[MISSED_EVENTS] Error processing missed events: $e', name: 'MissedEventsService', error: e, stackTrace: st);
    }
  }
}
