import 'package:flutter/material.dart';

import '../data/menu.dart';
import '../state/cart.dart';
import '../widgets/drink_tile.dart';
import '../widgets/promo_banner.dart';
import 'details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenCart});
  final VoidCallback onOpenCart;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _category = 'All';

  void _open(Drink d) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => DetailsScreen(drink: d)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final items = _category == 'All'
        ? menu
        : menu.where((d) => d.category == _category).toList();
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            sliver: SliverList.list(children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: cs.primaryContainer,
                    child: Text('A',
                        style: text.titleMedium?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('صباح الخير يا عبد ☀️',
                            style: text.titleMedium?.copyWith(
                                fontFamily: 'El Messiri',
                                fontWeight: FontWeight.w700)),
                        Row(children: <Widget>[
                          Icon(Icons.storefront_outlined,
                              size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text('Bunn Downtown · pickup in 8 min',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () {},
                    icon: const Badge(
                        smallSize: 8, child: Icon(Icons.notifications_none)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('What are we\nbrewing today?',
                  style: text.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800, height: 1.15)),
              const SizedBox(height: 16),
              SearchBar(
                hintText: 'Search coffee, pastries…',
                leading: const Icon(Icons.search),
                trailing: <Widget>[
                  IconButton(onPressed: () {}, icon: const Icon(Icons.tune)),
                ],
                padding: const WidgetStatePropertyAll<EdgeInsets>(
                    EdgeInsets.symmetric(horizontal: 14)),
              ),
              const SizedBox(height: 18),
              PromoBanner(onOrder: () => _open(menu[0])),
              const SizedBox(height: 18),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = categories[i];
                    return ChoiceChip(
                      label: Text(c),
                      selected: c == _category,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _category = c),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(children: <Widget>[
                Expanded(
                  child: Text('Popular now',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                TextButton(onPressed: () {}, child: const Text('See all')),
              ]),
              const SizedBox(height: 6),
            ]),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.66,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => DrinkTile(
                drink: items[i],
                onTap: () => _open(items[i]),
                onAdd: () => addToCart(CartLine(items[i])),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
