import 'package:flutter/material.dart';
import 'package:i18n/i18n_service.dart';

/// 更新对话框管理器
class UpdateDialogManager {
  static bool _isCheckingUpdateDialogOpen = false;
  static bool _isUpdateProgressDialogOpen = false;

  static final ValueNotifier<int> updateProgress = ValueNotifier(0);
  static final ValueNotifier<int> updateReceivedBytes = ValueNotifier(0);
  static final ValueNotifier<int> updateTotalBytes = ValueNotifier(0);
  static final ValueNotifier<bool> isDownloadComplete = ValueNotifier(false);

  /// 格式化字节数
  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 2)} ${suffixes[i]}';
  }

  /// 显示正在检查更新对话框
  static void showCheckingUpdateDialog(BuildContext context, I18nService i18n) {
    if (_isCheckingUpdateDialogOpen) return;
    _isCheckingUpdateDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(i18n.t('update_checking_title')),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(i18n.t('update_checking')),
          ],
        ),
      ),
    );
  }

  /// 关闭正在检查更新对话框
  static void closeCheckingUpdateDialog(BuildContext context) {
    if (_isCheckingUpdateDialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
      _isCheckingUpdateDialogOpen = false;
    }
  }

  /// 显示更新可用对话框
  static void showUpdateAvailableDialog({
    required BuildContext context,
    required I18nService i18n,
    required String version,
    required String downloadUrl,
    required VoidCallback onSkip,
    required VoidCallback onUpdateNow,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(i18n.t('update_available', {'version': version})),
        content: Text(i18n.t('update_available_content')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onSkip();
            },
            child: Text(i18n.t('update_skip')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onUpdateNow();
            },
            child: Text(i18n.t('update_now')),
          ),
        ],
      ),
    );
  }

  /// 显示无新版本对话框
  static void showNoUpdateDialog(BuildContext context, I18nService i18n, String currentVersion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(i18n.t('update_no_new_version_title')),
        content: Text(i18n.t('update_no_new_version_content', {'version': currentVersion})),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(i18n.t('confirm')),
          ),
        ],
      ),
    );
  }

  /// 显示更新进度对话框
  static void showUpdateProgressDialog({
    required BuildContext context,
    required I18nService i18n,
    required VoidCallback onBackgroundDownload,
    required VoidCallback onStopUpdate,
    required VoidCallback onInstallNow,
    required VoidCallback onLater,
    bool resetState = true,
  }) {
    if (_isUpdateProgressDialogOpen) return;
    _isUpdateProgressDialogOpen = true;
    if (resetState) {
      updateProgress.value = 0;
      updateReceivedBytes.value = 0;
      updateTotalBytes.value = 0;
      isDownloadComplete.value = false;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: ValueListenableBuilder<bool>(
              valueListenable: isDownloadComplete,
              builder: (context, complete, child) {
                return Text(complete 
                    ? i18n.t('update_download_complete_notification_title')
                    : i18n.t('update_downloading'));
              },
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: updateProgress,
                    builder: (context, progress, child) {
                      return LinearProgressIndicator(value: progress / 100);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 1,
                        child: ValueListenableBuilder<int>(
                          valueListenable: updateProgress,
                          builder: (context, progress, child) {
                            return Text(
                              '$progress%',
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: ValueListenableBuilder<int>(
                          valueListenable: updateReceivedBytes,
                          builder: (context, received, child) {
                            return ValueListenableBuilder<int>(
                              valueListenable: updateTotalBytes,
                              builder: (context, total, child) {
                                if (total <= 0) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  '${_formatBytes(received)} / ${_formatBytes(total)}',
                                  textAlign: TextAlign.right,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              ValueListenableBuilder<bool>(
                valueListenable: isDownloadComplete,
                builder: (context, complete, child) {
                  if (complete) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _isUpdateProgressDialogOpen = false;
                            onLater();
                          },
                          child: Text(i18n.t('update_later')),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            onInstallNow();
                          },
                          child: Text(i18n.t('update_install_now')),
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _isUpdateProgressDialogOpen = false;
                            onBackgroundDownload();
                          },
                          child: Text(i18n.t('update_background_download')),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _isUpdateProgressDialogOpen = false;
                            onStopUpdate();
                          },
                          child: Text(i18n.t('update_stop')),
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 更新进度
  static void updateProgressValue(int progress, int receivedBytes, int totalBytes) {
    updateProgress.value = progress;
    updateReceivedBytes.value = receivedBytes;
    updateTotalBytes.value = totalBytes;
  }

  /// 标记下载完成
  static void markDownloadComplete() {
    isDownloadComplete.value = true;
  }

  /// 直接设置为下载完成状态
  static void setDownloadComplete(int totalBytes) {
    updateProgress.value = 100;
    updateReceivedBytes.value = totalBytes;
    updateTotalBytes.value = totalBytes;
    isDownloadComplete.value = true;
  }

  /// 关闭更新进度对话框
  static void closeUpdateProgressDialog(BuildContext context) {
    if (_isUpdateProgressDialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
      _isUpdateProgressDialogOpen = false;
    }
  }

  /// 检查更新进度对话框是否打开
  static bool get isUpdateProgressDialogOpen => _isUpdateProgressDialogOpen;
}
