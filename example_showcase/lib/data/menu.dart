/// One item on the menu.
class Drink {
  const Drink({
    required this.id,
    required this.name,
    required this.origin,
    required this.subtitle,
    required this.price,
    required this.image,
    required this.category,
    required this.rating,
    required this.reviews,
    required this.description,
    this.isNew = false,
  });

  final String id;
  final String name;
  /// Origin and tasting line shown under the name on the details screen.
  final String origin;
  final String subtitle;
  final double price;
  final String image;
  final String category;
  final double rating;
  final int reviews;
  final String description;
  final bool isNew;
}

const List<String> categories = <String>[
  'All',
  'Espresso',
  'Cold',
  'Arabic',
  'Bakery',
];

const List<Drink> menu = <Drink>[
  Drink(
    id: 'flat-white',
    name: 'Flat White',
    origin: 'Ethiopia Guji · stone fruit & cocoa',
    subtitle: 'Double ristretto · silky milk',
    price: 4.20,
    image: 'assets/images/latte.jpg',
    category: 'Espresso',
    rating: 4.9,
    reviews: 1240,
    description:
        'Two ristretto shots of our Ethiopia Guji roast under a thin layer of '
        'velvety microfoam. Sweet, round, with notes of stone fruit and cocoa.',
  ),
  Drink(
    id: 'spanish-latte',
    name: 'Iced Spanish Latte',
    origin: 'Brazil Cerrado · caramel sweet',
    subtitle: 'Condensed milk · espresso',
    price: 5.10,
    image: 'assets/images/iced.jpg',
    category: 'Cold',
    rating: 4.8,
    reviews: 980,
    isNew: true,
    description:
        'Espresso poured over cold milk sweetened with condensed milk and '
        'served over ice. Our most ordered drink after 2 pm.',
  ),
  Drink(
    id: 'arabic-coffee',
    name: 'Saudi Qahwa',
    origin: 'Yemeni beans · light roast',
    subtitle: 'Cardamom · saffron · dates',
    price: 3.50,
    image: 'assets/images/cardamom.jpg',
    category: 'Arabic',
    rating: 5.0,
    reviews: 640,
    description:
        'Lightly roasted beans brewed with green cardamom and a thread of '
        'saffron, poured into finjan cups and served with Khalas dates.',
  ),
  Drink(
    id: 'cortado',
    name: 'Cortado',
    origin: 'House blend · bold & balanced',
    subtitle: 'Equal espresso & milk',
    price: 3.80,
    image: 'assets/images/cortado.jpg',
    category: 'Espresso',
    rating: 4.7,
    reviews: 410,
    description:
        'A short, strong balance of espresso and warm milk in a Gibraltar '
        'glass. For when a flat white feels like too much milk.',
  ),
  Drink(
    id: 'cold-brew',
    name: 'Orange Cold Brew',
    origin: 'Colombia Huila · bright citrus',
    subtitle: '18-hour steep · citrus',
    price: 4.90,
    image: 'assets/images/coldbrew.jpg',
    category: 'Cold',
    rating: 4.6,
    reviews: 355,
    isNew: true,
    description:
        'Colombian beans steeped cold for 18 hours, finished with a twist of '
        'fresh orange. Smooth, bright and low in acidity.',
  ),
  Drink(
    id: 'croissant',
    name: 'Butter Croissant',
    origin: 'French butter · baked at 6 am',
    subtitle: 'Baked every morning',
    price: 2.90,
    image: 'assets/images/croissant.jpg',
    category: 'Bakery',
    rating: 4.8,
    reviews: 720,
    description:
        'Laminated with French butter over three days and baked in house at '
        '6 am. Crisp shell, honeycomb inside.',
  ),
];
