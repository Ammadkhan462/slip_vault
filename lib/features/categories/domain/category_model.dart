import 'package:flutter/material.dart';

class CategoryItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

class SlipCategories {
  static const List<CategoryItem> all = [
    CategoryItem(
      id: 'General',
      name: 'General',
      icon: Icons.category_outlined,
      color: Color(0xFF64748B),
    ),
    CategoryItem(
      id: 'Business / Freelance',
      name: 'Business & Freelance',
      icon: Icons.work_outline,
      color: Color(0xFF3B82F6),
    ),
    CategoryItem(
      id: 'Salary / Income',
      name: 'Salary & Income',
      icon: Icons.payments_outlined,
      color: Color(0xFF10B981),
    ),
    CategoryItem(
      id: 'Utilities & Bills',
      name: 'Utilities & Bills',
      icon: Icons.bolt_outlined,
      color: Color(0xFFF59E0B),
    ),
    CategoryItem(
      id: 'Inventory / Supplies',
      name: 'Inventory & Supplies',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF8B5CF6),
    ),
    CategoryItem(
      id: 'Rent & Office',
      name: 'Rent & Office',
      icon: Icons.apartment_outlined,
      color: Color(0xFFEC4899),
    ),
    CategoryItem(
      id: 'Personal / Family',
      name: 'Personal & Family',
      icon: Icons.home_outlined,
      color: Color(0xFF06B6D4),
    ),
    CategoryItem(
      id: 'Food & Dining',
      name: 'Food & Dining',
      icon: Icons.restaurant_outlined,
      color: Color(0xFFF97316),
    ),
    CategoryItem(
      id: 'Tax Deductible',
      name: 'Tax Deductible',
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF14B8A6),
    ),
  ];

  static CategoryItem get(String? id) {
    if (id == null) return all.first;
    return all.firstWhere(
      (c) => c.id.toLowerCase() == id.toLowerCase(),
      orElse: () => all.first,
    );
  }

  static String detect({
    required String ocrText,
    String? counterparty,
    String? provider,
    String? direction,
  }) {
    final text = '${ocrText.toLowerCase()} ${(counterparty ?? '').toLowerCase()} ${(provider ?? '').toLowerCase()}';

    // Utilities
    final utilityKeywords = [
      'kelectric', 'k-electric', 'lesco', 'gepco', 'fesco', 'mepco', 'hesco', 'pesco', 'qesco',
      'sngpl', 'ssgc', 'ptcl', 'nayatel', 'stormfiber', 'bill', 'electricity', 'sui gas', 'water board',
      'kw&sb', 'wasa', 'utility', 'energy bill'
    ];
    for (final kw in utilityKeywords) {
      if (text.contains(kw)) return 'Utilities & Bills';
    }

    // Salary & Income
    final salaryKeywords = ['salary', 'payroll', 'stipend', 'wages', 'remuneration', 'monthly pay'];
    for (final kw in salaryKeywords) {
      if (text.contains(kw)) return 'Salary / Income';
    }

    // Rent
    final rentKeywords = ['rent', 'landlord', 'tenancy', 'lease', 'office rent', 'flat rent'];
    for (final kw in rentKeywords) {
      if (text.contains(kw)) return 'Rent & Office';
    }

    // Food & Dining
    final foodKeywords = [
      'foodpanda', 'kfc', 'mcdonald', 'subway', 'restaurant', 'cafe', 'dining', 'bakery',
      'cheezious', 'dominos', 'pizza', 'burger'
    ];
    for (final kw in foodKeywords) {
      if (text.contains(kw)) return 'Food & Dining';
    }

    // Business & Freelance
    final freelanceKeywords = [
      'upwork', 'fiverr', 'client', 'invoice', 'consulting', 'software', 'developer',
      'freelance', 'project', 'milestone', 'payment for services', 'vendor payment'
    ];
    for (final kw in freelanceKeywords) {
      if (text.contains(kw)) return 'Business / Freelance';
    }

    // Inventory & Supplies
    final inventoryKeywords = ['wholesale', 'supplies', 'inventory', 'raw material', 'stock purchase'];
    for (final kw in inventoryKeywords) {
      if (text.contains(kw)) return 'Inventory / Supplies';
    }

    if (direction == 'received') return 'Business / Freelance';
    return 'General';
  }
}
