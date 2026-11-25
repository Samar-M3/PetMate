import 'package:flutter/material.dart';

import '../models/app_theme.dart';

PreferredSizeWidget careAppBar(
  String title, {
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    backgroundColor: CareTheme.background,
    elevation: 0,
    iconTheme: const IconThemeData(color: CareTheme.charcoal),
    title: Text(
      title,
      style: const TextStyle(
        color: CareTheme.charcoal,
        fontWeight: FontWeight.bold,
      ),
    ),
    actions: actions,
    bottom: bottom,
  );
}

void showCareSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : CareTheme.deepOlive,
      ),
    );
}

Future<bool> confirmCareAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Yes',
  String cancelLabel = 'Keep it',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: const TextStyle(color: CareTheme.terracotta),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

class CareLoading extends StatelessWidget {
  const CareLoading({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: CareTheme.terracotta),
  );
}

class CareMessage extends StatelessWidget {
  final String text;
  const CareMessage(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: CareTheme.mutedText),
      ),
    ),
  );
}

class CareErrorRetry extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const CareErrorRetry({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error.toString().replaceFirst('Exception: ', ''),
            textAlign: TextAlign.center,
            style: const TextStyle(color: CareTheme.charcoal),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CareTheme.terracotta,
              foregroundColor: Colors.white,
            ),
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
