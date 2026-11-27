import 'package:flutter/material.dart';

import '../models/app_theme.dart';
import '../utils/care_format.dart';

class BookVetHeroCard extends StatelessWidget {
  final VoidCallback onTap;

  /// Lowest consultation fee across listed vets; hidden when unknown.
  final int? startingFee;

  /// Average vet rating; the pill is hidden when there are no ratings yet.
  final double? rating;

  const BookVetHeroCard({
    super.key,
    required this.onTap,
    this.startingFee,
    this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final hasFee = startingFee != null && startingFee! > 0;
    final hasRating = rating != null && rating! > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: CareTheme.cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 145,
              decoration: const BoxDecoration(
                color: CareTheme.sageGreen,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(14),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.local_hospital_rounded,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _pill(
                        color: CareTheme.deepOlive,
                        child: const Text(
                          'Trusted care',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (hasRating)
                        _pill(
                          color: CareTheme.cardBg,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: CareTheme.charcoal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Book a Vet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: CareTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasFee
                              ? 'In-clinic checkups from ${formatFee(startingFee!)}'
                              : 'In-clinic checkups with trusted vets',
                          style: const TextStyle(
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
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _pill({required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
