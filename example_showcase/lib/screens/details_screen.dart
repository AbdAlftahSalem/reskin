import 'package:flutter/material.dart';

import '../data/menu.dart';
import '../state/cart.dart';

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({super.key, required this.drink});
  final Drink drink;

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  String _size = 'M';
  String _milk = 'Oat';
  final Set<String> _extras = <String>{'Extra shot'};
  int _qty = 1;

  double get _total =>
      (widget.drink.price + (_size == 'L' ? 0.6 : 0) + _extras.length * 0.5) *
      _qty;

  @override
  Widget build(BuildContext context) {
    final d = widget.drink;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            actions: <Widget>[
              IconButton.filledTonal(
                  onPressed: () {}, icon: const Icon(Icons.favorite_border)),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: d.id,
                child: Image.asset(d.image, fit: BoxFit.cover),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              transform: Matrix4.translationValues(0, -24, 0),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 130),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(d.name,
                                style: text.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            Text(d.origin,
                                style: text.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Text('\$${d.price.toStringAsFixed(2)}',
                          style: text.headlineSmall?.copyWith(
                              color: cs.primary, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(children: <Widget>[
                    const Icon(Icons.star_rounded,
                        size: 20, color: Color(0xFFF5A623)),
                    const SizedBox(width: 4),
                    Text('${d.rating}',
                        style: text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    Text('  (${d.reviews} reviews)',
                        style: text.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    const Spacer(),
                    Chip(
                      avatar: Icon(Icons.timer_outlined,
                          size: 16, color: cs.onSecondaryContainer),
                      label: const Text('4 min'),
                      backgroundColor: cs.secondaryContainer,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Text(d.description,
                      style: text.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant, height: 1.5)),
                  const SizedBox(height: 22),
                  Text('Size',
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const <ButtonSegment<String>>[
                        ButtonSegment<String>(value: 'S', label: Text('Small')),
                        ButtonSegment<String>(
                            value: 'M', label: Text('Medium')),
                        ButtonSegment<String>(value: 'L', label: Text('Large')),
                      ],
                      selected: <String>{_size},
                      onSelectionChanged: (s) =>
                          setState(() => _size = s.first),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Milk',
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: <String>['Whole', 'Oat', 'Almond', 'None']
                        .map((m) => ChoiceChip(
                              label: Text(m),
                              selected: _milk == m,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _milk = m),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Extras',
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: <String>['Extra shot', 'Vanilla', 'Cardamom']
                        .map((e) => FilterChip(
                              label: Text(e),
                              selected: _extras.contains(e),
                              onSelected: (v) => setState(
                                  () => v ? _extras.add(e) : _extras.remove(e)),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Material(
        color: cs.surfaceContainer,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: <Widget>[
                  IconButton(
                      onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                      icon: const Icon(Icons.remove)),
                  Text('$_qty',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  IconButton(
                      onPressed: () => setState(() => _qty++),
                      icon: const Icon(Icons.add)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    addToCart(CartLine(d, qty: _qty, size: _size, milk: _milk));
                    Navigator.of(context).maybePop();
                  },
                  child: Text('Add to order · \$${_total.toStringAsFixed(2)}'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
