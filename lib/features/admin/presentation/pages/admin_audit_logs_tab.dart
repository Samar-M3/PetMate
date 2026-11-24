import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/admin_audit_log_model.dart';
import '../providers/admin_provider.dart';
import '../theme/admin_colors.dart';

class AdminAuditLogsTab extends ConsumerStatefulWidget {
  const AdminAuditLogsTab({super.key});

  @override
  ConsumerState<AdminAuditLogsTab> createState() => _AdminAuditLogsTabState();
}

class _AdminAuditLogsTabState extends ConsumerState<AdminAuditLogsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(adminAuditLogsProvider);

    return Container(
      color: AdminColors.background,
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              color: AdminColors.surface,
              border: Border(
                bottom: BorderSide(color: AdminColors.border, width: 1.0),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim().toLowerCase());
                      },
                      style: const TextStyle(
                        fontSize: 13,
                        color: AdminColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Search audit logs by actor, action, or target...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AdminColors.textMuted,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: AdminColors.textMuted,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                color: AdminColors.textMuted,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AdminColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 0,
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
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: AdminColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(adminAuditLogsProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AdminColors.border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: logsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AdminColors.primary),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AdminColors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Error loading audit logs: $err',
                      style: const TextStyle(
                        color: AdminColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(adminAuditLogsProvider.notifier).refresh(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (logs) {
                final filtered = logs.where((l) {
                  if (_searchQuery.isEmpty) return true;
                  return l.action.toLowerCase().contains(_searchQuery) ||
                      (l.actorEmail?.toLowerCase().contains(_searchQuery) ??
                          false) ||
                      (l.targetEmail?.toLowerCase().contains(_searchQuery) ??
                          false);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AdminColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AdminColors.border),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            size: 36,
                            color: AdminColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No audit logs recorded',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Security and administrative actions will appear here in real time.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideScreen = constraints.maxWidth >= 850;

                    return RefreshIndicator(
                      color: AdminColors.primary,
                      onRefresh: () async =>
                          ref.read(adminAuditLogsProvider.notifier).refresh(),
                      child: isWideScreen
                          ? _buildDataTable(filtered)
                          : _buildCardList(filtered),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<AdminAuditLogModel> logs) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              color: AdminColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: const Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'ACTION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'ACTOR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'TARGET',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'CHANGES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'TIMESTAMP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: AdminColors.border),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                thickness: 1,
                color: AdminColors.borderLight,
              ),
              itemBuilder: (context, index) {
                final log = logs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      // Action
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildActionBadge(log.action),
                        ),
                      ),
                      // Actor
                      Expanded(
                        flex: 3,
                        child: Text(
                          log.actorEmail ?? log.actorId ?? 'System',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AdminColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Target
                      Expanded(
                        flex: 3,
                        child: Text(
                          log.targetEmail ?? log.targetId ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AdminColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Changes
                      Expanded(
                        flex: 3,
                        child: Text(
                          _formatChanges(log),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                      ),
                      // Timestamp
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatDateTime(log.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AdminColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardList(List<AdminAuditLogModel> logs) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final log = logs[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildActionBadge(log.action),
                  Text(
                    _formatDateTime(log.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AdminColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'By: ${log.actorEmail ?? log.actorId ?? "System"}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.textPrimary,
                ),
              ),
              if (log.targetEmail != null || log.targetId != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Target: ${log.targetEmail ?? log.targetId}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AdminColors.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AdminColors.borderLight),
                ),
                child: Text(
                  _formatChanges(log),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionBadge(String action) {
    Color color;
    Color bg;

    if (action.contains('APPROVE') || action.contains('CREATE')) {
      color = AdminColors.success;
      bg = AdminColors.successLight;
    } else if (action.contains('REJECT') ||
        action.contains('SUSPEND') ||
        action.contains('REVOKE')) {
      color = AdminColors.error;
      bg = AdminColors.errorLight;
    } else if (action.contains('ROLE')) {
      color = AdminColors.purple;
      bg = AdminColors.purpleLight;
    } else {
      color = AdminColors.info;
      bg = AdminColors.infoLight;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        action.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _formatChanges(AdminAuditLogModel log) {
    if (log.oldValue != null && log.newValue != null) {
      return '${log.oldValue} → ${log.newValue}';
    }
    if (log.newValue != null) {
      return 'Set to ${log.newValue}';
    }
    if (log.notes != null && log.notes!.isNotEmpty) {
      return log.notes!;
    }
    return 'Action executed';
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${months[dt.month - 1]} ${dt.day}, $time';
  }
}
