import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notify = true;
  bool _oatMilk = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
        children: <Widget>[
          Center(
            child: CircleAvatar(
              radius: 42,
              backgroundColor: cs.primaryContainer,
              child: Text('A',
                  style: text.headlineMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('Abd Alftah',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Center(
            child: Text('Gold member since 2024',
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
          const SizedBox(height: 20),
          Row(children: <Widget>[
            for (final (n, l) in <(String, String)>[
              ('48', 'Orders'),
              ('7/10', 'Stamps'),
              ('\$32', 'Saved'),
            ])
              Expanded(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(children: <Widget>[
                      Text(n,
                          style: text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800, color: cs.primary)),
                      Text(l, style: text.bodySmall),
                    ]),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 18),
          Card(
            child: Column(children: <Widget>[
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('Order notifications'),
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.eco_outlined),
                title: const Text('Oat milk by default'),
                value: _oatMilk,
                onChanged: (v) => setState(() => _oatMilk = v),
              ),
              const ListTile(
                leading: Icon(Icons.credit_card),
                title: Text('Payment methods'),
                trailing: Icon(Icons.chevron_right),
              ),
              const ListTile(
                leading: Icon(Icons.location_on_outlined),
                title: Text('Favourite branch'),
                subtitle: Text('Bunn Downtown'),
                trailing: Icon(Icons.chevron_right),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
