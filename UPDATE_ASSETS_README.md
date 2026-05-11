# 更新 pubspec.yaml 的自动化脚本

## 使用说明

### 1. 何时运行此脚本

每次重新构建网站（构建生成新的 `_next/` 目录）后，在构建 Flutter 应用前，请运行此脚本。

### 2. 运行脚本

```bash
cd /path/to/trip-route-track-flutter-app
python3 update_flutter_assets.py
```

### 3. 脚本功能

这个脚本会：
- 自动扫描 `assets/out/` 下所有子目录
- 更新 `pubspec.yaml` 中的 assets 配置
- 按字母顺序排序，保持文件整洁

### 4. 完整工作流程

```bash
# 步骤 1：构建你的网站（生成新的 _next/ 等目录）
# ...（你的网站构建命令）...

# 步骤 2：运行更新脚本
python3 update_flutter_assets.py

# 步骤 3：构建 Flutter 应用
flutter build apk
```
