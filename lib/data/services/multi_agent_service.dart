class AgentInsight {
  final String agentName;
  final String insight;
  final String severity; // info, warning, critical

  const AgentInsight({
    required this.agentName,
    required this.insight,
    required this.severity,
  });
}

class CareAction {
  final String action;
  final String reason;
  final String target; // patient, doctor, family

  const CareAction({
    required this.action,
    required this.reason,
    required this.target,
  });
}

class MultiAgentResult {
  final List<AgentInsight> insights;
  final List<CareAction> actions;

  const MultiAgentResult({
    required this.insights,
    required this.actions,
  });
}

class MultiAgentService {
  Future<MultiAgentResult> processPatientData(String patientId) async {
    await Future.delayed(const Duration(seconds: 2));
    
    final context = _contextAgent(patientId);
    final risks = _riskAgent(context);
    final medicationInsights = _medicationAgent(context);
    
    final allInsights = [...risks, ...medicationInsights];
    final validated = _validationAgent(allInsights);
    
    final actions = _decisionAgent(validated);
    
    return MultiAgentResult(
      insights: validated,
      actions: actions,
    );
  }

  Map<String, dynamic> _contextAgent(dynamic data) {
    // Collects recent health context
    return {
      'recentVitals': 'stable',
      'medicationAdherence': 78,
      'missedDoses': 2,
    };
  }

  List<AgentInsight> _riskAgent(Map<String, dynamic> context) {
    final List<AgentInsight> insights = [];
    if (context['medicationAdherence'] < 80) {
      insights.add(
        const AgentInsight(
          agentName: 'Risk Agent',
          insight: 'Medication adherence decreased from 94% to 78%',
          severity: 'warning',
        ),
      );
    }
    return insights;
  }

  List<AgentInsight> _medicationAgent(Map<String, dynamic> context) {
    final List<AgentInsight> insights = [];
    if (context['missedDoses'] > 0) {
      insights.add(
        const AgentInsight(
          agentName: 'Medication Agent',
          insight: 'Missed evening doses of Lisinopril on Tuesday and Wednesday',
          severity: 'warning',
        ),
      );
    }
    return insights;
  }

  List<AgentInsight> _validationAgent(List<AgentInsight> insights) {
    // Validates the insights found
    final validated = <AgentInsight>[];
    for (var insight in insights) {
      if (insight.agentName == 'Risk Agent') {
        validated.add(
          AgentInsight(
            agentName: 'Validation Agent',
            insight: 'Trend confirmed across 7 days: ${insight.insight}',
            severity: insight.severity,
          ),
        );
      } else {
        validated.add(insight);
      }
    }
    return validated;
  }

  List<CareAction> _decisionAgent(List<AgentInsight> validatedInsights) {
    // Decides actions based on validated insights
    final actions = <CareAction>[];
    
    bool hasWarnings = validatedInsights.any((i) => i.severity == 'warning');
    if (hasWarnings) {
      actions.add(
        const CareAction(
          action: 'Send reminder to patient, alert family member',
          reason: 'Address declining medication adherence',
          target: 'patient',
        ),
      );
      actions.add(
        const CareAction(
          action: 'Flag for next consultation',
          reason: 'Doctor should discuss adherence challenges',
          target: 'doctor',
        ),
      );
    }
    
    return actions;
  }
}
