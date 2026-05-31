/// Sản phẩm (món ăn / đồ uống).
class Product {
  final String id;
  final String name;
  final int costPrice;
  final int salePrice;
  final int stockQty;
  final bool isActive;

  const Product({
    required this.id,
    required this.name,
    required this.costPrice,
    required this.salePrice,
    required this.stockQty,
    this.isActive = true,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        name: j['name'] as String,
        costPrice: (j['cost_price'] as num).toInt(),
        salePrice: (j['sale_price'] as num).toInt(),
        stockQty: (j['stock_qty'] as num).toInt(),
        isActive: j['is_active'] as bool? ?? true,
      );

  /// Map dùng để insert/update (không gồm id / created_at).
  Map<String, dynamic> toInsert() => {
        'name': name,
        'cost_price': costPrice,
        'sale_price': salePrice,
        'stock_qty': stockQty,
        'is_active': isActive,
      };

  Product copyWith({
    String? name,
    int? costPrice,
    int? salePrice,
    int? stockQty,
    bool? isActive,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        costPrice: costPrice ?? this.costPrice,
        salePrice: salePrice ?? this.salePrice,
        stockQty: stockQty ?? this.stockQty,
        isActive: isActive ?? this.isActive,
      );
}
