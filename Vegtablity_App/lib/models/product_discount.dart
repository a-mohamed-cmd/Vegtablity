class ProductDiscount {
  final int discountId;
  final String discountName;
  final int discountType; // 1: Percentage %, 2: Fixed Amount, 3: Bundle/Qty Tier
  final double discountValue;
  final double minQuantity;
  final int productId;

  ProductDiscount({
    required this.discountId,
    required this.discountName,
    required this.discountType,
    required this.discountValue,
    required this.minQuantity,
    required this.productId,
  });

  factory ProductDiscount.fromJson(Map<String, dynamic> json) {
    return ProductDiscount(
      discountId: json['DiscountID'] ?? json['discountId'] ?? 0,
      discountName: json['DiscountName'] ?? json['discountName'] ?? '',
      discountType: json['DiscountType'] ?? json['discountType'] ?? 1,
      discountValue: (json['DiscountValue'] ?? json['discountValue'] ?? 0.0).toDouble(),
      minQuantity: (json['MinQuantity'] ?? json['minQuantity'] ?? 1.0).toDouble(),
      productId: json['ProductID'] ?? json['productId'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'DiscountID': discountId,
      'DiscountName': discountName,
      'DiscountType': discountType,
      'DiscountValue': discountValue,
      'MinQuantity': minQuantity,
      'ProductID': productId,
    };
  }

  /// Calculates discount amount for a given unit price & quantity
  double calculateDiscountAmount(double unitPrice, double quantity) {
    if (quantity < minQuantity) return 0.0;

    if (discountType == 1) {
      // Percentage %
      return (unitPrice * (discountValue / 100.0)) * quantity;
    } else if (discountType == 2) {
      // Fixed Amount per unit
      return discountValue * quantity;
    } else if (discountType == 3) {
      // Bundle Total Discount
      return discountValue;
    }
    return 0.0;
  }

  String get formattedLabel {
    final String qtySuffix = minQuantity > 1 ? ' (≥${minQuantity.toStringAsFixed(0)})' : '';
    if (discountType == 1) {
      return '$discountName (${discountValue.toStringAsFixed(0)}%)$qtySuffix';
    } else if (discountType == 2) {
      return '$discountName (-${discountValue.toStringAsFixed(3)})$qtySuffix';
    } else {
      return '$discountName (باقة -${discountValue.toStringAsFixed(3)})$qtySuffix';
    }
  }
}
