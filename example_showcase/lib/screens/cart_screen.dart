import 'package:flutter/material.dart';

import '../state/cart.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _pickup = 'ASAP';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ValueListenableBuilder<List<CartLine>>(
      valueListenable: cart,
      builder: (context, lines, _) {
        final subtotal = lines.fold<double>(0, (s, l) => s + l.total);
        final discount = subtotal * 0.2;
        final total = subtotal - discount;
        return SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
                child: Row(children: <Widget>[
                  Text('Your order',
                      style: text.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Clear')),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: <Widget>[
                    for (var i = 0; i < lines.length; i++) ...<Widget>[
                      _LineTile(line: lines[i], index: i),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    Text('Pickup time',
                        style: text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: <String>['ASAP', '8:30', '8:45', '9:00']
                          .map((t) => ChoiceChip(
                                label: Text(t),
                                selected: _pickup == t,
                                showCheckmark: false,
                                avatar: t == 'ASAP'
                                    ? const Icon(Icons.bolt, size: 16)
                                    : null,
                                onSelected: (_) => setState(() => _pickup = t),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.local_offer_outlined),
                        hintText: 'Promo code',
                        suffixIcon: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('MORNING20'),
                        ),
                        filled: true,
                        fillColor: cs.surfaceContainerHigh,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(children: <Widget>[
                          _Row('Subtotal', subtotal),
                          const SizedBox(height: 8),
                          _Row('Morning ritual −20%', -discount,
                              color: cs.tertiary),
                          const Divider(height: 26),
                          _Row('Total', total, bold: true),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1B16),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('\$${total.toStringAsFixed(2)}',
                          style: text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text('Pickup $_pickup · Bunn Downtown',
                          style: text.bodySmall
                              ?.copyWith(color: cs.outlineVariant)),
                    ],
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.apple),
                    label: const Text('Pay'),
                  ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line, required this.index});
  final CartLine line;
  final int index;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final opts = <String>[
      if (line.size != '-') 'Size ${line.size}',
      if (line.milk != '-') '${line.milk} milk',
    ].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(line.drink.image,
                width: 68, height: 68, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(line.drink.name,
                    style:
                        text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                if (opts.isNotEmpty)
                  Text(opts,
                      style:
                          text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text('\$${line.total.toStringAsFixed(2)}',
                    style: text.titleSmall?.copyWith(
                        color: cs.primary, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: <Widget>[
              IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setQty(index, line.qty - 1),
                  icon: const Icon(Icons.remove, size: 18)),
              Text('${line.qty}',
                  style:
                      text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setQty(index, line.qty + 1),
                  icon: const Icon(Icons.add, size: 18)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false, this.color});
  final String label;
  final double value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = (bold ? text.titleMedium : text.bodyMedium)?.copyWith(
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color);
    final v = value < 0
        ? '−\$${(-value).toStringAsFixed(2)}'
        : '\$${value.toStringAsFixed(2)}';
    return Row(children: <Widget>[
      Text(label, style: style),
      const Spacer(),
      Text(v, style: style),
    ]);
  }
}
