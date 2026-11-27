import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/app_notification_model.dart';
import '../../../../core/services/in_app_notification_service.dart';
import '../../../care_events/screens/appointments/my_appointments_screen.dart';
import '../../../care_events/screens/events_home_screen.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inAppNotificationsProvider);
    final notifications = state.notifications;
    final unreadCount = state.unreadCount;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/');
            }
          },
        ),
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.terracotta,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () {
                ref.read(inAppNotificationsProvider.notifier).markAllAsRead();
              },
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref
                  .read(inAppNotificationsProvider.notifier)
                  .syncPendingOnResume(),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  indent: 74,
                  endIndent: 16,
                  color: AppColors.border,
                ),
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  return _NotificationTile(
                    notification: notif,
                    onTap: () => _handleNotificationTap(context, ref, notif),
                  );
                },
              ),
            ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
    AppNotification notif,
  ) {
    if (!notif.isRead) {
      ref.read(inAppNotificationsProvider.notifier).markAsRead(notif.id);
    }

    final route = notif.route ?? notif.data['route'];
    final type = notif.type;
    final category = notif.category;

    // 1. Appointment notifications -> MyAppointmentsScreen
    if (type == 'appointment_status' ||
        (route != null && route.startsWith('/appointments'))) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyAppointmentsScreen()),
      );
      return;
    }

    // 2. Event notifications -> EventsHomeScreen
    if (type == 'event_reminder' ||
        (route != null && route.startsWith('/events'))) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: AppColors.cream,
            appBar: AppBar(
              backgroundColor: AppColors.cream,
              elevation: 0,
              title: const Text('Events'),
            ),
            body: const EventsHomeScreen(),
          ),
        ),
      );
      return;
    }

    // 3. Explicit GoRouter routes (e.g. /chat/:matchId, /requests, /shop/orders/:id, /seller, /vet)
    if (route != null && route.isNotEmpty) {
      context.push(route);
      return;
    }

    // 4. Fallbacks by category / data
    final conversationId = notif.data['conversationId'] ?? notif.data['matchId'];
    if (category == 'messages' &&
        conversationId != null &&
        conversationId.isNotEmpty) {
      context.push('/chat/$conversationId');
      return;
    }

    if (category == 'requests') {
      context.push('/requests');
      return;
    }

    if (category == 'orders') {
      final orderId = notif.data['orderId'];
      if (orderId != null && orderId.isNotEmpty) {
        context.push('/shop/orders/$orderId');
      } else {
        context.push('/shop/orders');
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Notifications Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When you receive messages, match requests, or appointment updates, they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final (icon, iconColor, bgColor) = _visualsFor(notification);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isUnread
            ? AppColors.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isUnread ? FontWeight.w700 : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeAgo(notification.createdAt),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              isUnread ? FontWeight.w600 : FontWeight.normal,
                          color: isUnread
                              ? AppColors.terracotta
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if (notification.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight:
                            isUnread ? FontWeight.w500 : FontWeight.normal,
                        color: isUnread
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.terracotta,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (IconData, Color, Color) _visualsFor(AppNotification n) {
    if (n.type == 'appointment_status') {
      return (
        Icons.medical_services_rounded,
        AppColors.primary,
        AppColors.primary.withValues(alpha: 0.12),
      );
    }
    if (n.type == 'event_reminder') {
      return (
        Icons.event_rounded,
        AppColors.terracotta,
        AppColors.terracotta.withValues(alpha: 0.12),
      );
    }
    switch (n.category) {
      case 'messages':
        return (
          Icons.chat_bubble_rounded,
          AppColors.primary,
          AppColors.primary.withValues(alpha: 0.12),
        );
      case 'requests':
      case 'matches':
        return (
          Icons.favorite_rounded,
          AppColors.terracotta,
          AppColors.terracotta.withValues(alpha: 0.12),
        );
      case 'orders':
        return (
          Icons.shopping_bag_rounded,
          const Color(0xFFD97706),
          const Color(0xFFD97706).withValues(alpha: 0.12),
        );
      default:
        return (
          Icons.notifications_rounded,
          AppColors.primary,
          AppColors.primary.withValues(alpha: 0.12),
        );
    }
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.day}/${date.month}';
  }
}
