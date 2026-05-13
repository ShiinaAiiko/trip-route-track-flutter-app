#! /bin/bash
# sshFilePath="../../../../ssh/101.132.144.52-ssh.json"
DIR=$(cd $(dirname $0) && pwd)
allowMethods=("run")

host=$BUILD_SERVER_HOST
user=$BUILD_SERVER_USER
password=$BUILD_SERVER_PASSWORD
projectPath=$BUILD_SERVER_PROJECT_ROOTP_PATH

run() {
	echo "-> 正在传输 APK 文件至服务器"

	# 先在服务器上创建目录
	sshpass -p $password ssh "$user@$host" "mkdir -p $projectPath/nyanya-trip-route-track/trip-route-track-flutter-app/out/packages"

	# 同步文件
	sshpass -p $password \
		rsync -avz --delete \
		--include="*arm64-v8a*" \
		--include="*/" \
		--exclude="*" \
		"$DIR/out/packages/" "$user@$host:$projectPath/nyanya-trip-route-track/trip-route-track-flutter-app/out/packages/"
	echo "-> 传输完毕"

}

main() {
	if echo "${allowMethods[@]}" | grep -wq "$1"; then
		"$1"
	else
		echo "Invalid command: $1"
	fi
}

main "$1"
