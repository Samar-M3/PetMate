import 'package:flutter/material.dart';

enum ChatFilterTab { active, liked, all }

// Design tokens
const _primaryTeal = Color(0xFF0B625B);
const _warmIvory = Color(0xFFF8F6F0);
const _charcoalText = Color(0xFF26332F);
const _mutedText = Color(0xFF7B8880);
const _softBorder = Color(0xFFE5E8E2);
const _coralAccent = Color(0xFFE8795B);

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildPill(tab: ChatFilterTab.active, label: 'Active'),
          const SizedBox(width: 8),
          _buildPill(tab: ChatFilterTab.liked, label: 'Liked'),
          const SizedBox(width: 8),
          _buildPill(
            tab: ChatFilterTab.all,
            label: 'All',
            badgeCount: incomingRequestsCount,
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required ChatFilterTab tab,
    required String label,
    int badgeCount = 0,
  }) {
    final isSelected = selectedTab == tab;

    return GestureDetector(
      onTap: () => onTabSelected(tab),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? _primaryTeal : _softBorder.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : _charcoalText,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : _coralAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
