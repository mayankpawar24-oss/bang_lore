import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/notification_sheet.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/report_model.dart';
import '../../../../data/models/medication_model.dart';
import '../../../../data/models/vital_model.dart';
import '../../../../data/models/reminder_model.dart';

enum TimelineFilter { all, reports, appointments, medications, vitals, reminders }

class TimelineEventItem {
  final String id;
  final String title;
  final String subtitle;
  final String? details;
  final DateTime timestamp;
  final TimelineFilter category;
  final IconData icon;
  final Color color;
  final String? statusLabel;
  final Color? statusColor;
  final Map<String, dynamic>? metadata;

  const TimelineEventItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.details,
    required this.timestamp,
    required this.category,
    required this.icon,
    required this.color,
    this.statusLabel,
    this.statusColor,
    this.metadata,
  });
}

class PatientTimelineScreen extends ConsumerStatefulWidget {
  const PatientTimelineScreen({super.key});

  @override
  ConsumerState<PatientTimelineScreen> createState() => _PatientTimelineScreenState();
}

class _PatientTimelineScreenState extends ConsumerState<PatientTimelineScreen> {
  TimelineFilter _selectedFilter = TimelineFilter.all;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isCalendarExpanded = false;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifications = ref.watch(notificationsStreamProvider).valueOrNull ?? [];
    final unreadCount = notifications.where((n) => !n.isRead).length;

    final reports = ref.watch(reportsStreamProvider).valueOrNull ?? [];
    final appointments = ref.watch(appointmentsStreamProvider).valueOrNull ?? [];
    final medications = ref.watch(medicationsStreamProvider).valueOrNull ?? [];
    final vitals = ref.watch(vitalsStreamProvider).valueOrNull ?? [];
    final reminders = ref.watch(remindersStreamProvider).valueOrNull ?? [];

    final events = _buildUnifiedTimeline(reports, appointments, medications, vitals, reminders);

    final filteredEvents = events.where((e) {
      if (_selectedFilter == TimelineFilter.all) return true;
      return e.category == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, unreadCount, isDark),
            _buildCalendarSection(appointments, isDark),
            const SizedBox(height: 10),
            _buildFilterChips(isDark),
            const SizedBox(height: 8),
            Expanded(
              child: filteredEvents.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: filteredEvents.length,
                      itemBuilder: (context, index) {
                        final event = filteredEvents[index];
                        final isLast = index == filteredEvents.length - 1;
                        return _buildTimelineTile(event, isLast, isDark)
                            .animate()
                            .fadeIn(duration: 250.ms, delay: (25 * index).ms)
                            .slideY(begin: 0.04);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection(List<AppointmentModel> appointments, bool isDark) {
    final now = DateTime.now();
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstWeekday = (DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday) % 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        borderRadius: 20,
        elevation: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.calendar, size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMMM yyyy').format(_focusedMonth),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.navy,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      icon: Icon(LucideIcons.chevronLeft, size: 18, color: isDark ? Colors.white70 : AppColors.navy),
                      onPressed: () {
                        setState(() {
                          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                        });
                      },
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      icon: Icon(LucideIcons.chevronRight, size: 18, color: isDark ? Colors.white70 : AppColors.navy),
                      onPressed: () {
                        setState(() {
                          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                        });
                      },
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        _isCalendarExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                        size: 18,
                        color: AppColors.primaryBlue,
                      ),
                      onPressed: () {
                        setState(() {
                          _isCalendarExpanded = !_isCalendarExpanded;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            if (_isCalendarExpanded) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) {
                  return Text(
                    d,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.muted),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: firstWeekday + daysInMonth,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1.2,
                ),
                itemBuilder: (context, index) {
                  if (index < firstWeekday) return const SizedBox.shrink();
                  final dayNum = index - firstWeekday + 1;
                  final dayDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);

                  final isSelected = _isSameDay(dayDate, _selectedDate);
                  final isToday = _isSameDay(dayDate, now);
                  final dayAppts = appointments.where((a) => _isSameDay(a.dateTime, dayDate)).toList();

                  return GestureDetector(
                    onTap: () => setState(() => _selectedDate = dayDate),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryBlue
                            : (isToday
                                ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : AppColors.softBlue)
                                : Colors.transparent),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : (isToday
                                      ? AppColors.primaryBlue
                                      : (isDark ? Colors.white : AppColors.navy)),
                            ),
                          ),
                          if (dayAppts.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: dayAppts.take(3).map((a) {
                                Color dotColor = AppColors.success;
                                if (a.status == AppointmentStatus.pending || a.status == AppointmentStatus.requested) {
                                  dotColor = AppColors.warning;
                                } else if (a.status == AppointmentStatus.cancelled || a.status == AppointmentStatus.rejected) {
                                  dotColor = AppColors.danger;
                                }
                                return Container(
                                  width: 3.5,
                                  height: 3.5,
                                  margin: const EdgeInsets.symmetric(horizontal: 0.8),
                                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _CalendarLegendDot(color: AppColors.success, label: 'Approved'),
                  SizedBox(width: 12),
                  _CalendarLegendDot(color: AppColors.warning, label: 'Pending'),
                  SizedBox(width: 12),
                  _CalendarLegendDot(color: AppColors.danger, label: 'Cancelled'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int unreadCount, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Care Timeline',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.navy,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Your continuous health journey & milestones',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => context.push('/patient/dashboard/doctor-search'),
                icon: const Icon(LucideIcons.userPlus, color: AppColors.primaryBlue),
                tooltip: 'Find Doctor',
              ),
              Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      LucideIcons.bell,
                      color: isDark ? Colors.white : AppColors.navy,
                      size: 24,
                    ),
                    onPressed: () => NotificationSheet.show(context),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final filters = [
      {'key': TimelineFilter.all, 'label': 'All Events'},
      {'key': TimelineFilter.reports, 'label': 'Reports & EMR'},
      {'key': TimelineFilter.appointments, 'label': 'Consultations'},
      {'key': TimelineFilter.medications, 'label': 'Medications'},
      {'key': TimelineFilter.vitals, 'label': 'Vitals'},
      {'key': TimelineFilter.reminders, 'label': 'Follow-ups'},
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = filters[index];
          final key = item['key'] as TimelineFilter;
          final label = item['label'] as String;
          final isSelected = _selectedFilter == key;

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryBlue
                    : (isDark ? const Color(0xFF131C2E) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryBlue
                      : (isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.border),
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<TimelineEventItem> _buildUnifiedTimeline(
    List<ReportModel> reports,
    List<AppointmentModel> appointments,
    List<MedicationModel> medications,
    List<Vital> vitals,
    List<ReminderModel> reminders,
  ) {
    final List<TimelineEventItem> list = [];

    // 1. Reports
    for (final r in reports) {
      IconData icon = LucideIcons.fileText;
      Color color = AppColors.primaryBlue;
      if (r.category == ReportCategory.discharge) {
        icon = LucideIcons.building;
        color = const Color(0xFF8B5CF6);
      } else if (r.category == ReportCategory.lab) {
        icon = LucideIcons.flaskConical;
        color = AppColors.accentCyan;
      } else if (r.category == ReportCategory.prescription) {
        icon = LucideIcons.pill;
        color = AppColors.success;
      }

      list.add(
        TimelineEventItem(
          id: 'report_${r.id}',
          title: r.title,
          subtitle: '${r.category.name.toUpperCase()} • ${r.doctorOrFacility ?? "Health Record"}',
          details: r.summary ?? r.followUpInstructions,
          timestamp: r.date,
          category: TimelineFilter.reports,
          icon: icon,
          color: color,
          statusLabel: 'VERIFIED',
          statusColor: AppColors.success,
        ),
      );
    }

    // 2. Appointments
    for (final a in appointments) {
      final isUpcoming = a.dateTime.isAfter(DateTime.now());
      String statusStr = 'SCHEDULED';
      Color statusCol = AppColors.primaryBlue;
      if (a.status == AppointmentStatus.pending || a.status == AppointmentStatus.requested) {
        statusStr = 'PENDING';
        statusCol = AppColors.warning;
      } else if (a.status == AppointmentStatus.cancelled || a.status == AppointmentStatus.rejected) {
        statusStr = 'CANCELLED';
        statusCol = AppColors.danger;
      } else if (!isUpcoming) {
        statusStr = 'COMPLETED';
        statusCol = AppColors.success;
      }

      list.add(
        TimelineEventItem(
          id: 'appt_${a.id}',
          title: 'Consultation: ${a.doctorName.isNotEmpty ? a.doctorName : "Doctor"}',
          subtitle: '${a.specialty} • ${DateFormat('hh:mm a').format(a.dateTime)}',
          details: a.notes,
          timestamp: a.dateTime,
          category: TimelineFilter.appointments,
          icon: LucideIcons.calendar,
          color: AppColors.primaryBlue,
          statusLabel: statusStr,
          statusColor: statusCol,
        ),
      );
    }

    // 3. Medications
    for (final m in medications) {
      list.add(
        TimelineEventItem(
          id: 'med_${m.id}',
          title: 'Medication: ${m.name} ${m.dosage}',
          subtitle: '${m.frequency ?? "Daily"} • ${m.times.join(", ")}',
          details: 'Scheduled time: ${m.time}',
          timestamp: DateTime.now().subtract(const Duration(hours: 4)),
          category: TimelineFilter.medications,
          icon: LucideIcons.pill,
          color: AppColors.accentCyan,
          statusLabel: m.isTaken ? 'TAKEN' : 'SCHEDULED',
          statusColor: m.isTaken ? AppColors.success : AppColors.warning,
        ),
      );
    }

    // 4. Vitals
    for (final v in vitals) {
      list.add(
        TimelineEventItem(
          id: 'vital_${v.id}',
          title: 'Vital Milestone Recorded',
          subtitle: 'HR: ${v.heartRate} bpm • BP: ${v.systolic}/${v.diastolic} • SpO₂: ${v.spo2}%',
          details: v.weight != null ? 'Weight: ${v.weight} kg' : null,
          timestamp: v.recordedAt,
          category: TimelineFilter.vitals,
          icon: LucideIcons.activity,
          color: AppColors.danger,
          statusLabel: 'NORMAL',
          statusColor: AppColors.success,
        ),
      );
    }

    // 5. Reminders
    for (final rem in reminders) {
      list.add(
        TimelineEventItem(
          id: 'rem_${rem.id}',
          title: rem.title,
          subtitle: DateFormat('EEEE, MMM d • hh:mm a').format(rem.dateTime),
          details: rem.description,
          timestamp: rem.dateTime,
          category: TimelineFilter.reminders,
          icon: LucideIcons.bell,
          color: AppColors.warning,
          statusLabel: rem.isCompleted ? 'COMPLETED' : 'PENDING',
          statusColor: rem.isCompleted ? AppColors.success : AppColors.warning,
        ),
      );
    }

    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Widget _buildTimelineTile(TimelineEventItem event, bool isLast, bool isDark) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator line + circle
          SizedBox(
            width: 38,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: event.color.withValues(alpha: isDark ? 0.25 : 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: event.color.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Icon(event.icon, color: event.color, size: 16),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDark ? const Color(0xFF1E293B) : AppColors.border,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                borderRadius: 16,
                elevation: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : AppColors.navy,
                            ),
                          ),
                        ),
                        if (event.statusLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (event.statusColor ?? AppColors.primaryBlue).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              event.statusLabel!,
                              style: TextStyle(
                                color: event.statusColor ?? AppColors.primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.subtitle,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    if (event.details != null && event.details!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        event.details!,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : AppColors.navy,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('MMM d, yyyy • hh:mm a').format(event.timestamp),
                          style: const TextStyle(color: AppColors.muted, fontSize: 11),
                        ),
                        Icon(LucideIcons.chevronRight, size: 14, color: isDark ? Colors.white38 : AppColors.muted),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131C2E) : AppColors.softBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.history, size: 40, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 16),
            Text(
              'No Timeline Events Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload a health record, book a doctor consultation, or log your vitals to start your care journey.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : AppColors.secondaryText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Find Specialists',
              icon: LucideIcons.search,
              isFullWidth: false,
              onPressed: () => context.push('/patient/dashboard/doctor-search'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _CalendarLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
