enum LoadingLogType {
  engine,    // 引擎
  server,    // 服务器
  web,       // 界面
}

class LoadingLog {
  final LoadingLogType type;
  final String message;

  LoadingLog({
    required this.type,
    required this.message,
  });

  @override
  String toString() {
    return 'LoadingLog{type: $type, message: $message}';
  }
}