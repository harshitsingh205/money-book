class BudgetModel {
  final String id;
  final String category; // 'Overall' or specific expense category name
  final double limitAmount;
  final int month;
  final int year;

  BudgetModel({
    required this.id,
    required this.category,
    required this.limitAmount,
    required this.month,
    required this.year,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'limitAmount': limitAmount,
      'month': month,
      'year': year,
    };
  }

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'] as String,
      category: json['category'] as String,
      limitAmount: (json['limitAmount'] as num).toDouble(),
      month: json['month'] as int,
      year: json['year'] as int,
    );
  }
}
