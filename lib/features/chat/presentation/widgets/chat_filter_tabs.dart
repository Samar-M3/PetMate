import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

enum ChatFilterTab { active, liked, all }

class ChatFilterTabs extends StatelessWidget {
  final ChatFilterTab selectedTab;
  final ValueChanged<ChatFilterTab> onTabSelected;
  final int incomingRequestsCount;

  const ChatFilterTabs({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
    this.incomingRequestsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.creamDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildTab(
            tab: ChatFilterTab.active,
            label: 'Active',
          ),
          _buildTab(
            tab: ChatFilterTab.liked,
            label: 'Liked',
          ),
          _buildTab(
            tab: ChatFilterTab.all,
            label: 'All',
            badgeCount: incomingRequestsCount,
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required ChatFilterTab tab,
    required String label,
    int badgeCount = 0,
  }) {
    final isSelected = selectedTab == tab;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTabSelected(tab),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F5C57) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F5C57).withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFF8A65)
                        : AppColors.terracotta,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
