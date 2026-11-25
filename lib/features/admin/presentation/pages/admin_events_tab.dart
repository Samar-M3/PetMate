import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmatee/features/care_events/providers/care_events_provider.dart';
import 'package:petmatee/features/care_events/models/event_model.dart';
import '../../../../core/constants/app_colors.dart';

class AdminEventsTab extends ConsumerWidget {
const AdminEventsTab({super.key});

Future<String?> _promptNewCategory(BuildContext context) async {
final textCtrl = TextEditingController();
return showDialog<String>(
context: context,
builder: (ctx) => AlertDialog(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
title: const Text('Add Category',
style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
content: TextField(
controller: textCtrl,
autofocus: true,
textCapitalization: TextCapitalization.characters,
decoration: InputDecoration(
hintText: 'e.g. WORKSHOP, CHARITY',
filled: true,
fillColor: AppColors.inputFill,
contentPadding:
const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppColors.border),
),
),
),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
ElevatedButton(
onPressed: () => Navigator.pop(ctx, textCtrl.text.trim()),
style: ElevatedButton.styleFrom(
backgroundColor: AppColors.primary,
foregroundColor: Colors.white),
child: const Text('Add'),
),
],
),
);
}

void _showAddEventDialog(BuildContext context, WidgetRef ref) {
final titleCtrl = TextEditingController();
final locationCtrl = TextEditingController();
final timeCtrl = TextEditingController(text: '10:00 AM - 01:00 PM');
final descCtrl = TextEditingController();
final dateCtrl = TextEditingController(text: 'Dec 05, 2026');
String selectedCategory = 'MEETUP';
final categories = ['MEETUP', 'AGILITY', 'OTHER'];

showDialog(
context: context,
builder: (ctx) => StatefulBuilder(
builder: (dialogContext, setState) => AlertDialog(
shape:
RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
title: const Row(
children: [
Icon(Icons.event_available_rounded, color: AppColors.primary),
SizedBox(width: 8),
Text('Create Community Event',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
],
),
content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_inputField(titleCtrl, 'Event Title (e.g. Puppy Playdate)'),
const SizedBox(height: 10),
const Text('Category',
style: TextStyle(
fontSize: 12,
fontWeight: FontWeight.bold,
color: AppColors.textSecondary)),
const SizedBox(height: 6),
Wrap(
spacing: 6,
runSpacing: 6,
children: [
...categories.map((cat) {
final isSel = selectedCategory == cat;
return ChoiceChip(
label: Text(cat,
style: TextStyle(
fontSize: 11,
color: isSel
? Colors.white
: AppColors.textPrimary)),
selected: isSel,
selectedColor: AppColors.primary,
backgroundColor: AppColors.inputFill,
onSelected: (_) =>
setState(() => selectedCategory = cat),
);
}),
ActionChip(
avatar: const Icon(Icons.add_rounded,
size: 16, color: AppColors.primary),
label: const Text('New',
style: TextStyle(
fontSize: 11,
color: AppColors.primary,
fontWeight: FontWeight.bold)),
backgroundColor: AppColors.primary.withValues(alpha: 0.1),
side: const BorderSide(color: AppColors.primary),
onPressed: () async {
final newCategory = await _promptNewCategory(context);
if (newCategory != null && newCategory.isNotEmpty) {
final formatted = newCategory.toUpperCase().trim();
setState(() {
if (!categories.contains(formatted)) {
categories.add(formatted);
}
selectedCategory = formatted;
});
}
},
),
],
),
const SizedBox(height: 10),
_inputField(dateCtrl, 'Date (e.g. Dec 05, 2026)'),
const SizedBox(height: 10),
_inputField(timeCtrl, 'Time (e.g. 09:00 AM - 12:00 PM)'),
const SizedBox(height: 10),
_inputField(locationCtrl, 'Location (e.g. Central Park, Lalitpur)'),
const SizedBox(height: 10),
_inputField(descCtrl, 'Description...', maxLines: 3),
],
),
),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx),
child: const Text('Cancel'),
),
ElevatedButton(
onPressed: () async {
if (titleCtrl.text.trim().isEmpty ||
locationCtrl.text.trim().isEmpty) {
return;
}
Navigator.pop(ctx);
try {
await ref.read(careEventsProvider.notifier).addEvent(
title: titleCtrl.text.trim(),
category: selectedCategory,
fullDate: dateCtrl.text.trim(),
time: timeCtrl.text.trim(),
location: locationCtrl.text.trim(),
description: descCtrl.text.trim().isEmpty
? 'Join fellow pet parents for this exciting event!'
: descCtrl.text.trim(),
);
if (context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Event created successfully!'),
backgroundColor: AppColors.success,
),
);
}
} catch (e) {
if (context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Failed to create event: $e'),
backgroundColor: AppColors.error,
),
);
}
}
},
style: ElevatedButton.styleFrom(
backgroundColor: AppColors.primary,
foregroundColor: Colors.white,
),
child: const Text('Create Event'),
),
],
),
),
);
}

Future<void> _deleteEvent(BuildContext context, WidgetRef ref, PetEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Event?'),
        content: Text(
          'Are you sure you want to delete "${event.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(careEventsProvider.notifier).deleteEvent(event.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event deleted!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete event: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showEditEventDialog(BuildContext context, WidgetRef ref, PetEvent event) {
final titleCtrl = TextEditingController(text: event.title);
final locationCtrl = TextEditingController(text: event.location);
final timeCtrl = TextEditingController(text: event.time);
final descCtrl = TextEditingController(text: event.description);
final dateCtrl = TextEditingController(text: event.fullDate);
String selectedCategory = event.category;
final categories = ['MEETUP', 'AGILITY', 'OTHER'];

showDialog(
context: context,
builder: (ctx) => StatefulBuilder(
builder: (dialogContext, setState) => AlertDialog(
shape:
RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
title: const Row(
children: [
Icon(Icons.edit_rounded, color: AppColors.primary),
SizedBox(width: 8),
Text('Edit Event',
style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
],
),
content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_inputField(titleCtrl, 'Event Title (e.g. Puppy Playdate)'),
const SizedBox(height: 10),
const Text('Category',
style: TextStyle(
fontSize: 12,
fontWeight: FontWeight.bold,
color: AppColors.textSecondary)),
const SizedBox(height: 6),
Wrap(
spacing: 6,
runSpacing: 6,
children: [
...categories.map((cat) {
final isSel = selectedCategory == cat;
return ChoiceChip(
label: Text(cat,
style: TextStyle(
fontSize: 11,
color: isSel
? Colors.white
: AppColors.textPrimary)),
selected: isSel,
selectedColor: AppColors.primary,
backgroundColor: AppColors.inputFill,
onSelected: (_) =>
setState(() => selectedCategory = cat),
);
}),
ActionChip(
avatar: const Icon(Icons.add_rounded,
size: 16, color: AppColors.primary),
label: const Text('New',
style: TextStyle(
fontSize: 11,
color: AppColors.primary,
fontWeight: FontWeight.bold)),
backgroundColor: AppColors.primary.withValues(alpha: 0.1),
side: const BorderSide(color: AppColors.primary),
onPressed: () async {
final newCategory = await _promptNewCategory(context);
if (newCategory != null && newCategory.isNotEmpty) {
final formatted = newCategory.toUpperCase().trim();
setState(() {
if (!categories.contains(formatted)) {
categories.add(formatted);
}
selectedCategory = formatted;
});
}
},
),
],
),
const SizedBox(height: 10),
_inputField(dateCtrl, 'Date (e.g. Dec 05, 2026)'),
const SizedBox(height: 10),
_inputField(timeCtrl, 'Time (e.g. 09:00 AM - 12:00 PM)'),
const SizedBox(height: 10),
_inputField(locationCtrl, 'Location (e.g. Central Park, Lalitpur)'),
const SizedBox(height: 10),
_inputField(descCtrl, 'Description...', maxLines: 3),
],
),
),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx),
child: const Text('Cancel'),
),
ElevatedButton(
onPressed: () async {
if (titleCtrl.text.trim().isEmpty ||
locationCtrl.text.trim().isEmpty) {
return;
}
Navigator.pop(ctx);
try {
await ref.read(careEventsProvider.notifier).updateEvent(
event.id,
title: titleCtrl.text.trim(),
category: selectedCategory,
fullDate: dateCtrl.text.trim(),
time: timeCtrl.text.trim(),
location: locationCtrl.text.trim(),
description: descCtrl.text.trim().isEmpty
? 'Join fellow pet parents for this exciting event!'
: descCtrl.text.trim(),
);
if (context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Event updated successfully!'),
backgroundColor: AppColors.success,
),
);
}
} catch (e) {
if (context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Failed to update event: $e'),
backgroundColor: AppColors.error,
),
);
}
}
},
style: ElevatedButton.styleFrom(
backgroundColor: AppColors.primary,
foregroundColor: Colors.white,
),
child: const Text('Save Changes'),
),
],
),
)
);
}

static Widget _inputField(TextEditingController ctrl, String hint,
{int maxLines = 1}) {
return TextField(
controller: ctrl,
maxLines: maxLines,
decoration: InputDecoration(
hintText: hint,
filled: true,
fillColor: AppColors.inputFill,
contentPadding:
const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppColors.border),
),
enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
borderSide: const BorderSide(color: AppColors.border),
),
),
);
}

@override
Widget build(BuildContext context, WidgetRef ref) {
final eventsAsync = ref.watch(careEventsProvider);

return Scaffold(
backgroundColor: AppColors.cream,
floatingActionButton: FloatingActionButton.extended(
heroTag: 'admin_add_event_fab',
onPressed: () => _showAddEventDialog(context, ref),
backgroundColor: AppColors.terracotta,
foregroundColor: Colors.white,
icon: const Icon(Icons.add_rounded),
label: const Text('Add Event'),
),
body: eventsAsync.when(
loading: () => const Center(
child: CircularProgressIndicator(color: AppColors.primary),
),
error: (err, _) => Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Text('Error loading events: $err'),
const SizedBox(height: 10),
ElevatedButton(
onPressed: () => ref.invalidate(careEventsProvider),
child: const Text('Retry'),
),
],
),
),
data: (events) {
if (events.isEmpty) {
return const Center(
child: Text(
  'No events created yet.\nTap "+ Add Event" to publish one.',
  textAlign: TextAlign.center,
  style: TextStyle(color: AppColors.textSecondary),
),
);
}
return RefreshIndicator(
  onRefresh: () async => ref.invalidate(careEventsProvider),
  child: ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
    itemCount: events.length,
    separatorBuilder: (_, __) => const SizedBox(height: 12),
    itemBuilder: (context, index) {
      final ev = events[index];
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(ev.dayName,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                  Text(ev.dayNum,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ev.category,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.terracotta)),
                  Text(ev.title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('${ev.location} • ${ev.time}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('${ev.attendeeCount} pet parents going',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                  tooltip: 'Edit Event',
                  onPressed: () => _showEditEventDialog(context, ref, ev),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                  tooltip: 'Delete Event',
                  onPressed: () => _deleteEvent(context, ref, ev),
                ),
              ],
            ),
          ],
        ),
      );
    },
  ),
);
},
),
);
}
}