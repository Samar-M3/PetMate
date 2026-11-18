// The large top card from your mockup featuring the clinic photo,
// "Trusted care" badge, "★ 4.9" pill, "Book a Vet" heading, "from ₹499" text, and the circular terracotta arrow button.
import 'package:flutter/material.dart';
import '../models/app_theme.dart';

class BookVetHeroCard extends StatelessWidget {
  final VoidCallback onTap;

  const BookVetHeroCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: CareTheme.cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Clinic Banner
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
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: CareTheme.deepOlive,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Trusted care',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: CareTheme.cardBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.amber),
                            SizedBox(width: 4),
                            Text(
                              '4.9',
                              style: TextStyle(
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
            // Bottom Action Row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Book a Vet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CareTheme.charcoal,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'In-clinic checkups from ₹499',
                        style: TextStyle(
                          fontSize: 13,
                          color: CareTheme.mutedText,
                        ),
                      ),
                    ],
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
}
