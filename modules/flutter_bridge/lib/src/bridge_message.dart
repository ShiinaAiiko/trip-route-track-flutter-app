class BridgeMessage {
  final String type;
  final dynamic payload;

  BridgeMessage({
    required this.type,
    this.payload,
  });

  factory BridgeMessage.fromJson(Map<String, dynamic> json) {
    return BridgeMessage(
      type: json['type'] as String,
      payload: json['payload'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'payload': payload,
    };
  }

  String toJsonString() {
    return toJson().toString();
  }
}
