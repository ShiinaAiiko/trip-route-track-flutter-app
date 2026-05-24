enum WebViewEngine {
  gecko,
  system,
}

class WebViewOptions {
  final WebViewEngine engine;
  final String initialUrl;
  final bool enableJavascript;
  final bool enableGeolocation;
  final bool enableMixedContent;
  final int serverPort;
  final Map<String, String>? headers;

  const WebViewOptions({
    this.engine = WebViewEngine.gecko,
    required this.initialUrl,
    this.enableJavascript = true,
    this.enableGeolocation = false,
    this.enableMixedContent = true,
    this.serverPort = 13218,
    this.headers,
  });

  WebViewOptions copyWith({
    WebViewEngine? engine,
    String? initialUrl,
    bool? enableJavascript,
    bool? enableGeolocation,
    bool? enableMixedContent,
    int? serverPort,
    Map<String, String>? headers,
  }) {
    return WebViewOptions(
      engine: engine ?? this.engine,
      initialUrl: initialUrl ?? this.initialUrl,
      enableJavascript: enableJavascript ?? this.enableJavascript,
      enableGeolocation: enableGeolocation ?? this.enableGeolocation,
      enableMixedContent: enableMixedContent ?? this.enableMixedContent,
      serverPort: serverPort ?? this.serverPort,
      headers: headers ?? this.headers,
    );
  }
}