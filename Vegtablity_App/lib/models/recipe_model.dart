class RecipeHeader {
  final int recipeID;
  final int productID;
  final String productName;
  final String? barcode;
  final int? productType;
  final double totalCost;
  final String? notes;
  final int ingredientsCount;
  final List<RecipeDetailItem> details;

  RecipeHeader({
    required this.recipeID,
    required this.productID,
    required this.productName,
    this.barcode,
    this.productType,
    required this.totalCost,
    this.notes,
    required this.ingredientsCount,
    this.details = const [],
  });

  factory RecipeHeader.fromJson(Map<String, dynamic> json) {
    return RecipeHeader(
      recipeID: json['RecipeID'] ?? 0,
      productID: json['ProductID'] ?? 0,
      productName: json['ProductName'] ?? '',
      barcode: json['Barcode'],
      productType: json['ProductType'],
      totalCost: (json['TotalCost'] as num?)?.toDouble() ?? 0.0,
      notes: json['Notes'],
      ingredientsCount: json['IngredientsCount'] ?? 0,
      details: (json['Details'] as List<dynamic>?)
              ?.map((d) => RecipeDetailItem.fromJson(d))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'RecipeID': recipeID,
      'ProductID': productID,
      'ProductName': productName,
      'Barcode': barcode,
      'ProductType': productType,
      'TotalCost': totalCost,
      'Notes': notes,
      'IngredientsCount': ingredientsCount,
      'Details': details.map((d) => d.toJson()).toList(),
    };
  }
}

class RecipeDetailItem {
  final int? recipeDetailID;
  final int? recipeID;
  final int ingredientProductID;
  final String ingredientName;
  final String? ingredientBarcode;
  final String? unitName;
  double qty;
  double unitCost;
  double lineCost;

  RecipeDetailItem({
    this.recipeDetailID,
    this.recipeID,
    required this.ingredientProductID,
    required this.ingredientName,
    this.ingredientBarcode,
    this.unitName,
    required this.qty,
    required this.unitCost,
    required this.lineCost,
  });

  factory RecipeDetailItem.fromJson(Map<String, dynamic> json) {
    return RecipeDetailItem(
      recipeDetailID: json['RecipeDetailID'],
      recipeID: json['RecipeID'],
      ingredientProductID: json['IngredientProductID'] ?? 0,
      ingredientName: json['IngredientName'] ?? '',
      ingredientBarcode: json['IngredientBarcode'],
      unitName: json['UnitName'],
      qty: (json['Qty'] as num?)?.toDouble() ?? 0.0,
      unitCost: (json['UnitCost'] as num?)?.toDouble() ?? 0.0,
      lineCost: (json['LineCost'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'RecipeDetailID': recipeDetailID,
      'RecipeID': recipeID,
      'IngredientProductID': ingredientProductID,
      'IngredientName': ingredientName,
      'IngredientBarcode': ingredientBarcode,
      'UnitName': unitName,
      'Qty': qty,
      'Cost': unitCost,
      'LineCost': lineCost,
    };
  }
}
