import 'package:flutter/material.dart';

/// The morning offer at the top of Home.
class PromoBanner extends StatelessWidget {
  const PromoBanner({super.key, required this.onOrder});
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      height: 168,
      decoration: BoxDecoration(
        // Marketing asked for "the coffee brown from the poster".
        color: const Color(0xFF8A4B2A),
        borderRadius: BorderRadius.circular(26),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -28,
            top: -10,
            bottom: -10,
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipOval(
                child:
                    Image.asset('assets/images/latte.jpg', fit: BoxFit.cover),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 150, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1D6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('20% OFF',
                      style: text.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: const Color(0xFF8A4B2A))),
                ),
                const SizedBox(height: 10),
                Text('Morning ritual',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFF6E9))),
                const SizedBox(height: 2),
                Text('Every latte, until 11 am',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withValues(alpha: 0.85))),
                const Spacer(),
                SizedBox(
                  height: 36,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 16)),
                    onPressed: onOrder,
                    child: const Text('Order now'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
