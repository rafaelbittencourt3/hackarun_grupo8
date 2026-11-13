class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
  });

  final int id;
  final String name;
  final double price;
  final String? imageUrl;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String?,
    );
  }
}

class Promotion {
  const Promotion({
    required this.id,
    required this.title,
    required this.description,
    required this.endsAt,
    this.price,
    this.store,
  });

  final int id;
  final String title;
  final String description;
  final DateTime endsAt;
  final double? price;
  final Store? store;

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      endsAt: DateTime.parse(json['ends_at'] as String),
      price: (json['price'] as num?)?.toDouble(),
      store: json['store'] == null
          ? null
          : Store.fromJson(json['store'] as Map<String, dynamic>),
    );
  }
}

class Store {
  const Store({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.floor,
    required this.latitude,
    required this.longitude,
    this.whatsapp,
    this.openingHours,
    this.imageUrl,
    this.products = const [],
    this.promotions = const [],
  });

  final int id;
  final String name;
  final String category;
  final String description;
  final int floor;
  final double latitude;
  final double longitude;
  final String? whatsapp;
  final String? openingHours;
  final String? imageUrl;
  final List<Product> products;
  final List<Promotion> promotions;

  String get floorLabel => '$floorº andar';

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as int,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      floor: json['floor'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      whatsapp: json['whatsapp'] as String?,
      openingHours: json['opening_hours'] as String?,
      imageUrl: json['image_url'] as String?,
      products: _list(json['products'], Product.fromJson),
      promotions: _list(json['promotions'], Promotion.fromJson),
    );
  }
}

/// Produto citado em uma resposta do guia, com a loja que o vende.
class ChatProduct {
  const ChatProduct({required this.product, required this.store});

  final Product product;
  final Store store;

  factory ChatProduct.fromJson(Map<String, dynamic> json) {
    return ChatProduct(
      product: Product.fromJson(json),
      store: Store.fromJson(json['store'] as Map<String, dynamic>),
    );
  }
}

class ChatAnswer {
  const ChatAnswer({
    required this.reply,
    this.stores = const [],
    this.products = const [],
    this.suggestions = const [],
    this.route,
  });

  /// Produtos citados na resposta, na ordem em que aparecem.
  final List<ChatProduct> products;

  /// Perguntas curtas que o visitante pode fazer em seguida.
  final List<String> suggestions;


  final String reply;

  /// Lojas citadas na resposta, da mais relevante para a menos.
  final List<Store> stores;

  /// Roteiro montado quando o visitante pede várias coisas na mesma visita.
  final RoutePlan? route;
}

class RouteStop {
  const RouteStop({
    required this.store,
    required this.item,
    required this.reason,
    required this.minutes,
    this.price,
  });

  final Store store;
  final String item;
  final String reason;
  final int minutes;
  final double? price;

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      store: Store.fromJson(json['store'] as Map<String, dynamic>),
      item: json['item'] as String,
      reason: json['reason'] as String,
      minutes: (json['minutes'] as num).toInt(),
      price: (json['price'] as num?)?.toDouble(),
    );
  }
}

class RoutePlan {
  const RoutePlan({
    required this.summary,
    required this.totalPrice,
    required this.totalMinutes,
    required this.stops,
  });

  final String summary;
  final double totalPrice;
  final int totalMinutes;
  final List<RouteStop> stops;

  factory RoutePlan.fromJson(Map<String, dynamic> json) {
    return RoutePlan(
      summary: json['summary'] as String,
      totalPrice: (json['total_price'] as num).toDouble(),
      totalMinutes: (json['total_minutes'] as num).toInt(),
      stops: _list(json['stops'], RouteStop.fromJson),
    );
  }
}

List<T> _list<T>(Object? json, T Function(Map<String, dynamic>) fromJson) {
  if (json is! List) {
    return const [];
  }

  return json.map((item) => fromJson(item as Map<String, dynamic>)).toList();
}

String formatPrice(double value) {
  return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
}
