import 'package:flutter/material.dart';
import '../models/app_theme.dart';

class BookVetHeroCard extends StatelessWidget {
  final VoidCallback onTap;

  const BookVetHeroCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CareTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CareTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: CareTheme.sagePill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Trusted care',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: CareTheme.deepOlive,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Book a Vet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: CareTheme.charcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Consultations from ₹499',
                    style: TextStyle(
                      fontSize: 13,
                      color: CareTheme.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: CareTheme.terracotta,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
