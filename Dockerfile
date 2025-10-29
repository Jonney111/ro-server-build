# =========================
# Stage 1: Build
# =========================
FROM debian:11-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV RATHENA_DIR=/opt/rAthena
# 定义版本参数
ARG VER=20221116
ENV VER=$VER

# 编译依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    git make gcc g++ pkg-config \
    libmariadb-dev libmariadbclient-dev-compat \
    zlib1g-dev libpcre3-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 克隆源码
RUN git clone --depth=1 https://github.com/rathena/rathena.git $RATHENA_DIR
WORKDIR $RATHENA_DIR

# 编译
RUN ./configure --enable-packetver=$VER \
                --enable-packetver-zero \
                && make clean \
                && make server 

# 备份运行所需文件
RUN mkdir -p /opt/rAthena/default_conf && \
    cp -r conf /opt/rAthena/default_conf && \
    cp -r db   /opt/rAthena/default_conf/db
# =========================
# Stage 2: Runtime
# =========================
FROM debian:11-slim
ENV RATHENA_DIR=/opt/rAthena
WORKDIR $RATHENA_DIR

# 运行依赖 + tini + screen
RUN apt-get update && apt-get install -y --no-install-recommends \
    libmariadb3 zlib1g libpcre3 \
    ca-certificates tini netcat \
    && rm -rf /var/lib/apt/lists/*

# 只复制编译产物
COPY --from=builder $RATHENA_DIR/char-server $RATHENA_DIR/
COPY --from=builder $RATHENA_DIR/login-server $RATHENA_DIR/
COPY --from=builder $RATHENA_DIR/map-server $RATHENA_DIR/
COPY --from=builder $RATHENA_DIR/web-server $RATHENA_DIR/

# 复制运行所需资源
COPY --from=builder $RATHENA_DIR/conf $RATHENA_DIR/conf
COPY --from=builder $RATHENA_DIR/db $RATHENA_DIR/db
COPY --from=builder $RATHENA_DIR/default_conf $RATHENA_DIR/default_conf
COPY --from=builder $RATHENA_DIR/npc $RATHENA_DIR/npc
COPY --from=builder $RATHENA_DIR/sql-files $RATHENA_DIR/sql-files

# 复制entrypoint
COPY entrypoint.sh /tmp/entrypoint.sh
RUN chmod +x /tmp/entrypoint.sh

# 使用 tini 作为 init 进程
ENTRYPOINT ["/usr/bin/tini", "--", "/tmp/entrypoint.sh"]

# 暴露端口
EXPOSE 6900 5120 5121 5122
