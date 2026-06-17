#! /bin/bash
name="trip-route-track"
runName="$name-flutter-app"
port=23204
branch="main"
version="v1.0.25"
# configFilePath="config.dev.json"
configFilePath="config.pro.json"
DIR=$(cd $(dirname $0) && pwd)
allowMethods=("build:all addVersion build:new build:old build:byd install adb dev run stop protos start build buildDev setVersion profile profileDev release")

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
	loadEnv
	setGoogleClientId "prod"
	_build "prod" "standard"

	# 打包比亚迪版本
	# echo "-> 开始打包比亚迪车机版本 Android APK"
	# _build "prod" "byd"
}

build:all(){
	build
	build:byd

	release
}

build:byd() {
	echo "-> 开始单独打包比亚迪车机版本 Android APK"
	loadEnv
	setGoogleClientId "prod"
	_build "prod" "byd"
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
	versionType="${2:-standard}" # 默认值为 standard
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
	if [ "$versionType" = "standard" ]; then
		setVersion
	fi

	flutter build apk --release --flavor "$flavor" --split-per-abi --no-shrink

	# 检查构建是否成功
	if [ $? -ne 0 ]; then
		echo "❌ flutter build 失败，停止执行"
		exit 1
	fi

	# 只有 build 成功才会执行到这里
	echo "✅ flutter build 成功，继续执行..."

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
				new_name="$name-dev-$version-$arch.apk"
			elif [ "$versionType" == "byd" ]; then
				new_name="$name-byd-$version-$arch.apk"
			else
				new_name="$name-$version-$arch.apk"
			fi
			cp "$apk" "$OUT_DIR/$new_name"
			cp "$apk" "$PACKAGES_DIR/$new_name"
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

	# 在 WSL2 终端输入
	# 加上 -Force 确保覆盖
	# 只有生产包才上传到服务器
	if [ "$flavor" == "prod" ]; then
		# 上传到服务器（只有标准版本上传）
		echo "-> 开始上传到服务器..."
		"$DIR/ssh.sh" run
	fi

}

install() {
	local versionType="${1:-standard}"
	OUT_DIR="$DIR/out/packages"

	if [ "$versionType" = "byd" ]; then
		echo "📱 比亚迪车机版本安装命令:"
		echo "adb install $OUT_DIR/$name-byd-$version-arm64-v8a.apk"
	else
		echo "📱 普通安卓版本安装命令:"
		echo "adb install $OUT_DIR/$name-$version-arm64-v8a.apk"
	fi
}

# 解析命令行参数（设置全局版本号）
parseVersionArgs() {
  local args=("$@")
  for ((i=0; i<${#args[@]}; i++)); do
    case "${args[$i]}" in
      -v|--version)
        if [ $((i+1)) -lt ${#args[@]} ]; then
          export CMD_VERSION="${args[$((i+1))]}"
          i=$((i+1))
        fi
        ;;
    esac
  done
}

# 发布到 GitHub Release
release() {
  # 解析版本号参数
  parseVersionArgs "$@"
  
  # 如果指定了版本号，使用指定的版本；否则使用脚本中定义的版本号
  if [ -n "$CMD_VERSION" ]; then
    RELEASE_VERSION="$CMD_VERSION"
    echo "📌 使用命令行指定版本: $RELEASE_VERSION"
  else
    RELEASE_VERSION="$version"
    echo "📌 使用脚本中定义的版本号: $RELEASE_VERSION"
  fi
  
  # 检查 packages 目录是否存在
  PACKAGES_DIR="$DIR/out/packages"
  if [ ! -d "$PACKAGES_DIR" ]; then
    echo "❌ 错误：$PACKAGES_DIR 目录不存在"
    echo "请先运行 ./release.sh build:all 或 ./release.sh build 生成产物"
    return 1
  fi
  
  # 查找指定版本的 APK 文件
  APK_FILES=("$PACKAGES_DIR"/*"$RELEASE_VERSION"*.apk)
  
  # 检查是否找到 APK 文件
  if [ ! -f "${APK_FILES[0]}" ]; then
    echo "❌ 错误：未找到版本 $RELEASE_VERSION 的 APK 文件"
    echo "请确保已使用版本 $RELEASE_VERSION 打包"
    return 1
  fi
  
  # 列出将要上传的文件
  echo "📦 将要上传的 APK 文件:"
  for apk in "${APK_FILES[@]}"; do
    if [ -f "$apk" ]; then
      echo "   $(basename "$apk")"
    fi
  done
  
  # 检查 GitHub Release 是否已存在
  if gh release view "$RELEASE_VERSION" &>/dev/null; then
    echo -n "❓ GitHub Release $RELEASE_VERSION 已存在，是否覆盖? [y/N]: "
    read confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "✓ 取消发布"
      return 0
    fi
    # 删除旧 Release
    echo "-> 删除旧 Release: $RELEASE_VERSION"
    if ! gh release delete "$RELEASE_VERSION" -y; then
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
  local latest_commit=$(git log -1 --oneline)
  local commit_date=$(git log -1 --format=%ad --date=short)
  local commit_author=$(git log -1 --format=%an)
  
  local notes="## 更新内容

### 版本 $RELEASE_VERSION

**最新提交:**
- $latest_commit
- 作者: $commit_author
- 日期: $commit_date

**包含架构:**
- armeabi-v7a
- arm64-v8a  
- x86_64"
  
  # 创建 Release（使用数组展开）
  if ! gh release create "$RELEASE_VERSION" \
    --title "Version $RELEASE_VERSION" \
    --notes "$notes" \
    "${upload_files[@]}"; then
    echo "❌ 创建 GitHub Release 失败"
    return 1
  fi
  
  echo ""
  echo "✅ Release $RELEASE_VERSION 发布成功!"
  echo "🔗 Release 地址: https://github.com/your-repo/releases/tag/$RELEASE_VERSION"
}

main() {
	if echo "${allowMethods[@]}" | grep -wq "$1"; then
		"$@"
	else
		echo "Invalid command: $1"
	fi
}

main "$@"
