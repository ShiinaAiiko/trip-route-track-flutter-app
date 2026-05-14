import 'package:flutter/material.dart';
import 'loading_dots.dart';

class LoadingContent extends StatelessWidget {
  final Brightness brightness;
  final String subtitle;
  final List<String> loadingLog;

  const LoadingContent({
    super.key,
    required this.brightness,
    required this.subtitle,
    required this.loadingLog,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: LoadingDots(brightness: brightness),
        ),
        Positioned(
          bottom: 80,
          left: 40,
          right: 40,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredLoadingLog.length,
                itemBuilder: (context, index) {
                  final log = _filteredLoadingLog[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      log,
                      style: TextStyle(
                        color: brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.8)
                            : Colors.black.withOpacity(0.8),
                        fontSize: 13,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              subtitle,
              style: TextStyle(
                color: brightness == Brightness.dark ? Colors.white : Colors.black,
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<String> get _filteredLoadingLog {
    final Map<String, String> latestStatus = {};

    for (final log in loadingLog) {
      if (log.contains('GeckoView') || log.contains('内核')) {
        latestStatus['gecko'] = log;
      } else if (log.contains('服务') || log.toLowerCase().contains('server')) {
        latestStatus['server'] = log;
      } else if (log.contains('界面') || log.toLowerCase().contains('interface') || log.contains('准备')) {
        latestStatus['web'] = log;
      }
    }

    return latestStatus.values.toList();
  }
}
