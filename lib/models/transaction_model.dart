enum TransactionType { cashIn, cashOut }

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String note;
  final DateTime? dueDate;
  final bool reminderEnabled;
  final String? phoneNumber;
  final bool isPaid;

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note = '',
    this.dueDate,
    this.reminderEnabled = false,
    this.phoneNumber,
    this.isPaid = false,
  });

  bool get isCashIn => type == TransactionType.cashIn;
  bool get isCashOut => type == TransactionType.cashOut;
  bool get isDue => isCashOut && dueDate != null && !isPaid;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.name,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'dueDate': dueDate?.toIso8601String(),
      'reminderEnabled': reminderEnabled,
      'phoneNumber': phoneNumber,
      'isPaid': isPaid,
    };
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled',
      amount: (json['amount'] as num).toDouble(),
      type: (json['type'] as String) == 'cashIn'
          ? TransactionType.cashIn
          : TransactionType.cashOut,
      category: json['category'] as String? ?? 'Other',
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String? ?? '',
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      reminderEnabled: json['reminderEnabled'] as bool? ?? false,
      phoneNumber: json['phoneNumber'] as String?,
      isPaid: json['isPaid'] as bool? ?? false,
    );
  }

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    String? category,
    DateTime? date,
    String? note,
    DateTime? dueDate,
    bool? reminderEnabled,
    String? phoneNumber,
    bool? isPaid,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      dueDate: dueDate ?? this.dueDate,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}
