import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/in_app_notification_service.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class HomeHeader extends ConsumerWidget {
  final VoidCallback onProfileTap;

  const HomeHeader({super.key, required this.onProfileTap});

  static const Color _deepTeal = Color(0xFF0F5C57);
  static const Color _sageGreen = Color(0xFFE8F0EA);
  static const Color _softCoral = Color(0xFFE16F52);
  static const Color _darkText = Color(0xFF293A37);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final unreadNotifications = ref.watch(unreadNotificationsCountProvider);
    final profile = user?.profile;
    final avatarUrl = profile?.effectiveImageUrl ?? profile?.profilePictureUrl;
    final initial = (profile?.fullName != null && profile!.fullName!.isNotEmpty)
        ? profile.fullName![0].toUpperCase()
        : (user?.email != null && user!.email!.isNotEmpty)
        ? user.email![0].toUpperCase()
        : 'P';

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
                  color: _deepTeal,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _deepTeal.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.pets_rounded,
                  color: Colors.white,
                  size: 20,
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

          // Notification Bell & User Profile Avatar
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
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _sageGreen,
                    border: Border.all(
                      color: _deepTeal.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: UserAvatar(
                    imageUrl: avatarUrl,
                    radius: 18,
                    initials: initial,
                    onTap: onProfileTap,
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
