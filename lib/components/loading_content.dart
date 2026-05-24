import 'package:flutter/material.dart';
import 'loading_dots.dart';
import '../models/loading_log.dart';

class LoadingContent extends StatelessWidget {
  final Brightness brightness;
  final String subtitle;
  final List<LoadingLog> loadingLog;

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
                itemCount: _displayLoadingLogs.length,
                itemBuilder: (context, index) {
                  final log = _displayLoadingLogs[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      log.message,
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

  List<LoadingLog> get _displayLoadingLogs {
    // 每种类型只显示最新的一条，总共最多显示3条（引擎、服务器、界面）
    Map<LoadingLogType, LoadingLog> latestLogs = {};
    
    // 遍历所有日志，每种类型保留最新的一条
    for (final log in loadingLog) {
      latestLogs[log.type] = log;
    }
    
    // 按固定顺序返回：引擎 → 服务器 → 界面
    List<LoadingLog> result = [];
    if (latestLogs.containsKey(LoadingLogType.engine)) {
      result.add(latestLogs[LoadingLogType.engine]!);
    }
    if (latestLogs.containsKey(LoadingLogType.server)) {
      result.add(latestLogs[LoadingLogType.server]!);
    }
    if (latestLogs.containsKey(LoadingLogType.web)) {
      result.add(latestLogs[LoadingLogType.web]!);
    }
    
    return result;
  }
}
