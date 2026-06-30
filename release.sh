#! /bin/bash
name="trip-route-track"
runName="$name-flutter-app"
port=23204
branch="main"
# // 注意，每次更新了一次app，
# 那么当前app的web版本就为支持app的最终web版本了
# // 新的app支持新的web了，新的web老版本不允许支持了
version="v1.1.2"
# configFilePath="config.dev.json"
configFilePath="config.pro.json"
currentTime=$(date +"%Y%m%d%H%M%S")
DIR=$(cd $(dirname $0) && pwd)
allowMethods=("up deleteRelease build:all addVersion build:new build:old build:byd build:test install install:test adb dev run stop protos start build buildDev setVersion profile profileDev release")

# 1. 基础配置（根据你的实际公开主库地址修改）
TARGET_REPO="ShiinaAiiko/nyanya-trip-route-track"
PREFIX="app-v"

# 加载环境变量
loadEnv() {
	if [ -f "$DIR/.env" ]; then
		echo "-> 加载环境变量..."
		export $(cat "$DIR/.env" | grep -v '#' | xargs)
	fi
}

# 设置 Google Client ID 环境变量
setGoogleClientId() {
	local env_type="$1"
	if [ "$env_type" == "dev" ]; then
		export GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID_DEV"
		echo "-> 使用开发环境 Google Client ID"
	else
		export GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID_PROD"
		echo "-> 使用生产环境 Google Client ID"
	fi
}

dev() {
	# adb logcat | grep "NyaNyaWebview"
	# adb logcat | grep "GeckoViewPlatform\|gps1"
	# adb logcat | grep "message.type\|gps12"
	# 更新 assets 目录配置

	# adb logcat -c && adb logcat | grep --line-buffered -E -i "onOpenUrl|NyaNyaWebViewLog" | grep --line-buffered -E -v -i "sendMessage|postMessage" | tee flutter_log.txt
	# adb logcat -c && adb logcat | grep --line-buffered -E -i "onLocationChange|onTitleChange" | grep --line-buffered -E -v -i "sendMessage|postMessage" | tee flutter_log.txt

	#  adb logcat -c && adb logcat | grep --line-buffered -E -i "onOpenUrl|NyaNyaWebViewLog|onLocationChange|onLocationChange|anGoBack|FlutterBridge" | grep --line-buffered -E -v -i "postMessage|location" | tee flutter_log.txt

	# adb logcat -c && adb logcat | grep --line-buffered -E -i "NyaNyaWebViewLog" | grep --line-buffered -E -v -i "postMessage|location" | tee flutter_log.txt

	# adb logcat -c && adb logcat | grep --line-buffered -E -i "" | grep --line-buffered -E -v -i "postMessage|location" | tee flutter_log.txt

	loadEnv
	setGoogleClientId "dev"
	setVersion

	export VERSION_TYPE="dev"

	echo "-> 更新 pubspec.yaml 的 assets 配置..."
	"$DIR/update_flutter_assets.sh"

	AUTO_DEVICE=$(flutter devices | grep "mobile" | awk -F '•' '{print $2}' | tr -d ' ')

	if [ -z "$AUTO_DEVICE" ]; then
		echo "警告：没发现安卓手机，将尝试默认模式..."
		flutter run --flavor dev "$@"
	else
		echo "发现真机：$AUTO_DEVICE，启动中..."
		flutter run -d "$AUTO_DEVICE" --flavor dev "$@" --no-dds
	fi
}

adb() {
	# powershell 运行
	# E:\Apps\platform-tools\adb.exe kill-server
	# E:\Apps\platform-tools\adb.exe -a nodaemon server start
	# 新开 powershell 运行
	# E:\Apps\platform-tools\adb.exe connect 192.168.1.100:45749

	# wsl2运行
	# export ADB_SERVER_SOCKET=tcp:172.25.240.1:5037
	# adb connect 192.168.1.100:45749

	# 暂时不管
	# unset ADB_SERVER_SOCKET
	# adb kill-server

	adb devices
	# adb install  /home/shiina_aiiko/Code/ShiinaAiikoDevWorkspace/OpenSourceProject/nyanya/nyanya-trip-route-track/trip-route-track-flutter-app/out/trip-route-track-v1.0.0-arm64-v8a.apk
}

start() {
	echo "-> 开始部署"

	protos

	cd $DIR/web
	./release.sh start

	cd $DIR/server
	./release.sh start
}

protos() {
	echo "-> 准备编译 Protobuf"

	cd $DIR/web
	./release.sh protos

	cd $DIR/server
	./release.sh protos
}
addVersion() {

	# 2. 计算新版本号
	# 使用 awk 自动处理 v1.0.3 -> v1.0.4 的转换
	new_version=$(echo $version | awk -F. '{$NF = $NF + 1;} 1' OFS=.)

	# 3. 同步到当前进程的变量（让接下来的脚本逻辑拿到新值）
	old_version=$version
	version=$new_version

	# 4. 永久写回文件 ($0 代表脚本自身)
	# 这里的正则会匹配 version="v数字.数字.数字"
	sed -i "s/version=\"$old_version\"/version=\"$version\"/" "$0"

	# --- 以下是测试代码，验证变量是否已经改变 ---
	echo "内存中的变量已更新为: $version"
}
minusVersion() {
	# 2. 计算新版本号
	# 使用 awk 处理 v1.0.4 -> v1.0.3 的转换，并在末尾数字为 0 时进行拦截
	new_version=$(echo $version | awk -F. '{
    if ($NF <= 0) {
      print "ERROR: 版本号末位已为 0，无法继续降级！" > "/dev/stderr";
      exit 1;
    }
    $NF = $NF - 1;
  } 1' OFS=.)

	# 如果 awk 报错退出了（比如已经是 0 了），就终止接下来改写文件的逻辑
	if [ $? -ne 0 ]; then
		return 1
	fi

	# 3. 同步到当前进程的变量（让接下来的脚本逻辑拿到新值）
	old_version=$version
	version=$new_version

	# 4. 永久写回文件 ($0 代表脚本自身)
	sed -i "s/version=\"$old_version\"/version=\"$version\"/" "$0"

	# --- 以下是测试代码，验证变量是否已经改变 ---
	echo "内存中的变量已降级为: $version"
}
setVersion() {
	echo "-> 设置 App 版本为 $version"

	# 1. 处理 VersionName (去掉开头的 v)
	versionName=$(echo $version | sed 's/v//')

	# 2. 从 pubspec.yaml 提取当前的 versionCode
	# 逻辑：找到 version: 行，取 + 号后面的数字
	oldCode=$(grep "version: " pubspec.yaml | cut -d+ -f2)

	# 3. 如果没找到或格式不对，给个初始值，否则自增 1
	if [ -z "$oldCode" ]; then
		versionCode=1
	else
		versionCode=$((oldCode + 1))
	fi

	echo "-> VersionName: $versionName, VersionCode: $versionCode"

	cd "$DIR"

	# 4. 更新 pubspec.yaml
	# 使用 @ 符号作为分隔符，防止内容里有特殊字符干扰
	sed -i "s@version: .*@version: $versionName+$versionCode@" pubspec.yaml

	# 5. 更新 local.properties (保持你原有的逻辑，但使用自增后的变量)
	if [ ! -f "$DIR/android/local.properties" ]; then
		# 修复：这里的 sdk.dir 路径通常是手动指定的，原脚本逻辑较简单
		echo "flutter.sdk=$(dirname $(which flutter))" >"$DIR/android/local.properties"
	fi

	sed -i "/flutter.versionName=/d" "$DIR/android/local.properties"
	sed -i "/flutter.versionCode=/d" "$DIR/android/local.properties"
	echo "flutter.versionName=$versionName" >>"$DIR/android/local.properties"
	echo "flutter.versionCode=$versionCode" >>"$DIR/android/local.properties"
}

build() {
	echo "-> 开始打包生产环境 Android APK（普通版本 + 比亚迪版本）"
	setVersion

	loadEnv
	setGoogleClientId "prod"
	_build "prod" "android"

	# 打包比亚迪版本
	# echo "-> 开始打包比亚迪车机版本 Android APK"
	# _build "prod" "byd"
}

build:all() {
	build:byd
	build
	build:test

	up

	install "byd"
	install "android"
	install "test"
	# release
}

build:byd() {
	echo "-> 开始单独打包比亚迪车机版本 Android APK"
	setVersion

	loadEnv
	setGoogleClientId "prod"
	_build "prod" "byd"

	# 移动当前版本的 BYD APK 到专用目录
	local BYD_PACKAGES_DIR="$DIR/out/byd_packages"
	mkdir -p "$BYD_PACKAGES_DIR"

	echo "-> 清理旧版本文件"
	rm -f "$BYD_PACKAGES_DIR/"*-byd-*${version}*.apk

	# 查找并移动所有当前版本的 byd apk 文件
	local packages_dir="$DIR/out/packages"
	if [ -d "$packages_dir" ]; then
		# 查找所有包含当前版本号的 byd apk
		local byd_apks=$(ls "$packages_dir"/*-byd-$version*.apk 2>/dev/null)
		if [ -n "$byd_apks" ]; then
			for byd_apk in $byd_apks; do
				if [ -f "$byd_apk" ]; then
					mv "$byd_apk" "$BYD_PACKAGES_DIR/"
					echo "✅ 已移动: $(basename $byd_apk)"
				fi
			done
			echo "✅ 所有 BYD APK 已移动至: $BYD_PACKAGES_DIR"
			ls -la "$BYD_PACKAGES_DIR"
		else
			echo "⚠️ 未找到当前版本 BYD APK 文件"
		fi
	fi
}

build:new() {
	echo "-> 开始打包生产环境 Android APK"
	loadEnv
	setGoogleClientId "prod"
	addVersion
	_build "prod"
}
build:old() {
	echo "-> 开始打包生产环境 Android APK"
	loadEnv
	setGoogleClientId "prod"
	minusVersion
	_build "prod"
}

buildDev() {
	echo "-> 开始打包开发环境 Android APK"
	loadEnv
	setGoogleClientId "dev"
	_build "dev"
}

build:test() {
	echo "-> 开始打包测试环境 Android APK"
	setVersion

	loadEnv
	setGoogleClientId "dev"
	_build "beta" "test"

	local TEST_PACKAGES_DIR="$DIR/out/test_packages"
	mkdir -p "$TEST_PACKAGES_DIR"

	echo "-> 清理旧版本文件"
	rm -f "$TEST_PACKAGES_DIR/"*-test-*${version}*.apk

	# 查找并移动所有当前版本的 byd apk 文件
	local packages_dir="$DIR/out"
	if [ -d "$packages_dir" ]; then
		# 查找所有包含当前版本号的 byd apk
		local test_apks=$(ls "$packages_dir"/*-test-$version*.apk 2>/dev/null)
		if [ -n "$test_apks" ]; then
			for test_apk in $test_apks; do
				if [ -f "$test_apk" ]; then
					mv "$test_apk" "$TEST_PACKAGES_DIR/"
					echo "✅ 已移动: $(basename $test_apk)"
				fi
			done
			echo "✅ 所有 BYD APK 已移动至: $TEST_PACKAGES_DIR"
			ls -la "$TEST_PACKAGES_DIR"
		else
			echo "⚠️ 未找到当前版本 BYD APK 文件"
		fi
	fi
}

profile() {
	echo "-> 启动生产环境性能测试模式"
	loadEnv
	setGoogleClientId "prod"
	setVersion
	_runProfile "prod"
}

profileDev() {
	echo "-> 启动开发环境性能测试模式"
	loadEnv
	setGoogleClientId "dev"
	setVersion
	_runProfile "dev"
}

_runProfile() {
	flavor="$1"
	echo "-> 更新 pubspec.yaml 的 assets 配置..."
	"$DIR/update_flutter_assets.sh"

	AUTO_DEVICE=$(flutter devices | grep "mobile" | awk -F '•' '{print $2}' | tr -d ' ')

	echo "-> 性能测试模式已启动！"
	echo "提示：打开 DevTools 分析性能数据"
	echo "      快捷键: Ctrl+Shift+P (VS Code) 或访问 http://localhost:9100"
	echo "      启动后查看终端输出获取完整 DevTools 地址"
	echo ""

	if [ -z "$AUTO_DEVICE" ]; then
		echo "警告：没发现安卓手机，将尝试默认模式..."
		flutter run --profile --flavor "$flavor"
	else
		echo "发现真机：$AUTO_DEVICE，启动性能测试模式..."
		flutter run -d "$AUTO_DEVICE" --profile --flavor "$flavor" --no-dds
	fi
}

_build() {
	flavor="$1"
	versionType="${2:-android}" # 默认值为 android
	cd $DIR

	# 更新 assets 目录配置
	echo "-> 更新 pubspec.yaml 的 assets 配置..."
	"$DIR/update_flutter_assets.sh"

	# 创建 out 和 packages 文件夹
	OUT_DIR="$DIR/out"
	PACKAGES_DIR="$OUT_DIR/packages"
	mkdir -p "$OUT_DIR" "$PACKAGES_DIR"

	# 清理 out 目录下的旧 APK
	rm -f "$OUT_DIR"/*.apk

	# 设置版本类型环境变量
	export VERSION_TYPE="$versionType"
	echo "-> 设置版本类型: $versionType"

	# addVersion (只在第一次构建时执行)
	if [ "$versionType" = "android" ]; then
		setVersion
	fi

	# 根据 flavor 添加 dart-define 参数
	local dartDefine="--dart-define=APP_FLAVOR=$flavor"
	if [ "$flavor" = "beta" ]; then
		echo "-> 使用 test 环境端口: 13221"
	elif [ "$flavor" = "dev" ]; then
		echo "-> 使用 dev 环境端口: 13218"
	elif [ "$flavor" = "prod" ]; then
		echo "-> 使用 prod 环境端口: 13219"
	fi

	flutter build apk --release --flavor "$flavor" --split-per-abi --no-shrink $dartDefine

	if [ $? -ne 0 ]; then
		echo "❌ flutter build 失败，停止执行"
		exit 1
	fi

	# 只有 build 成功才会执行到这里
	echo "✅ flutter build 成功，继续执行..."

	# 检查 APK 是否生成
	APK_DIR="$DIR/build/app/outputs/flutter-apk"
	apk_count=$(ls "$APK_DIR"/app-*-"$flavor"-release.apk 2>/dev/null | wc -l)
	if [ "$apk_count" -eq 0 ]; then
		echo "❌ 没有找到生成的 APK！"
		exit 1
	fi

	# APK 已生成，继续！
	echo "✅ 找到 APK，继续执行..."

	echo "-> 清理旧版本文件"
	# 重命名并复制
	if [ "$flavor" == "dev" ]; then
		rm -f "$PACKAGES_DIR/"${name}-v${version}*.apk
	elif [ "$flavor" == "beta" ]; then
		rm -f "$PACKAGES_DIR/"*-test-${version}*.apk
	elif [ "$versionType" == "byd" ]; then
		rm -f "$PACKAGES_DIR/"*-byd-*${version}*.apk
	else
		rm -f "$PACKAGES_DIR/"${name}-v${version}*.apk
		rm -f "$PACKAGES_DIR/"*-x86_64.apk
		rm -f "$PACKAGES_DIR/"*-armeabi-v7a.apk
	fi

	# 复制并重命名新 APK 到 out 和 packages
	echo "-> 整理新 APK 文件..."
	# /build/app/outputs/flutter-apk/app-arm64-v8a-dev-release.apk
	APK_DIR="$DIR/build/app/outputs/flutter-apk"
	for apk in "$APK_DIR"/app-*-"$flavor"-release.apk; do
		if [ -f "$apk" ]; then
			# 提取架构信息
			if [[ "$apk" == *-armeabi-v7a-* ]]; then
				arch="armeabi-v7a"
			elif [[ "$apk" == *-arm64-v8a-* ]]; then
				arch="arm64-v8a"
			elif [[ "$apk" == *-x86_64-* ]]; then
				arch="x86_64"
			else
				arch="universal"
			fi

			# 重命名并复制
			if [ "$flavor" == "dev" ]; then
				new_name="$name-dev-$version.${currentTime}-$arch.apk"
			elif [ "$flavor" == "beta" ]; then
				new_name="$name-test-$version.${currentTime}-$arch.apk"
			elif [ "$versionType" == "byd" ]; then
				new_name="$name-byd-$version.${currentTime}-$arch.apk"
				cp "$apk" "$PACKAGES_DIR/$new_name"
			else
				new_name="$name-$version.${currentTime}-$arch.apk"
				cp "$apk" "$PACKAGES_DIR/$new_name"
			fi
			cp "$apk" "$OUT_DIR/$new_name"
			echo "   $new_name"
		fi
	done

	# echo "-> 压缩 APK 中的 native libraries..." # 暂时禁用
	# KEYSTORE="$DIR/android/app/platform.keystore"
	# TMP_DIR="/tmp/apk_compress_$$"
	# for apk_file in "$OUT_DIR"/*.apk; do
	# 	if [ -f "$apk_file" ]; then
	# 		echo "   压缩: $(basename "$apk_file")"
	# 		rm -rf "$TMP_DIR"
	# 		mkdir -p "$TMP_DIR"
	# 		cd "$TMP_DIR"
	#
	# 		# 解压整个 APK
	# 		unzip -q "$apk_file"
	#
	# 		# 删除原 APK 和旧签名
	# 		rm -f "$apk_file"
	# 		rm -rf META-INF
	#
	# 		# 重新打包（最高压缩级别）
	# 		zip -r -9 "$apk_file" . >/dev/null 2>&1
	#
	# 		# 重新签名
	# 		if [ -f "$KEYSTORE" ]; then
	# 			echo "   重新签名..."
	# 			jarsigner -keystore "$KEYSTORE" -storepass "android" -keypass "android" "$apk_file" "androiddebugkey" >/dev/null 2>&1
	# 		else
	# 			echo "   警告：找不到签名文件 $KEYSTORE"
	# 		fi
	#
	# 		cd "$DIR"
	# 	fi
	# done
	# rm -rf "$TMP_DIR"
	# echo "-> 压缩完成！"

	echo "-> 版本类型 [$versionType] 打包完成！新 APK 文件已整理至：$OUT_DIR"
	ls -la "$OUT_DIR"

	# 显示安装命令（不实际执行安装）
	install "$versionType"

}

up() {
	# 在 WSL2 终端输入
	# 加上 -Force 确保覆盖
	# 只有生产包且不是BYD版本才上传到服务器
	# if [ "$flavor" == "prod" ] && [ "$versionType" != "byd" ]; then
	# 	# 上传到服务器（只有标准版本上传，BYD版本禁止上传）
	echo "-> 开始上传到服务器..."
	"$DIR/ssh.sh" run
	# elif [ "$versionType" == "byd" ]; then
	# 	echo "⚠️ 比亚迪车机版本禁止上传到服务器"
	# fi

	SEARCH_VERSION=$version
	PACKAGES_DIR="./out/packages"
	ARCH="arm64-v8a"
	BASE_URL="https://cdn-dl.aiiko.club/trip/"

	echo "========================================="
	echo "CDN 缓存预热任务"
	echo "搜索版本: $SEARCH_VERSION"
	echo "搜索目录: $PACKAGES_DIR"
	echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
	echo "========================================="

	# 检查目录
	if [ ! -d "$PACKAGES_DIR" ]; then
		echo "❌ 错误: 目录不存在"
		exit 1
	fi

	# 搜索文件
	file_list=$(find "$PACKAGES_DIR" -type f -name "*${SEARCH_VERSION}*${ARCH}*" 2>/dev/null)

	if [ -z "$file_list" ]; then
		echo "❌ 未找到包含版本 ${SEARCH_VERSION} 的文件"
		exit 1
	fi

	file_count=$(echo "$file_list" | wc -l)
	echo "✅ 找到 ${file_count} 个文件"
	echo "-----------------------------------------"

	# 先打印所有文件列表
	echo "📋 文件列表:"
	echo "-----------------------------------------"
	echo "$file_list" | while read -r file_path; do
		echo "  $(basename "$file_path")"
	done
	echo "-----------------------------------------"
	echo ""

	success=0
	fail=0

	while IFS= read -r file_path; do
		filename=$(basename "$file_path")
		download_url="${BASE_URL}${filename}"

		echo "📄 $filename"
		echo "🔗 $download_url"
		echo -n "⏳ 发送缓存请求... "

		echo "-> 开始缓存预热: $download_url"

		if curl -s -o /dev/null -w "%{http_code}" -I "$download_url" | grep -q "200\|206\|302"; then
			echo "✅ 缓存成功"
			((success++))
		else
			echo "❌ 失败"
			((fail++))
		fi

	done <<<"$file_list"

	echo ""
	echo "========================================="
	echo "完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
	echo "成功: $success  失败: $fail  总计: $file_count"
	echo "========================================="
}

install() {
	local versionType="${1:-android}"
	OUT_DIR="$DIR/out/packages"

	if [ "$versionType" = "byd" ]; then
		echo "📱 比亚迪车机版本安装命令:"
		echo "adb install $DIR/out/byd_packages/$name-byd-$version.${currentTime}-arm64-v8a.apk"
	elif [ "$versionType" = "test" ]; then
		echo "📱 测试版本安装命令:"
		echo "adb install $DIR/out/test_packages/$name-test-$version.${currentTime}-arm64-v8a.apk"
	else
		echo "📱 普通安卓版本安装命令:"
		echo "adb install $OUT_DIR/$name-$version.${currentTime}-arm64-v8a.apk"
	fi
}

install:test() {
	OUT_DIR="$DIR/out/packages"
	echo "📱 测试版本安装命令:"
	echo "adb install $OUT_DIR/$name-test-$version.${currentTime}-arm64-v8a.apk"
}

# 解析命令行参数（设置全局版本号）
parseVersionArgs() {
	local args=("$@")
	for ((i = 0; i < ${#args[@]}; i++)); do
		case "${args[$i]}" in
		-v | --version)
			if [ $((i + 1)) -lt ${#args[@]} ]; then
				export CMD_VERSION="${args[$((i + 1))]}"
				i=$((i + 1))
			fi
			;;
		esac
	done
}

# ./release.sh deleteRelease v1.0.25
# 删除远端公开库的 Release
# 支持：
# 1. 指定版本：./release.sh deleteRelease 1.0.24
# 2. 留空（自动读取脚本全局 version 变量）：./release.sh deleteRelease
deleteRelease() {
	# 优先拿命令行传入的 $1，如果为空则对接自带的 $version 变量
	local input_version="${1:-$version}"

	if [ -z "$input_version" ]; then
		echo "❌ 错误：未检测到任何版本号。"
		echo "请在脚本头部定义 version 变量，或在命令行中指定，例如：./release.sh deleteRelease 1.0.24"
		return 1
	fi

	local RELEASE_TAG="$input_version"

	# 🎯 智能判断：如果版本号不包含前缀，默认补上当前脚本的 PREFIX ("app-v")
	if [[ ! "$input_version" =~ ^(web-v|app-v) ]]; then
		local clean_ver="${input_version#v}"
		RELEASE_TAG="${PREFIX}${clean_ver}"
	fi

	echo "-> 正在从公开库 [$TARGET_REPO] 删除 Release 及 Tag: $RELEASE_TAG"

	# 连带远端 Tag 一起彻底干净抹除
	if ! gh release delete "$RELEASE_TAG" -R "$TARGET_REPO" --cleanup-tag -y; then
		echo "❌ 删除 GitHub Release 失败，请检查该 Release 是否存在"
		return 1
	fi

	echo "✅ Release $RELEASE_TAG 及其远程 Tag 已成功斩杀!"
}

# 发布到 GitHub Release
# ./release.sh release -v v1.0.25
release() {
	# 解析版本号参数
	parseVersionArgs "$@"

	# 如果指定了版本号，使用指定的版本；否则使用脚本中定义的版本号
	if [ -n "$CMD_VERSION" ]; then
		CLEAN_VERSION="$CMD_VERSION"
		echo "📌 使用命令行指定版本: $CLEAN_VERSION"
	else
		CLEAN_VERSION="$version"
		echo "📌 使用脚本中定义的版本号: $CLEAN_VERSION"
	fi

	# 规整版本号，去掉可能多输入的 'v'
	CLEAN_VERSION="${CLEAN_VERSION#v}"

	# 🎯 拼装 App 轨道的专属 Tag (如 app-v1.0.24)
	RELEASE_TAG="${PREFIX}${CLEAN_VERSION}"

	# 检查 packages 目录是否存在
	PACKAGES_DIR="$DIR/out/packages"
	if [ ! -d "$PACKAGES_DIR" ]; then
		echo "❌ 错误：$PACKAGES_DIR 目录不存在"
		echo "请先运行 ./release.sh build:all 或 ./release.sh build 生成产物"
		return 1
	fi

	# 🎯 查找指定版本的 APK 文件 (用规整后的 CLEAN_VERSION 匹配文件名)
	APK_FILES=("$PACKAGES_DIR"/*"$CLEAN_VERSION"*"arm64-v8a"*.apk)

	# 检查是否找到 APK 文件
	if [ ! -f "${APK_FILES[0]}" ]; then
		echo "❌ 错误：未找到版本 $CLEAN_VERSION 的 APK 文件"
		echo "请确保已使用版本 $CLEAN_VERSION 打包"
		return 1
	fi

	# 列出将要上传的文件
	echo "📦 将要上传的 APK 文件:"
	for apk in "${APK_FILES[@]}"; do
		if [ -f "$apk" ]; then
			echo "   $(basename "$apk")"
		fi
	done

	# 🎯 跨仓库检查 GitHub Release 是否已存在
	if gh release view "$RELEASE_TAG" -R "$TARGET_REPO" &>/dev/null; then
		echo -n "❓ 跨仓库 Release $RELEASE_TAG 已存在，是否覆盖? [y/N]: "
		read confirm
		if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
			echo "✓ 取消发布"
			return 0
		fi
		# 删除旧 Release
		echo "-> 正在从公开库删除旧 Release: $RELEASE_TAG"
		if ! gh release delete "$RELEASE_TAG" -R "$TARGET_REPO" -y; then
			echo "❌ 删除旧 Release 失败"
			return 1
		fi
	fi

	# 创建 GitHub Release
	echo "-> 创建 GitHub Release: $RELEASE_VERSION"

	# 使用数组存储要上传的文件（正确处理路径中的空格）
	local -a upload_files=()
	for apk in "${APK_FILES[@]}"; do
		if [ -f "$apk" ]; then
			upload_files+=("$apk")
		fi
	done

	# 获取更新说明（使用最新的 git commit 信息）
	local latest_commit_short=$(git log -1 --oneline)
	local latest_commit_msg=$(git log -1 --format=%B | head -n 1) # 获取第一行完整提交信息
	local commit_date=$(git log -1 --format=%ad --date=short)
	local commit_author=$(git log -1 --format=%an)

	# 获取最近5个commit的简短信息
	local recent_commits=""
	local commit_count=0
	while IFS= read -r line && [ $commit_count -lt 5 ]; do
		if [ -n "$line" ]; then
			recent_commits="${recent_commits}- ${line}\n"
			commit_count=$((commit_count + 1))
		fi
	done < <(git log --oneline -5)

	# 🎯 规范体面的 App 专属发布日志，干掉私有 commit 暴露隐患
	local commit_date=$(date +"%Y-%m-%d")
	local notes="## 📱 App Release | 自驾路书客户端发布

### 🏷️ 客户端版本: v$CLEAN_VERSION
**📅 发布日期:** $commit_date

### ⚙️ 包含架构与平台适配
- **支持架构:** arm64-v8a
- **优化重点:** 优化车机本地 WebView 渲染性能与 Navigator Agent 语音通信底座

---
*💡 本仓库为官方 Release 资产分发专区。源码已通过独立私有库安全隔离。*"

	# 🎯 一键创建并流式上传到公开主库
	echo "-> 正在向公开库 [$TARGET_REPO] 创建并发布 Release: $RELEASE_TAG"

	# 🎯 1. 先创建空的 Release 壳子
	echo "-> 正在创建 GitHub Release: $RELEASE_TAG ..."
	if ! gh release create "$RELEASE_TAG" \
		-R "$TARGET_REPO" \
		--title "App Release v$CLEAN_VERSION" \
		--notes "$notes"; then
		echo "❌ 创建 GitHub Release 失败"
		return 1
	fi

	# 🎯 2. 逐个文件流式上传，并强制 gh 吐出原始进度条
	echo "-> 正在流式上传 APK 文件..."
	for apk in "${upload_files[@]}"; do
		if [ -f "$apk" ]; then
			local filename=$(basename "$apk")
			local filesize=$(du -h "$apk" | cut -f1)

			echo "  📤 正在上传: $filename ($filesize)"

			# 💡 诀窍：gh release upload 如果直接运行，在某些终端会隐藏进度。
			# 加上 --clobber（覆盖）并确保标准错误（进度条所在的流）不被拦截
			if ! gh release upload "$RELEASE_TAG" "$apk" -R "$TARGET_REPO" --clobber; then
				echo "❌ 上传 $filename 失败"
				return 1
			fi
			echo "  ✅ 上传完成: $filename"
		fi
	done

	echo ""
	echo "✅ Release $RELEASE_TAG 发布成功!"
	echo "🔗 公开下载地址: https://github.com/$TARGET_REPO/releases/tag/$RELEASE_TAG"
}

main() {
	if echo "${allowMethods[@]}" | grep -wq "$1"; then
		"$@"
	else
		echo "Invalid command: $1"
	fi
}

main "$@"
