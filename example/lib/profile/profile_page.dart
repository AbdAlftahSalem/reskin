import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: cs.primary,
              child: Text('AS',
                  style: text.headlineSmall?.copyWith(color: cs.onPrimary)),
            ),
          ),
          const SizedBox(height: 12),
          // Hardcoded on purpose: near-black name text.
          const Center(
            child: Text('Abd Alftah',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A))),
          ),
          Center(
              child: Text('Gold member',
                  style:
                      text.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              for (final (label, value) in <(String, String)>[
                ('Orders', '24'),
                ('Saved', '\$312'),
                ('Points', '1,280')
              ])
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        children: <Widget>[
                          Text(value,
                              style: text.titleLarge?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w800)),
                          Text(label, style: text.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (icon, label) in <(IconData, String)>[
            (Icons.receipt_long, 'My orders'),
            (Icons.location_on_outlined, 'Addresses'),
            (Icons.credit_card, 'Payment methods'),
            (Icons.settings_outlined, 'Settings'),
          ])
            ListTile(
              leading: Icon(icon, color: cs.primary),
              title: Text(label),
              trailing: const Icon(Icons.chevron_right),
            ),
        ],
      ),
    );
  }
}
