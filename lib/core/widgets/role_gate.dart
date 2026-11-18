import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/entities/user_role.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// A widget that selectively renders [child] if the authenticated user's
/// role matches any of [allowedRoles]. Otherwise, renders [fallback].
class RoleGate extends ConsumerWidget {
  final List<UserRole> allowedRoles;
  final Widget child;
  final Widget fallback;

  const RoleGate({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final userRole = user?.role ?? UserRole.petOwner;

    if (allowedRoles.contains(userRole)) {
      return child;
    }

    return fallback;
  }
}
