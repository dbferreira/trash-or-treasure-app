enum MessageRole { user, assistant }

class PriceInfo {
  final String low;
  final String high;

  PriceInfo({required this.low, required this.high});

  factory PriceInfo.fromJson(Map<String, dynamic> json) {
    return PriceInfo(
      low: json['low'] ?? '',
      high: json['high'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'low': low,
      'high': high,
    };
  }
}

class ItemInfo {
  final String name;
  final String description;

  ItemInfo({required this.name, required this.description});

  factory ItemInfo.fromJson(Map<String, dynamic> json) {
    return ItemInfo(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
    };
  }
}

class SourceInfo {
  final String url;
  final String type;

  SourceInfo({required this.url, required this.type});

  factory SourceInfo.fromJson(Map<String, dynamic> json) {
    return SourceInfo(
      url: json['url'] ?? '',
      type: json['type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type,
    };
  }
}

class WorkflowResult {
  final PriceInfo price;
  final int confidence;
  final List<SourceInfo> sources;
  final ItemInfo item;

  WorkflowResult({
    required this.price,
    required this.confidence,
    required this.sources,
    required this.item,
  });

  factory WorkflowResult.fromJson(Map<String, dynamic> json) {
    return WorkflowResult(
      price: PriceInfo.fromJson(json['price'] ?? {}),
      confidence: (json['confidence'] ?? 0).toInt(),
      sources: (json['sources'] as List? ?? [])
          .map((s) => SourceInfo.fromJson(s))
          .toList(),
      item: ItemInfo.fromJson(json['item'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'price': price.toJson(),
      'confidence': confidence,
      'sources': sources.map((s) => s.toJson()).toList(),
      'item': item.toJson(),
    };
  }
}

class PinnedResult {
  final String id;
  final String key;
  final WorkflowResult result;
  final DateTime pinnedAt;
  final String? locationLabel;
  final List<String> imagePaths;

  PinnedResult({
    required this.id,
    required this.key,
    required this.result,
    required this.pinnedAt,
    this.locationLabel,
    this.imagePaths = const [],
  });

  factory PinnedResult.fromJson(Map<String, dynamic> json) {
    return PinnedResult(
      id: json['id'] ?? '',
      key: json['key'] ?? '',
      result: WorkflowResult.fromJson(json['result'] ?? {}),
      pinnedAt: DateTime.tryParse(json['pinnedAt'] ?? '') ?? DateTime.now(),
      locationLabel: json['locationLabel'],
      imagePaths: (json['imagePaths'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'result': result.toJson(),
      'pinnedAt': pinnedAt.toIso8601String(),
      'locationLabel': locationLabel,
      'imagePaths': imagePaths,
    };
  }
}

class Message {
  final String id;
  final MessageRole role;
  final String? content;
  final List<String>? images;
  final WorkflowResult? result;
  final DateTime timestamp;
  final bool loading;

  Message({
    required this.id,
    required this.role,
    this.content,
    this.images,
    this.result,
    required this.timestamp,
    this.loading = false,
  });
}
