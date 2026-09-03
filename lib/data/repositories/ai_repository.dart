abstract class AIRepository {
  Future<String> sendMessage(String message);
  Future<List<String>> getAIInsights(String patientId);
}

class MockAIRepository implements AIRepository {
  @override
  Future<String> sendMessage(String message) async {
    await Future.delayed(const Duration(seconds: 1));
    final lower = message.toLowerCase();
    
    if (lower.contains('medicine') || lower.contains('medication')) {
      return 'Based on your records, you took Furosemide at 8:00 AM today. Your evening dose of Lisinopril is scheduled for 6:00 PM.';
    } else if (lower.contains('appointment')) {
      return 'Your next appointment is with Dr. Aisha Patel tomorrow at 10:30 AM. Would you like me to set a reminder?';
    } else if (lower.contains('cardiologist')) {
      return 'I found 2 cardiologists near you. Dr. Aisha Patel (1.2 km) has excellent ratings. Would you like to book an appointment?';
    } else if (lower.contains('report')) {
      return 'Your latest blood test from August 15 shows your cholesterol levels are within the normal range, but we need to monitor your blood pressure.';
    }
    
    return 'I understand your concern. Based on your health profile, I recommend discussing this with your primary care physician. Would you like me to help you book an appointment?';
  }

  @override
  Future<List<String>> getAIInsights(String patientId) async {
    await Future.delayed(const Duration(seconds: 1));
    return [
      'Your medication adherence has dropped this week. Remember to take Lisinopril every evening.',
      'Your heart rate has been stable over the last 3 days.',
      'You have an upcoming appointment with Dr. Patel tomorrow.'
    ];
  }
}
