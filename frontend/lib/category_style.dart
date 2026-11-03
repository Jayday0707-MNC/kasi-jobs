import 'package:flutter/material.dart';

String shortCategory(String name) => name.split(' & ').first;

IconData categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('farm') || n.contains('agri')) return Icons.agriculture;
  if (n.contains('forest') || n.contains('saw')) return Icons.forest;
  if (n.contains('retail') || n.contains('hospit')) return Icons.storefront;
  if (n.contains('construct') || n.contains('trade')) return Icons.construction;
  if (n.contains('driv') || n.contains('transport'))
    return Icons.local_shipping;
  if (n.contains('domestic') || n.contains('clean'))
    return Icons.cleaning_services;
  if (n.contains('secur')) return Icons.shield;
  if (n.contains('admin') || n.contains('office')) return Icons.business_center;
  if (n.contains('learn') || n.contains('bursar')) return Icons.school;
  return Icons.work;
}

const _palette = [
  Color(0xFF16A34A),
  Color(0xFF2563EB),
  Color(0xFFF97316),
  Color(0xFF9333EA),
  Color(0xFFE11D48),
  Color(0xFF0891B2),
];

Color categoryColor(String name) {
  final sum = name.codeUnits.fold<int>(0, (a, b) => a + b);
  return _palette[sum % _palette.length];
}
class CategoryBadge extends StatelessWidget {
  const CategoryBadge(this.category, {super.key, this.size = 52});
  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(categoryIcon(category), color: color, size: size * 0.5),
    );
  }
}