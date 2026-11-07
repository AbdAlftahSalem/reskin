import 'package:flutter/material.dart';

class Offer {
  const Offer(this.title, this.store, this.price, this.oldPrice, this.discount,
      this.icon);
  final String title;
  final String store;
  final String price;
  final String oldPrice;
  final int discount;
  final IconData icon;
}

const List<Offer> hotOffers = <Offer>[
  Offer('Wireless Earbuds', 'SoundLab', '\$39', '\$79', 50, Icons.headphones),
  Offer('Smart Watch S2', 'Tickr', '\$89', '\$129', 30, Icons.watch),
  Offer('Espresso Maker', 'Brewly', '\$54', '\$90', 40, Icons.coffee_maker),
];

class Deal {
  const Deal(this.name, this.detail, this.distance);
  final String name;
  final String detail;
  final String distance;
}

const List<Deal> nearbyDeals = <Deal>[
  Deal('Green Basket Market', 'Fresh produce · 20% off', '0.4 km'),
  Deal('Urban Threads', 'Buy 2, get 1 free', '1.1 km'),
];
