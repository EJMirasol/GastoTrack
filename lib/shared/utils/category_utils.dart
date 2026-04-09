import 'package:flutter/material.dart';

const transferCategoryId = '10';
const transferFeeCategoryId = '11';

const categoryIconNames = [
  'restaurant',
  'directions_car',
  'shopping_bag',
  'movie',
  'receipt',
  'local_hospital',
  'school',
  'home',
  'account_balance_wallet',
  'swap_horiz',
  'fitness_center',
  'pets',
  'flight',
  'card_giftcard',
  'coffee',
  'music_note',
  'brush',
  'phone_android',
  'menu_book',
  'work',
];

const categoryPresetColors = [
  '#FF6B6B',
  '#4ECDC4',
  '#45B7D1',
  '#96CEB4',
  '#FECEA8',
  '#FF6F91',
  '#845EC2',
  '#D65DB1',
  '#4CAF50',
  '#FFC75F',
  '#FF8A65',
  '#78909C',
];

IconData getCategoryIconData(String iconName) {
  return switch (iconName) {
    'restaurant' => Icons.restaurant,
    'directions_car' => Icons.directions_car,
    'shopping_bag' => Icons.shopping_bag,
    'movie' => Icons.movie,
    'receipt' => Icons.receipt,
    'local_hospital' => Icons.local_hospital,
    'school' => Icons.school,
    'home' => Icons.home,
    'account_balance_wallet' => Icons.account_balance_wallet,
    'swap_horiz' => Icons.swap_horiz,
    'fitness_center' => Icons.fitness_center,
    'pets' => Icons.pets,
    'flight' => Icons.flight,
    'card_giftcard' => Icons.card_giftcard,
    'coffee' => Icons.coffee,
    'music_note' => Icons.music_note,
    'brush' => Icons.brush,
    'phone_android' => Icons.phone_android,
    'menu_book' => Icons.menu_book,
    'work' => Icons.work,
    _ => Icons.more_horiz,
  };
}

Color parseCategoryColor(
  String hexColor, {
  Color fallback = const Color(0xFF9E9E9E),
}) {
  try {
    return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
  } catch (_) {
    return fallback;
  }
}
