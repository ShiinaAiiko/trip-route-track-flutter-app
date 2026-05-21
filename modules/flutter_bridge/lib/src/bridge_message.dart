class BridgeMessage {
  final String type;
  final dynamic payload;
  final String? bridgeId;

  BridgeMessage({
    required this.type,
    this.payload,
    this.bridgeId,
  });

  factory BridgeMessage.fromJson(Map<String, dynamic> json) {
    return BridgeMessage(
      type: json['type'] as String,
      payload: json['payload'],
      bridgeId: json['bridgeId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'type': type,
      'payload': payload,
    };
    if (bridgeId != null) {
      json['bridgeId'] = bridgeId;
    }
    return json;
  }

  String toJsonString() {
    return toJson().toString();
  }
}
