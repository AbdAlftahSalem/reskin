import 'package:flutter/material.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
        children: <Widget>[
          Text('Rewards',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2F6D5A),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(children: <Widget>[
                  Text('Bunn Gold',
                      style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800, color: Colors.white)),
                  const Spacer(),
                  Text('1,240 pts',
                      style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700, color: cs.onPrimary)),
                ]),
                const SizedBox(height: 4),
                Text('3 more cups for a free drink',
                    style: text.bodySmall
                        ?.copyWith(color: cs.onPrimary.withValues(alpha: 0.8))),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List<Widget>.generate(10, (i) {
                    final done = i < 7;
                    return CircleAvatar(
                      radius: 13,
                      backgroundColor: done
                          ? cs.onPrimary
                          : cs.onPrimary.withValues(alpha: 0.18),
                      child: Icon(Icons.coffee,
                          size: 14,
                          color: done
                              ? cs.primary
                              : cs.onPrimary.withValues(alpha: 0.6)),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Perks',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final (icon, title, sub) in <(IconData, String, String)>[
            (Icons.cake_outlined, 'Birthday drink', 'Any size, on us'),
            (
              Icons.local_shipping_outlined,
              'Free delivery',
              'Orders over \$15'
            ),
            (
              Icons.coffee_maker_outlined,
              'Bean of the month',
              '15% off 250 g bags'
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor: cs.secondaryContainer,
                      child: Icon(icon, color: cs.onSecondaryContainer)),
                  title: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(sub),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
