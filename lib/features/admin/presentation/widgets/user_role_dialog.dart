import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/admin_user_model.dart';

class UserRoleDialog extends StatefulWidget {
  final AdminUserModel user;
  final bool isCurrentUser;
  final ValueChanged<String> onRoleSelected;

  const UserRoleDialog({
    super.key,
    required this.user,
    required this.isCurrentUser,
    required this.onRoleSelected,
  });

  @override
  State<UserRoleDialog> createState() => _UserRoleDialogState();
}

class _UserRoleDialogState extends State<UserRoleDialog> {
  late String _selectedRole;

  final List<Map<String, String>> _roles = [
    {
      'role': 'PET_OWNER',
      'label': 'Pet Owner',
      'desc':
          'Can register pets, browse discover, swipe, and book appointments.',
    },
    {
      'role': 'SELLER',
      'label': 'Seller',
      'desc': 'Can publish products and manage marketplace inventory.',
    },
    {
      'role': 'VETERINARIAN',
      'label': 'Veterinarian',
      'desc': 'Can provide medical care, schedule appointments, and consult.',
    },
    {
      'role': 'ADMIN',
      'label': 'System Admin',
      'desc': 'Full administrative control over users, roles, and platform settings.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.user.role;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.manage_accounts_rounded, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Change User Role',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target User: ${widget.user.fullName ?? widget.user.email ?? widget.user.id}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.isCurrentUser) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You cannot change your own admin role.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            IgnorePointer(
              ignoring: widget.isCurrentUser,
              child: RadioGroup<String>(
                groupValue: _selectedRole,
                onChanged: (val) {
                  if (!widget.isCurrentUser && val != null) {
                    setState(() => _selectedRole = val);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _roles.map((r) {
                    final roleVal = r['role']!;
                    final isCurrent = roleVal == widget.user.role;
                    return RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: roleVal,
                      title: Text(
                        r['label']! + (isCurrent ? ' (Current)' : ''),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        r['desc']!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      activeColor: AppColors.primary,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!widget.isCurrentUser)
          ElevatedButton(
            onPressed: _selectedRole == widget.user.role
                ? null
                : () {
                    Navigator.pop(context);
                    widget.onRoleSelected(_selectedRole);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Role'),
          ),
      ],
    );
  }
}
