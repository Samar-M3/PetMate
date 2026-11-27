import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/in_app_notification_service.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  static const Color _deepTeal = Color(0xFF0F5C57);
  static const Color _softCoral = Color(0xFFE16F52);
  static const Color _darkText = Color(0xFF293A37);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadNotifications = ref.watch(unreadNotificationsCountProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Brand Logo & Wordmark
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _deepTeal.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/icons/petmate-logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text.rich(
                TextSpan(
                  text: 'Pet',
                  children: [
                    TextSpan(
                      text: 'Mate',
                      style: TextStyle(
                        color: _softCoral,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: _darkText,
                ),
              ),
            ],
          ),

          // Notification Bell & Location
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 0,
                child: InkWell(
                  onTap: () => context.push('/notifications'),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE0E8E2),
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: Badge(
                        isLabelVisible: unreadNotifications > 0,
                        backgroundColor: _softCoral,
                        label: Text(
                          unreadNotifications > 99
                              ? '99+'
                              : '$unreadNotifications',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        child: Icon(
                          unreadNotifications > 0
                              ? Icons.notifications_rounded
                              : Icons.notifications_none_rounded,
                          color: _darkText,
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 0,
                child: InkWell(
                  onTap: () => context.push('/nearby'),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE0E8E2),
                        width: 1.0,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.location_on_outlined,
                        color: _darkText,
                        size: 21,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
