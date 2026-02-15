FROM ubuntu:24.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV VNC_PORT=5901
ENV NOVNC_PORT=6080

# 安装基础工具
RUN apt-get update && apt-get install -y \
    wget curl git vim \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# 安装虚拟显示和VNC
RUN apt-get update && apt-get install -y \
    xvfb \
    x11vnc \
    tigervnc-standalone-server \
    tigervnc-common \
    novnc \
    websockify \
    && rm -rf /var/lib/apt/lists/*

# 安装Qt和QML运行时
RUN apt-get update && apt-get install -y \
    qt6-base-dev \
    qt6-declarative-dev \
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtquick-window \
    libqt6multimedia6 \
    libqt6multimediawidgets6 \
    && rm -rf /var/lib/apt/lists/*

# 安装应用依赖
RUN apt-get update && apt-get install -y \
    libmosquitto1 \
    libmosquitto-dev \
    libasound2 \
    libpulse0 \
    && rm -rf /var/lib/apt/lists/*

# 创建工作目录
WORKDIR /app

# 创建VNC密码文件
RUN mkdir -p ~/.vnc && \
    x11vnc -storepasswd 123456 ~/.vnc/passwd

# 创建supervisor配置目录
RUN mkdir -p /etc/supervisor/conf.d

# 暴露端口
EXPOSE 5901 6080

# 启动脚本将在运行时挂载
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
