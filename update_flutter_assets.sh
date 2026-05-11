#!/bin/bash

update_assets() {
    # 获取脚本所在目录
    DIR=$(cd "$(dirname "$0")" && pwd)
    cd "$DIR"

    # 检查 assets/out/ 目录是否存在
    if [ ! -d "assets/out" ]; then
        echo "错误：目录 assets/out 不存在！"
        return 1
    fi

    # 查找所有子目录（递归）
    # 使用 find 命令，对结果按字母顺序排序
    echo "正在扫描 assets/out/ 下的子目录..."

    # 使用 sort 确保顺序一致
    dirs=$(find "assets/out" -type d | sort)

    # 构建新的 assets 配置
    new_assets_section="  assets:"

    # 遍历目录，添加到配置中
    while IFS= read -r dir; do
        # 替换为相对路径格式
        asset_path=$(echo "$dir" | sed 's|$|/|')
        new_assets_section+=$'\n'"    - $asset_path"
    done <<< "$dirs"

    # 计算目录数量
    num_dirs=$(echo "$dirs" | grep -c 'assets/out')

    # 读取原 pubspec.yaml
    pubspec_content=$(cat "pubspec.yaml")

    # 定位 assets 部分并替换
    # 使用 perl 进行替换，更安全
    if echo "$pubspec_content" | grep -q "  assets:"; then
        # 使用 awk 处理替换
        # 找到  assets: 行，然后找到下一个以两个空格开头但不是四个空格的行
        # 替换中间内容为新的 assets 部分
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

        # 检查是否替换成功
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

update_assets
