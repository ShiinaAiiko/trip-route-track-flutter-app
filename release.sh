#! /bin/bash
name="trip-route-track"
runName="$name-flutter-app"
port=23204
branch="main"
version="v1.0.2"
# configFilePath="config.dev.json"
configFilePath="config.pro.json"
DIR=$(cd $(dirname $0) && pwd)
allowMethods=("adb dev run stop protos start build buildDev setVersion")

dev() {
	# adb logcat | grep "GeckoViewPlatform\|gps1"
	# adb logcat | grep "message.type\|gps12"
	# 更新 assets 目录配置
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

setVersion() {
	echo "-> 设置 App 版本为 $version"
	versionName=$(echo $version | sed 's/v//')
	versionCode=$(date +%s | cut -c 7-10)

	cd $DIR
	# 更新 pubspec.yaml
	sed -i "s/version: .*/version: $versionName+$versionCode/" pubspec.yaml
	# 更新 local.properties
	if [ ! -f $DIR/android/local.properties ]; then
		echo "sdk.dir=\$(dirname \$(which flutter))/cache/artifacts/engine/android-arm64" >$DIR/android/local.properties
	fi
	sed -i "/flutter.versionName=/d" $DIR/android/local.properties
	sed -i "/flutter.versionCode=/d" $DIR/android/local.properties
	echo "flutter.versionName=$versionName" >>$DIR/android/local.properties
	echo "flutter.versionCode=$versionCode" >>$DIR/android/local.properties
}

build() {
	echo "-> 开始打包生产环境 Android APK"
	_build "prod"
}

buildDev() {
	echo "-> 开始打包开发环境 Android APK"
	_build "dev"
}

_build() {
	flavor="$1"
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

	setVersion
	flutter build apk --release --flavor "$flavor" --split-per-abi --no-shrink

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
				new_name="$name-$version-dev-$arch.apk"
			else
				new_name="$name-$version-$arch.apk"
			fi
			cp "$apk" "$OUT_DIR/$new_name"
			cp "$apk" "$PACKAGES_DIR/$new_name"
			echo "   $new_name"
		fi
	done

	echo "-> 打包完成！新 APK 文件已整理至：$OUT_DIR"
	ls -la "$OUT_DIR"

	# 只有生产包才上传到服务器
	if [ "$flavor" == "prod" ]; then
		# 上传到服务器
		echo "-> 开始上传到服务器..."
		"$DIR/ssh.sh" run
	fi

	adb install $OUT_DIR/$name-$version-arm64-v8a.apk
}

main() {
	if echo "${allowMethods[@]}" | grep -wq "$1"; then
		"$1"
	else
		echo "Invalid command: $1"
	fi
}

main "$1"
