import 'package:flutter/material.dart';

import 'data.dart';

class OfferCard extends StatelessWidget {
  const OfferCard({super.key, required this.offer});
  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Hardcoded on purpose: a white card stays white in dark mode,
    // while its theme-colored text turns light and vanishes.
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            children: <Widget>[
              Container(
                height: 84,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                    child: Icon(offer.icon,
                        size: 40, color: cs.onSecondaryContainer)),
              ),
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F80ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('-${offer.discount}%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(offer.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text(offer.store,
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const Spacer(),
          Row(
            children: <Widget>[
              Text(offer.price,
                  style: const TextStyle(
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
              const SizedBox(width: 6),
              Text(offer.oldPrice,
                  style: text.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      decoration: TextDecoration.lineThrough)),
            ],
          ),
        ],
      ),
    );
  }
}
