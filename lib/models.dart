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
