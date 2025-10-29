#!/bin/bash
set -e

DEFAULT_CONF="/opt/rAthena/default_conf/conf"
DEFAULT_DB="/opt/rAthena/default_conf/db"
TARGET_CONF="/opt/rAthena/conf"
TARGET_DB="/opt/rAthena/db"
RATHENA_DIR="/opt/rAthena"

# 自定义数据库参数，可通过环境变量传入
DB_IP=${DB_IP:-127.0.0.1}
DB_PORT=${DB_PORT:-3306}
DB_USER=${DB_USER:-ragnarok}
DB_PASS=${DB_PASS:-ragnarok}
DB_NAME=${DB_NAME:-ragnarok}

# 如果挂载的 conf 目录为空，则复制默认配置
if [ -d "$TARGET_CONF" ] && [ -z "$(ls -A "$TARGET_CONF")" ]; then
    echo "📂 检测到挂载的 conf 目录为空，正在复制默认配置..."
    cp -r "$DEFAULT_CONF"/* "$TARGET_CONF"/

    INTER_CONF="$TARGET_CONF/inter_athena.conf"

    # 循环替换 login/char/map/web
    for server in login char map web; do
        sed -i "s#${server}_server_ip:.*#${server}_server_ip: $DB_IP#" "$INTER_CONF"
        sed -i "s#${server}_server_port:.*#${server}_server_port: $DB_PORT#" "$INTER_CONF"
        sed -i "s#${server}_server_id:.*#${server}_server_id: $DB_USER#" "$INTER_CONF"
        sed -i "s#${server}_server_pw:.*#${server}_server_pw: $DB_PASS#" "$INTER_CONF"
        sed -i "s#${server}_server_db:.*#${server}_server_db: $DB_NAME#" "$INTER_CONF"
    done

    # 单独处理 ipban_db 和 log_db
    for db in ipban log; do
        sed -i "s#${db}_db_ip:.*#${db}_db_ip: $DB_IP#" "$INTER_CONF"
        sed -i "s#${db}_db_port:.*#${db}_db_port: $DB_PORT#" "$INTER_CONF"
        sed -i "s#${db}_db_id:.*#${db}_db_id: $DB_USER#" "$INTER_CONF"
        sed -i "s#${db}_db_pw:.*#${db}_db_pw: $DB_PASS#" "$INTER_CONF"
        sed -i "s#${db}_db_db:.*#${db}_db_db: $DB_NAME#" "$INTER_CONF"
    done

    echo "✅ 已复制默认配置并修改所有数据库信息到挂载目录。"
else
    echo "ℹ️ conf 目录已存在内容，跳过复制。"
fi

# 如果挂载的 db 目录为空，则复制默认数据库配置
if [ -d "$TARGET_DB" ] && [ -z "$(ls -A "$TARGET_DB")" ]; then
    echo "📂 检测到挂载的 db 目录为空，正在复制默认数据库配置..."
    cp -r "$DEFAULT_DB"/* "$TARGET_DB"/
    echo "✅ 已复制默认 db 到挂载目录。"
else
    echo "ℹ️ db 目录已存在内容，跳过复制。"
fi

# 删除 default_conf
if [ -d "/opt/rAthena/default_conf" ]; then
    #echo "🗑️ 删除 default_conf 文件夹..."
    rm -rf /opt/rAthena/default_conf
    #echo "✅ 已删除 default_conf。"
fi

# 删除default_conf
# rm -f "$0"

echo "🚀 启动 (screen 前台激活)..."
start_service() {
    local name=$1
    local cmd=$2
    local port=$3

    echo "🚀 启动 $name..."
    "$RATHENA_DIR/$cmd" &

    # 等待端口就绪
    echo "⏳ 等待 $name 端口 $port 就绪..."
    while ! nc -z 127.0.0.1 $port; do
        sleep 1
    done
    echo "✅ $name 端口 $port 已就绪。"
}

# -----------------------------
# 启动四服务
# -----------------------------
start_service "login-server" "./login-server" 6900
start_service "char-server"  "./char-server" 6121
start_service "map-server"   "./map-server" 5121
start_service "web-server"   "./web-server" 5122

echo "✅ 所有 rAthena 服务已启动。"
echo "📢 使用 'docker logs -f <container>' 查看输出。"
tail -f /dev/null
