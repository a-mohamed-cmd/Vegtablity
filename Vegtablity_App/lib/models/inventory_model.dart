class WastageItem {
  final int productID;
  final String productName;
  final String barcode;
  final String unitName;
  double quantity;
  double costPrice;
  double stockBefore;

  WastageItem({
    required this.productID,
    required this.productName,
    required this.barcode,
    required this.unitName,
    required this.quantity,
    required this.costPrice,
    this.stockBefore = 0.0,
  });

  double get totalCost => quantity * costPrice;

  Map<String, dynamic> toJson() {
    return {
      'ProductID': productID,
      'Quantity': quantity,
      'CostPrice': costPrice,
      'StockBefore': stockBefore,
    };
  }

  factory WastageItem.fromJson(Map<String, dynamic> json) {
    return WastageItem(
      productID: json['product_id'] ?? json['ProductID'] as int,
      productName: json['product_name'] ?? json['ProductName'] ?? '',
      barcode: json['barcode'] ?? json['Barcode'] ?? '',
      unitName: json['unit_name'] ?? json['UnitName'] ?? '',
      quantity: (json['quantity'] ?? json['Quantity'] as num).toDouble(),
      costPrice: (json['cost_price'] ?? json['CostPrice'] as num).toDouble(),
      stockBefore: (json['stock_before'] ?? json['StockBefore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class StockTakeItem {
  final int productID;
  final String productName;
  final String barcode;
  final String unitName;
  double systemQty;
  double actualQty;
  double costPrice;

  StockTakeItem({
    required this.productID,
    required this.productName,
    required this.barcode,
    required this.unitName,
    required this.systemQty,
    required this.actualQty,
    required this.costPrice,
  });

  double get diffQty => actualQty - systemQty;
  double get diffValue => diffQty * costPrice;

  Map<String, dynamic> toJson() {
    return {
      'ProductID': productID,
      'SystemQuantity': systemQty,
      'ActualQuantity': actualQty,
      'CostPrice': costPrice,
    };
  }

  factory StockTakeItem.fromJson(Map<String, dynamic> json) {
    return StockTakeItem(
      productID: json['product_id'] ?? json['ProductID'] as int,
      productName: json['product_name'] ?? json['ProductName'] ?? '',
      barcode: json['barcode'] ?? json['Barcode'] ?? '',
      unitName: json['unit_name'] ?? json['UnitName'] ?? '',
      systemQty: (json['system_qty'] ?? json['SystemQuantity'] as num).toDouble(),
      actualQty: (json['actual_qty'] ?? json['ActualQuantity'] as num).toDouble(),
      costPrice: (json['cost_price'] ?? json['CostPrice'] as num).toDouble(),
    );
  }
}
