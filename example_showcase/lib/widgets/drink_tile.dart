import 'package:flutter/material.dart';

import '../data/menu.dart';

/// A product card in the Home grid.
class DrinkTile extends StatelessWidget {
  const DrinkTile(
      {super.key,
      required this.drink,
      required this.onTap,
      required this.onAdd});
  final Drink drink;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: Hero(
                        tag: drink.id,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(drink.image, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    if (drink.isNew)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE4572E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('NEW',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 0, 0),
                child: Text(drink.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 0, 0),
                child: Text(drink.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ),
              Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text('\$${drink.price.toStringAsFixed(2)}',
                        style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF7A5230))),
                  ),
                  const Spacer(),
                  IconButton.filled(
                    visualDensity: VisualDensity.compact,
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
