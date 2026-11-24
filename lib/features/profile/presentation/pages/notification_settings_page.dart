import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/notification_strings.dart';
import '../../../../core/models/notification_preference_model.dart';
import '../../../../core/services/notification_repository.dart';

const _systemSettingsChannel = MethodChannel('petmate/system_settings');

Future<bool> openSystemNotificationSettings() async {
  try {
    final result = await _systemSettingsChannel.invokeMethod<bool>('openNotificationSettings');
    return result ?? false;
  } catch (_) {
    return false;
  }
}

class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferenceModel> {
  @override
  Future<NotificationPreferenceModel> build() async {
    final repo = ref.watch(notificationRepositoryProvider);
    return repo.getPreferences();
  }

  Future<void> updatePreference({
    required BuildContext context,
    bool? messages,
    bool? requests,
    bool? matches,
    bool? orders,
    bool? system,
    bool? showPreviews,
  }) async {
    final current = state.value ?? const NotificationPreferenceModel();
    final updated = current.copyWith(
      messages: messages,
      requests: requests,
      matches: matches,
      orders: orders,
      system: system,
      showPreviews: showPreviews,
    );

    // 1. Optimistic UI update
    state = AsyncData(updated);

    try {
      final repo = ref.read(notificationRepositoryProvider);
      final saved = await repo.updatePreferences(updated);
      state = AsyncData(saved);
    } catch (e) {
      // 2. Rollback on failure
      state = AsyncData(current);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update notification settings. Reverted.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

final notificationPreferencesProvider = AsyncNotifierProvider<
    NotificationPreferencesNotifier,
    NotificationPreferenceModel>(
  NotificationPreferencesNotifier.new,
);

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);
    final locale = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          NotificationStrings.get('settings_title', locale: locale),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text(
                'Failed to load preferences',
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(notificationPreferencesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (prefs) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Section 1: Categories
            _SectionHeader(title: NotificationStrings.get('alert_categories', locale: locale)),
            _PreferenceTile(
              title: NotificationStrings.get('messages', locale: locale),
              subtitle: NotificationStrings.get('messages_desc', locale: locale),
              icon: Icons.chat_bubble_outline_rounded,
              value: prefs.messages,
              semanticLabel: 'Toggle message notifications',
              onChanged: (val) {
                ref
                    .read(notificationPreferencesProvider.notifier)
                    .updatePreference(context: context, messages: val);
              },
            ),
            _PreferenceTile(
              title: NotificationStrings.get('requests', locale: locale),
              subtitle: NotificationStrings.get('requests_desc', locale: locale),
              icon: Icons.swap_horiz_rounded,
              value: prefs.requests,
              semanticLabel: 'Toggle pet match request notifications',
              onChanged: (val) {
                ref
                    .read(notificationPreferencesProvider.notifier)
                    .updatePreference(context: context, requests: val);
              },
            ),
            _PreferenceTile(
              title: NotificationStrings.get('matches', locale: locale),
              subtitle: NotificationStrings.get('matches_desc', locale: locale),
              icon: Icons.favorite_border_rounded,
              value: prefs.matches,
              semanticLabel: 'Toggle pet match notifications',
              onChanged: (val) {
                ref
                    .read(notificationPreferencesProvider.notifier)
                    .updatePreference(context: context, matches: val);
              },
            ),
            _PreferenceTile(
              title: NotificationStrings.get('orders', locale: locale),
              subtitle: NotificationStrings.get('orders_desc', locale: locale),
              icon: Icons.shopping_bag_outlined,
              value: prefs.orders,
              semanticLabel: 'Toggle order notifications',
              onChanged: (val) {
                ref
                    .read(notificationPreferencesProvider.notifier)
                    .updatePreference(context: context, orders: val);
              },
            ),
            _PreferenceTile(
              title: NotificationStrings.get('system', locale: locale),
              subtitle: NotificationStrings.get('system_desc', locale: locale),
              icon: Icons.notifications_active_outlined,
              value: prefs.system,
              semanticLabel: 'Toggle system notifications',
              onChanged: (val) {
                ref
                    .read(notificationPreferencesProvider.notifier)
                    .updatePreference(context: context, system: val);
              },
            ),

            const SizedBox(height: 20),

            // Section 2: Display & Privacy
            _SectionHeader(title: NotificationStrings.get('display_privacy', locale: locale)),
            _PreferenceTile(
              title: NotificationStrings.get('show_previews', locale: locale),
              subtitle: NotificationStrings.get('show_previews_desc', locale: locale),
              icon: Icons.preview_rounded,
              value: prefs.showPreviews,
              semanticLabel: 'Toggle message preview in push notifications',
              onChanged: (val) {
                ref
                    .read(notificationPreferencesProvider.notifier)
                    .updatePreference(context: context, showPreviews: val);
              },
            ),

            const SizedBox(height: 20),

            // Section 3: System Notification Settings
            _SectionHeader(title: NotificationStrings.get('device_settings', locale: locale)),
            Card(
              margin: const EdgeInsets.only(top: 6),
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
              ),
              child: ListTile(
                minVerticalPadding: 16,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                title: Text(
                  NotificationStrings.get('system_settings_title', locale: locale),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    NotificationStrings.get('system_settings_desc', locale: locale),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                trailing: const Icon(
                  Icons.open_in_new_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onTap: () async {
                  await openSystemNotificationSettings();
                },
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final String semanticLabel;
  final ValueChanged<bool> onChanged;

  const _PreferenceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.semanticLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: Semantics(
        label: semanticLabel,
        toggled: value,
        container: true,
        child: SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          activeThumbColor: AppColors.primary,
          activeTrackColor: AppColors.primaryLight,
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
