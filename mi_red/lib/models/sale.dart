class Sale {
  const Sale({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.product,
    required this.amount,
    required this.points,
    required this.saleDate,
  });

  factory Sale.fromRow(Map<String, dynamic> row) {
    final contact = row['crm_contacts'] as Map<String, dynamic>?;
    return Sale(
      id: row['id'] as String,
      contactId: row['contact_id'] as String?,
      contactName: contact?['name'] as String?,
      product: row['product'] as String,
      amount: (row['amount'] as num).toDouble(),
      points: (row['points'] as num).toDouble(),
      saleDate: DateTime.parse(row['sale_date'] as String),
    );
  }

  final String id;
  final String? contactId;
  final String? contactName;
  final String product;
  final double amount;
  final double points;
  final DateTime saleDate;
}
