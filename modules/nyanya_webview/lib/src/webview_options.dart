enum WebViewEngine {
  gecko,
  system,
}

enum NewTabBehavior {
  replace,
  delegate,
}

typedef OpenUrlHandler = void Function(String url, String? target);

class WebViewOptions {
  final WebViewEngine engine;
  final String initialUrl;
  final bool enableJavascript;
  final bool enableGeolocation;
  final bool enableMixedContent;
  final int serverPort;
  final Map<String, String>? headers;
  final NewTabBehavior newTabBehavior;

  const WebViewOptions({
    this.engine = WebViewEngine.gecko,
    required this.initialUrl,
    this.enableJavascript = true,
    this.enableGeolocation = false,
    this.enableMixedContent = true,
    this.serverPort = 13218,
    this.headers,
    this.newTabBehavior = NewTabBehavior.delegate,
  });

  WebViewOptions copyWith({
    WebViewEngine? engine,
    String? initialUrl,
    bool? enableJavascript,
    bool? enableGeolocation,
    bool? enableMixedContent,
    int? serverPort,
    Map<String, String>? headers,
    NewTabBehavior? newTabBehavior,
  }) {
    return WebViewOptions(
      engine: engine ?? this.engine,
      initialUrl: initialUrl ?? this.initialUrl,
      enableJavascript: enableJavascript ?? this.enableJavascript,
      enableGeolocation: enableGeolocation ?? this.enableGeolocation,
      enableMixedContent: enableMixedContent ?? this.enableMixedContent,
      serverPort: serverPort ?? this.serverPort,
      headers: headers ?? this.headers,
      newTabBehavior: newTabBehavior ?? this.newTabBehavior,
    );
  }
}