import 'package:flutter/material.dart';

class CategoryItem {
  final String name;
  final IconData icon;
  final Color color;

  const CategoryItem({
    required this.name,
    required this.icon,
    required this.color,
  });
}

class AppCategories {
  static const List<CategoryItem> expenseCategories = [
    CategoryItem(
      name: 'Food',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFEF4444), // Red
    ),
    CategoryItem(
      name: 'Travel',
      icon: Icons.directions_bus_rounded,
      color: Color(0xFF3B82F6), // Blue
    ),
    CategoryItem(
      name: 'Fuel',
      icon: Icons.local_gas_station_rounded,
      color: Color(0xFFF59E0B), // Amber
    ),
    CategoryItem(
      name: 'Shopping',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFFEC4899), // Pink
    ),
    CategoryItem(
      name: 'Bills',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFF8B5CF6), // Purple
    ),
    CategoryItem(
      name: 'Rent',
      icon: Icons.home_rounded,
      color: Color(0xFF14B8A6), // Teal
    ),
    CategoryItem(
      name: 'Education',
      icon: Icons.school_rounded,
      color: Color(0xFF6366F1), // Indigo
    ),
    CategoryItem(
      name: 'Medical',
      icon: Icons.local_hospital_rounded,
      color: Color(0xFF10B981), // Emerald
    ),
    CategoryItem(
      name: 'Entertainment',
      icon: Icons.movie_rounded,
      color: Color(0xFFF97316), // Orange
    ),
    CategoryItem(
      name: 'Other',
      icon: Icons.more_horiz_rounded,
      color: Color(0xFF64748B), // Slate
    ),
  ];

  static const List<CategoryItem> incomeCategories = [
    CategoryItem(
      name: 'Salary',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF10B981), // Green
    ),
    CategoryItem(
      name: 'Business',
      icon: Icons.store_rounded,
      color: Color(0xFF2563EB), // Blue
    ),
    CategoryItem(
      name: 'Freelance',
      icon: Icons.work_rounded,
      color: Color(0xFF8B5CF6), // Purple
    ),
    CategoryItem(
      name: 'Investment',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF06B6D4), // Cyan
    ),
    CategoryItem(
      name: 'Gift',
      icon: Icons.card_giftcard_rounded,
      color: Color(0xFFEC4899), // Pink
    ),
    CategoryItem(
      name: 'Other',
      icon: Icons.monetization_on_rounded,
      color: Color(0xFF64748B), // Slate
    ),
  ];

  static CategoryItem getCategory(String name, {bool isIncome = false}) {
    final list = isIncome ? incomeCategories : expenseCategories;
    return list.firstWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
      orElse: () => CategoryItem(
        name: name,
        icon: isIncome ? Icons.monetization_on_rounded : Icons.more_horiz_rounded,
        color: const Color(0xFF64748B),
      ),
    );
  }
}
