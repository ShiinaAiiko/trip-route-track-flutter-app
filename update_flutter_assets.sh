#!/bin/bash

update_assets() {
    DIR=$(cd "$(dirname "$0")" && pwd)
    cd "$DIR"

    if [ ! -d "assets/out" ]; then
        echo "错误：目录 assets/out 不存在！"
        return 1
    fi

    echo "正在扫描 assets/out/ 下的子目录..."

    dirs=$(find "assets/out" -type d | sort)

    new_assets_section="  assets:"
    # 保留 .env 文件配置（用于 flutter_dotenv）
    new_assets_section+=$'\n'"    - .env"

    while IFS= read -r dir; do
        asset_path=$(echo "$dir" | sed 's|$|/|')
        new_assets_section+=$'\n'"    - $asset_path"
    done <<< "$dirs"

    num_dirs=$(echo "$dirs" | grep -c 'assets/out')

    pubspec_content=$(cat "pubspec.yaml")

    if echo "$pubspec_content" | grep -q "  assets:"; then
        awk -v new="$new_assets_section" '
            BEGIN { in_assets=0; printed=0 }
            /^  assets:/ { in_assets=1; print new; printed=1; next }
            in_assets {
                if (/^  [a-z]/ || /^flutter:/ || /^dev_dependencies:/ || /^dependencies:/ || /^environment:/ || /^$/ && printed) {
                    in_assets=0
                    print
                }
            }
            !in_assets { print }
        ' "pubspec.yaml" > "pubspec.tmp"

        if [ -s "pubspec.tmp" ]; then
            mv "pubspec.tmp" "pubspec.yaml"
            echo "✅ pubspec.yaml 已更新，包含 $num_dirs 个目录"
        else
            echo "错误：替换失败！"
            rm -f "pubspec.tmp"
            return 1
        fi
    else
        echo "错误：未找到 assets 部分！"
        return 1
    fi

    return 0
}

update_app_icons() {
    DIR=$(cd "$(dirname "$0")" && pwd)
    cd "$DIR"

    icons_dir="assets/out/icons"
    if [ ! -d "$icons_dir" ]; then
        echo "警告：图标目录 $icons_dir 不存在，跳过图标更新"
        return 0
    fi

    echo "正在更新 App 图标..."

    cp "$icons_dir/48x48.png" "android/app/src/main/res/mipmap-mdpi/ic_launcher.png" 2>/dev/null || echo "  ⚠️  缺少 48x48.png"
    cp "$icons_dir/64x64.png" "android/app/src/main/res/mipmap-hdpi/ic_launcher.png" 2>/dev/null || echo "  ⚠️  缺少 64x64.png"
    cp "$icons_dir/128x128.png" "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png" 2>/dev/null || echo "  ⚠️  缺少 128x128.png"
    cp "$icons_dir/256x256.png" "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png" 2>/dev/null || echo "  ⚠️  缺少 256x256.png"
    cp "$icons_dir/512x512.png" "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" 2>/dev/null || echo "  ⚠️  缺少 512x512.png"

    echo "✅ App 图标已更新"

    return 0
}

update_assets
update_app_icons
