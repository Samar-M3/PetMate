import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmatee/features/care_events/providers/care_events_provider.dart';

import '../theme/admin_colors.dart';

class AdminAppointmentsTab extends ConsumerStatefulWidget {
  const AdminAppointmentsTab({super.key});

  @override
  ConsumerState<AdminAppointmentsTab> createState() =>
      _AdminAppointmentsTabState();
}

class _AdminAppointmentsTabState extends ConsumerState<AdminAppointmentsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedStatus = 'ALL';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apptsAsync = ref.watch(appointmentsProvider);

    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Column(
        children: [
          // Filter Toolbar
          Container(
            color: AdminColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: Row(
                  children: [
                    // Search Input
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by pet name, doctor, or clinic...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: AdminColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: AdminColors.background,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AdminColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AdminColors.border,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Status Filter Chips
                    Wrap(
                      spacing: 8,
                      children: ['ALL', 'Upcoming', 'Completed', 'Cancelled']
                          .map((status) {
                            final isSel = _selectedStatus == status;
                            return ChoiceChip(
                              label: Text(status),
                              selected: isSel,
                              selectedColor: AdminColors.primary,
                              backgroundColor: AdminColors.background,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSel
                                    ? Colors.white
                                    : AdminColors.textSecondary,
                              ),
                              onSelected: (_) =>
                                  setState(() => _selectedStatus = status),
                            );
                          })
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AdminColors.border),

          // Main Appointments Table Content
          Expanded(
            child: apptsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AdminColors.primary),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 40,
                      color: AdminColors.error,
                    ),
                    const SizedBox(height: 10),
                    Text('Failed to load appointments: $err'),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(appointmentsProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (list) {
                final query = _searchCtrl.text.trim().toLowerCase();
                final filtered = list.where((a) {
                  final matchesStatus =
                      _selectedStatus == 'ALL' ||
                      a.status.toLowerCase() == _selectedStatus.toLowerCase();
                  final matchesQuery =
                      query.isEmpty ||
                      a.petName.toLowerCase().contains(query) ||
                      a.vetName.toLowerCase().contains(query) ||
                      a.clinicName.toLowerCase().contains(query) ||
                      a.reason.toLowerCase().contains(query);
                  return matchesStatus && matchesQuery;
                }).toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.read(appointmentsProvider.notifier).refresh(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 48,
                                color: AdminColors.textMuted,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No matching appointments found',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AdminColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Patient bookings will appear here as owners schedule visits.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AdminColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AdminColors.primary,
                  onRefresh: () async =>
                      ref.read(appointmentsProvider.notifier).refresh(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1300),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AdminColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AdminColors.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2.0), // Pet
                                1: FlexColumnWidth(2.5), // Doctor / Clinic
                                2: FlexColumnWidth(2.0), // Schedule
                                3: FlexColumnWidth(2.5), // Reason / Notes
                                4: FlexColumnWidth(1.4), // Status
                              },
                              children: [
                                // Table Header
                                TableRow(
                                  decoration: const BoxDecoration(
                                    color: AdminColors.background,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: AdminColors.border,
                                      ),
                                    ),
                                  ),
                                  children: [
                                    _headerCell('Patient (Pet)'),
                                    _headerCell('Doctor & Clinic'),
                                    _headerCell('Schedule'),
                                    _headerCell('Reason & Notes'),
                                    _headerCell('Status'),
                                  ],
                                ),
                                // Table Rows
                                for (final appt in filtered)
                                  TableRow(
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: AdminColors.borderLight,
                                        ),
                                      ),
                                    ),
                                    children: [
                                      // Patient
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(7),
                                              decoration: BoxDecoration(
                                                color: AdminColors.primaryLight,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.pets,
                                                size: 16,
                                                color: AdminColors.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                appt.petName,
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      AdminColors.textPrimary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Doctor & Clinic
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              appt.vetName,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AdminColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              appt.clinicName,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color:
                                                    AdminColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Schedule
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              appt.date,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AdminColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              appt.timeSlot,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color:
                                                    AdminColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Reason & Notes
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              appt.reason,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: AdminColors.textPrimary,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (appt.vetNotes != null)
                                              Text(
                                                'Notes: ${appt.vetNotes}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AdminColors.textMuted,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),

                                      // Status Badge
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: _buildStatusBadge(appt.status),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AdminColors.textSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = AdminColors.infoLight;
    Color text = AdminColors.info;

    if (status.toLowerCase() == 'completed') {
      bg = AdminColors.successLight;
      text = AdminColors.success;
    } else if (status.toLowerCase() == 'cancelled') {
      bg = AdminColors.errorLight;
      text = AdminColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }
}
