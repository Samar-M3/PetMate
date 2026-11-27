import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

Future<String?> showIntroMessageSheet({
  required BuildContext context,
  required String petName,
  String? petImageUrl,
  String? initialMessage,
  required Future<void> Function(String message) onSend,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _IntroMessageSheet(
      petName: petName,
      petImageUrl: petImageUrl,
      initialMessage: initialMessage,
      onSend: onSend,
    ),
  );
}

class _IntroMessageSheet extends StatefulWidget {
  final String petName;
  final String? petImageUrl;
  final String? initialMessage;
  final Future<void> Function(String message) onSend;

  const _IntroMessageSheet({
    required this.petName,
    this.petImageUrl,
    this.initialMessage,
    required this.onSend,
  });

  @override
  State<_IntroMessageSheet> createState() => _IntroMessageSheetState();
}

class _IntroMessageSheetState extends State<_IntroMessageSheet> {
  static const int _maxLength = 300;
  late final TextEditingController _controller;
  bool _isSending = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialMessage ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSending) return;
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _errorText = 'Please write a short introduction before sending.';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorText = null;
    });

    try {
      await widget.onSend(trimmed);
      if (mounted) {
        Navigator.of(context).pop(trimmed);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _errorText = 'Could not send message. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasImage =
        widget.petImageUrl != null && widget.petImageUrl!.trim().isNotEmpty;
    final isEditing =
        widget.initialMessage != null && widget.initialMessage!.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.creamDark,
                  backgroundImage:
                      hasImage ? NetworkImage(widget.petImageUrl!) : null,
                  child: !hasImage
                      ? const Icon(
                          Icons.pets,
                          color: Color(0xFF0F5C57),
                          size: 22,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing
                            ? 'Edit intro for ${widget.petName}'
                            : 'Introduce yourself to ${widget.petName}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Your message will appear when they open your request',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLength: _maxLength,
              maxLines: 4,
              minLines: 3,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              decoration: InputDecoration(
                hintText:
                    'Hi! ${widget.petName} looks adorable — would love to set up a playdate!',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13.5,
                ),
                filled: true,
                fillColor: Colors.white,
                errorText: _errorText,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFF0F5C57),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSending
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F5C57),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEditing ? 'Save Message' : 'Send Message',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
