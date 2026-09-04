import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_layout_insets.dart';
import '../../../../data/providers/providers.dart';

class FollowUpCenterScreen extends ConsumerStatefulWidget {
  const FollowUpCenterScreen({super.key});

  @override
  ConsumerState<FollowUpCenterScreen> createState() => _FollowUpCenterScreenState();
}

class _FollowUpCenterScreenState extends ConsumerState<FollowUpCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _plans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    final uid = ref.read(currentUidProvider) ?? 'BZjQ5Yl7auZEsjxcDeE8Aa9WrRE2';
    try {
      final backend = ref.read(backendServiceProvider);
      final plans = await backend.getFollowUps(uid);
      if (mounted) {
        setState(() {
          _plans = plans;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respond(String planId, String responseType) async {
    final backend = ref.read(backendServiceProvider);
    final success = await backend.respondToFollowUp(planId, responseType);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Response recorded: $responseType. Event emitted to autonomous loop.'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadPlans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayPlans = _plans.where((p) => p['status'] == 'DUE' || p['status'] == 'SCHEDULED').toList();
    final upcomingPlans = _plans.where((p) => p['status'] == 'AWAITING_RESPONSE').toList();
    final completedPlans = _plans.where((p) => p['status'] == 'COMPLETED').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Autonomous Follow-Up Center', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Active (${todayPlans.length})'),
            Tab(text: 'Awaiting (${upcomingPlans.length})'),
            Tab(text: 'Completed (${completedPlans.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPlanList(todayPlans, isActionable: true),
                _buildPlanList(upcomingPlans, isActionable: false),
                _buildPlanList(completedPlans, isActionable: false),
              ],
            ),
    );
  }

  Widget _buildPlanList(List<Map<String, dynamic>> items, {required bool isActionable}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.checkCircle2, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No follow-up items in this section.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        AppLayoutInsets.bottomSafeInset(context) + 16,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final plan = items[index];
        final type = plan['type'] ?? 'GENERAL';
        final reason = plan['reason'] ?? '';
        final status = plan['status'] ?? '';
        final planId = plan['id'] ?? '';

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type.replaceAll('_', ' '),
                        style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: status == 'COMPLETED' ? AppColors.success : Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(reason, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                if (isActionable) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (type == 'MEDICATION_CHECKIN') ...[
                        ElevatedButton.icon(
                          onPressed: () => _respond(planId, 'TAKEN'),
                          icon: const Icon(LucideIcons.check, size: 16),
                          label: const Text('Taken'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _respond(planId, 'MISSED'),
                          icon: const Icon(LucideIcons.x, size: 16),
                          label: const Text('Missed'),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () => _respond(planId, 'CONFIRMED'),
                          icon: const Icon(LucideIcons.check, size: 16),
                          label: const Text('Confirm'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _respond(planId, 'DECLINED'),
                          icon: const Icon(LucideIcons.x, size: 16),
                          label: const Text('Decline'),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
