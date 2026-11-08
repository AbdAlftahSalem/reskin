import 'package:flutter/foundation.dart';

import '../data/menu.dart';

/// One line in the order.
class CartLine {
  const CartLine(this.drink,
      {this.qty = 1, this.size = 'M', this.milk = 'Oat'});
  final Drink drink;
  final int qty;
  final String size;
  final String milk;

  double get total => drink.price * qty + (size == 'L' ? 0.6 * qty : 0);

  CartLine withQty(int q) => CartLine(drink, qty: q, size: size, milk: milk);
}

/// The current order. Starts with two items so the order screen is real.
final ValueNotifier<List<CartLine>> cart = ValueNotifier<List<CartLine>>(
  <CartLine>[
    CartLine(menu[0], qty: 1, size: 'M', milk: 'Oat'),
    CartLine(menu[5], qty: 2, size: '-', milk: '-'),
  ],
);

void addToCart(CartLine line) {
  cart.value = <CartLine>[...cart.value, line];
}

void setQty(int index, int qty) {
  final next = <CartLine>[...cart.value];
  if (qty <= 0) {
    next.removeAt(index);
  } else {
    next[index] = next[index].withQty(qty);
  }
  cart.value = next;
}
