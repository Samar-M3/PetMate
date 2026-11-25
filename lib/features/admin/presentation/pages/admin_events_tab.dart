import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmatee/features/care_events/models/event_model.dart';
import 'package:petmatee/features/care_events/providers/care_events_provider.dart';

import '../theme/admin_colors.dart';

class AdminEventsTab extends ConsumerStatefulWidget {
  const AdminEventsTab({super.key});

  @override
  ConsumerState<AdminEventsTab> createState() => _AdminEventsTabState();
}

class _AdminEventsTabState extends ConsumerState<AdminEventsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'ALL';

  // Base categories (without 'OTHER', with '+New' for custom)
  final List<String> _baseCategories = [
    'ALL',
    'MEETUP',
    'AGILITY',
    'WORKSHOP',
    'ADOPTION',
  ];

  // Runtime categories (base + any custom ones added)
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _categories = List.from(_baseCategories);
    _categories.add('+New');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEventDialog({PetEvent? eventToEdit}) {
    final isEditing = eventToEdit != null;
    final titleCtrl = TextEditingController(text: eventToEdit?.title ?? '');
    final locationCtrl = TextEditingController(text: eventToEdit?.location ?? '');
    final timeCtrl = TextEditingController(text: eventToEdit?.time ?? '10:00 AM - 01:00 PM');
    final descCtrl = TextEditingController(text: eventToEdit?.description ?? '');
    final dateCtrl = TextEditingController(text: eventToEdit?.fullDate ?? 'Dec 05, 2026');
    String chosenCat = eventToEdit?.category ?? 'MEETUP';

    // Custom category controller for when "+New" is selected
    final customCatCtrl = TextEditingController();
    bool isCustomCategory = !_baseCategories.contains(chosenCat) && chosenCat != 'ALL';

    if (isCustomCategory) {
      customCatCtrl.text = chosenCat;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Edit Community Event' : 'Create Community Event',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _field(
                      titleCtrl,
                      'Event Title * (e.g. Puppy Socialization)',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'CATEGORY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Category selection with +New option
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _categories.map((cat) {
                        if (cat == '+New') {
                          return ActionChip(
                            avatar: const Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: AdminColors.primary,
                            ),
                            label: const Text(
                              'New Category',
                              style: TextStyle(
                                fontSize: 11,
                                color: AdminColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: AdminColors.primary.withValues(alpha: 0.1),
                            side: const BorderSide(color: AdminColors.primary),
                            onPressed: () async {
                              final newCat = await _promptNewCategory(context);
                              if (newCat != null && newCat.isNotEmpty) {
                                final formatted = newCat.toUpperCase().trim();
                                if (!_categories.contains(formatted)) {
                                  setState(() {
                                    _categories.insert(_categories.length - 1, formatted);
                                  });
                                }
                                setDialogState(() {
                                  chosenCat = formatted;
                                  isCustomCategory = true;
                                  customCatCtrl.text = formatted;
                                });
                              }
                            },
                          );
                        }
                        final isSel = chosenCat == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSel,
                          selectedColor: AdminColors.primary,
                          backgroundColor: AdminColors.background,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSel
                                ? Colors.white
                                : AdminColors.textSecondary,
                          ),
                          onSelected: (_) => setDialogState(() {
                            chosenCat = cat;
                            isCustomCategory = false;
                          }),
                        );
                      }).toList(),
                    ),
                    // Custom category input field (shown when +New is selected or editing custom category)
                    if (isCustomCategory) ...[
                      const SizedBox(height: 12),
                      _field(
                        customCatCtrl,
                        'Custom Category Name',
                      ),
                    ],
                    const SizedBox(height: 12),
                    _field(dateCtrl, 'Date * (e.g. Dec 05, 2026)'),
                    const SizedBox(height: 12),
                    _field(timeCtrl, 'Time * (e.g. 10:00 AM - 01:00 PM)'),
                    const SizedBox(height: 12),
                    _field(
                      locationCtrl,
                      'Location * (e.g. Central Dog Park, Lalitpur)',
                    ),
                    const SizedBox(height: 12),
                    _field(descCtrl, 'Description...', maxLines: 3),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: AdminColors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (titleCtrl.text.trim().isEmpty ||
                                locationCtrl.text.trim().isEmpty) {
                              return;
                            }
                            // Use custom category if provided
                            final finalCategory = isCustomCategory
                                ? customCatCtrl.text.trim().toUpperCase()
                                : chosenCat;
                            Navigator.pop(ctx);
                            try {
                              if (isEditing) {
                                await ref
                                    .read(careEventsProvider.notifier)
                                    .updateEvent(
                                      eventToEdit.id,
                                      title: titleCtrl.text.trim(),
                                      category: finalCategory,
                                      fullDate: dateCtrl.text.trim(),
                                      time: timeCtrl.text.trim(),
                                      location: locationCtrl.text.trim(),
                                      description: descCtrl.text.trim().isEmpty
                                          ? 'Join fellow pet parents for this exciting event!'
                                          : descCtrl.text.trim(),
                                    );
                              } else {
                                await ref
                                    .read(careEventsProvider.notifier)
                                    .addEvent(
                                      title: titleCtrl.text.trim(),
                                      category: finalCategory,
                                      fullDate: dateCtrl.text.trim(),
                                      time: timeCtrl.text.trim(),
                                      location: locationCtrl.text.trim(),
                                      description: descCtrl.text.trim().isEmpty
                                          ? 'Join fellow pet parents for this exciting event!'
                                          : descCtrl.text.trim(),
                                    );
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isEditing
                                          ? 'Community event updated successfully!'
                                          : 'Community event created successfully!',
                                    ),
                                    backgroundColor: AdminColors.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        isEditing ? 'Failed to update event: $e' : 'Failed to create event: $e'),
                                    backgroundColor: AdminColors.error,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(isEditing ? 'Save Changes' : 'Create Event'),
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
  }

  /// Prompt for new category name
  Future<String?> _promptNewCategory(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'New Category',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Charity, Training',
            filled: true,
            fillColor: AdminColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdminColors.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13, color: AdminColors.textPrimary),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(
          fontSize: 12,
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
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.primary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(careEventsProvider);

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(
                              () => _searchQuery = val.trim().toLowerCase(),
                            );
                          },
                          style: const TextStyle(
                            fontSize: 13,
                            color: AdminColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search community events by title or location...',
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
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 16,
                                    ),
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
                    ElevatedButton.icon(
                      onPressed: _showAddEventDialog,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Create Event'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
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
                const SizedBox(height: 12),
                // Categories
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSel = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() => _selectedCategory = cat),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AdminColors.primary
                                  : AdminColors.background,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSel
                                    ? AdminColors.primary
                                    : AdminColors.border,
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSel
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSel
                                    ? Colors.white
                                    : AdminColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: eventsAsync.when(
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
                      'Error loading events: $err',
                      style: const TextStyle(color: AdminColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(careEventsProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (events) {
                final filtered = events.where((e) {
                  final matchesCat =
                      _selectedCategory == 'ALL' ||
                      e.category.toUpperCase() == _selectedCategory;
                  final matchesSearch =
                      _searchQuery.isEmpty ||
                      e.title.toLowerCase().contains(_searchQuery) ||
                      e.location.toLowerCase().contains(_searchQuery);
                  return matchesCat && matchesSearch;
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
                            Icons.event_available_outlined,
                            size: 36,
                            color: AdminColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No events found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap "+ Create Event" to schedule a community gathering.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AdminColors.primary,
                  onRefresh: () async => ref.invalidate(careEventsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final ev = filtered[index];
                      return _buildEventCard(ev);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(PetEvent ev) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date badge
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AdminColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AdminColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Text(
                  ev.dayName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ev.dayNum,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AdminColors.background,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: Text(
                        ev.category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.textSecondary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AdminColors.successLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.people_alt_outlined,
                            size: 12,
                            color: AdminColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${ev.attendeeCount} going',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AdminColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  ev.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AdminColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      ev.time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AdminColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        ev.location,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AdminColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (ev.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    ev.description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AdminColors.textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: AdminColors.primary,
                      ),
                      tooltip: 'Edit Event',
                      onPressed: () => _showAddEventDialog(eventToEdit: ev),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_rounded,
                        size: 18,
                        color: AdminColors.error,
                      ),
                      tooltip: 'Delete Event',
                      onPressed: () => _deleteEvent(ev),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEvent(PetEvent ev) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Event?'),
        content: Text(
          'Are you sure you want to delete "${ev.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(careEventsProvider.notifier).deleteEvent(ev.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event deleted!'),
            backgroundColor: AdminColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete event: $e'),
            backgroundColor: AdminColors.error,
          ),
        );
      }
    }
  }
}
