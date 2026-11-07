import 'package:flutter/material.dart';

import 'data.dart';
import 'offer_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Good evening, Abd',
                        style: text.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text('Find your next deal',
                        style: text.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primaryContainer,
                child: Icon(Icons.notifications_none,
                    color: cs.onPrimaryContainer),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Hardcoded on purpose: a light grey search field (breaks in dark mode).
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.search, color: cs.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Search offers, stores…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final (i, c) in <String>[
                  'All',
                  'Tech',
                  'Home',
                  'Fashion',
                  'Food'
                ].indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                        label: Text(c), selected: i == 0, onSelected: (_) {}),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient:
                  LinearGradient(colors: <Color>[cs.primary, cs.tertiary]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Weekend Sale',
                          style: text.titleLarge?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Up to 50% off electronics',
                          style: text.bodyMedium?.copyWith(
                              color: cs.onPrimary.withValues(alpha: 0.85))),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                          onPressed: () {}, child: const Text('Shop now')),
                    ],
                  ),
                ),
                Icon(Icons.local_offer,
                    size: 64, color: cs.onPrimary.withValues(alpha: 0.9)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              // Hardcoded on purpose: black text disappears on a dark background.
              const Expanded(
                child: Text('Hot offers',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
              ),
              TextButton(onPressed: () {}, child: const Text('See all')),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hotOffers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => OfferCard(offer: hotOffers[i]),
            ),
          ),
          const SizedBox(height: 18),
          Text('Near you',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final d in nearbyDeals) _DealTile(deal: d),
        ],
      ),
    );
  }
}

class _DealTile extends StatelessWidget {
  const _DealTile({required this.deal});
  final Deal deal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        // Hardcoded on purpose: a fixed grey icon.
        leading: const Icon(Icons.storefront, color: Colors.grey),
        title: Text(deal.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(deal.detail),
        trailing: Text(deal.distance,
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
