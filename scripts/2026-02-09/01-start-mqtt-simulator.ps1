# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=" -NoNewline -ForegroundColor Cyan
Write-Host ("=" * 59) -ForegroundColor Cyan
Write-Host "🚀 MQTT 模块自动模拟器 - 启动脚本" -ForegroundColor Green
Write-Host "=" -NoNewline -ForegroundColor Cyan
Write-Host ("=" * 59) -ForegroundColor Cyan
Write-Host ""

# 检查 Python 是否安装
Write-Host "🔍 检查 Python 环境..." -ForegroundColor Yellow
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    Write-Host "❌ 未找到 Python，请先安装 Python 3.x" -ForegroundColor Red
    Write-Host "   下载地址: https://www.python.org/downloads/" -ForegroundColor Yellow
    exit 1
}

$pythonVersion = python --version 2>&1
Write-Host "✅ Python 版本: $pythonVersion" -ForegroundColor Green

# 检查 paho-mqtt 是否安装
Write-Host "`n🔍 检查 paho-mqtt 库..." -ForegroundColor Yellow
$pahoCheck = python -c "import paho.mqtt.client; print('installed')" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "📦 安装 paho-mqtt 库..." -ForegroundColor Yellow
    pip install paho-mqtt
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ 安装 paho-mqtt 失败" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ paho-mqtt 安装成功" -ForegroundColor Green
} else {
    Write-Host "✅ paho-mqtt 已安装" -ForegroundColor Green
}

# 检查配置文件是否存在
$configFile = "config/mqtt_modules.json"
Write-Host "`n🔍 检查配置文件..." -ForegroundColor Yellow

if (-not (Test-Path $configFile)) {
    Write-Host "⚠️  配置文件不存在: $configFile" -ForegroundColor Yellow
    Write-Host "📝 创建默认配置文件..." -ForegroundColor Yellow

    # 创建配置目录
    New-Item -ItemType Directory -Force -Path "config" | Out-Null

    # 创建默认配置
    $defaultConfig = @{
        modules = @(
            @{
                index = 0
                name = "开关量输入1"
                type = "di"
                enabled = $true
                broker = @{
                    host = "192.168.10.142"
                    port = 1883
                    clientId = "belt_control_di1"
                }
                topics = @{
                    control = "belt_control/di/module1/control"
                    status = "belt_control/di/module1/status"
                    heartbeat = "belt_control/heartbeat/module1"
                }
                polling = @{
                    enabled = $true
                    interval = 100
                }
            },
            @{
                index = 1
                name = "开关量输入2"
                type = "di"
                enabled = $true
                broker = @{
                    host = "192.168.10.142"
                    port = 1883
                    clientId = "belt_control_di2"
                }
                topics = @{
                    control = "belt_control/di/module2/control"
                    status = "belt_control/di/module2/status"
                    heartbeat = "belt_control/heartbeat/module2"
                }
                polling = @{
                    enabled = $true
                    interval = 100
                }
            },
            @{
                index = 2
                name = "模拟量输入1"
                type = "ai"
                enabled = $true
                broker = @{
                    host = "192.168.10.142"
                    port = 1883
                    clientId = "belt_control_ai1"
                }
                topics = @{
                    control = "belt_control/ai/module3/control"
                    status = "belt_control/ai/module3/status"
                    heartbeat = "belt_control/heartbeat/module3"
                }
                polling = @{
                    enabled = $true
                    interval = 500
                }
                channels = @{
                    count = 8
                    changeThreshold = 10
                }
            },
            @{
                index = 3
                name = "模拟量输入2"
                type = "ai"
                enabled = $true
                broker = @{
                    host = "192.168.10.142"
                    port = 1883
                    clientId = "belt_control_ai2"
                }
                topics = @{
                    control = "belt_control/ai/module4/control"
                    status = "belt_control/ai/module4/status"
                    heartbeat = "belt_control/heartbeat/module4"
                }
                polling = @{
                    enabled = $true
                    interval = 500
                }
                channels = @{
                    count = 8
                    changeThreshold = 10
                }
            },
            @{
                index = 4
                name = "CS1"
                type = "cs"
                enabled = $true
                broker = @{
                    host = "192.168.10.142"
                    port = 1883
                    clientId = "belt_control_cs1"
                }
                topics = @{
                    control = "belt_control/cs/module5/control"
                    status = "belt_control/cs/module5/status"
                    heartbeat = "belt_control/heartbeat/module5"
                }
                polling = @{
                    enabled = $true
                    interval = 1000
                }
            },
            @{
                index = 5
                name = "CS2"
                type = "cs"
                enabled = $true
                broker = @{
                    host = "192.168.10.142"
                    port = 1883
                    clientId = "belt_control_cs2"
                }
                topics = @{
                    control = "belt_control/cs/module6/control"
                    status = "belt_control/cs/module6/status"
                    heartbeat = "belt_control/heartbeat/module6"
                }
                polling = @{
                    enabled = $true
                    interval = 1000
                }
            },
            @{
                index = 6
                name = "语音模块"
                type = "voice"
                enabled = $true
                broker = @{
                    host = "192.168.10.142"
                    port = 1883
                    clientId = "belt_control_voice"
                }
                topics = @{
                    control = "belt_control/voice/module7/control"
                    status = "belt_control/voice/module7/status"
                    heartbeat = "belt_control/heartbeat/module7"
                }
                polling = @{
                    enabled = $true
                    interval = 5000
                }
            },
            @{
                index = 7
                name = "预留模块"
                type = "heartbeat"
                enabled = $true
                broker = @{
                    host = "192.168.10.142"
                    port = 1883
                    clientId = "belt_control_module8"
                }
                topics = @{
                    control = "belt_control/module8/control"
                    status = "belt_control/module8/status"
                    heartbeat = "belt_control/heartbeat/module8"
                }
                polling = @{
                    enabled = $true
                    interval = 5000
                }
            }
        )
        reconnect = @{
            enabled = $true
            checkInterval = 5000
            maxDelay = 30000
        }
        health = @{
            dataTimeout = 5000
            maxTimeoutCount = 3
        }
    }

    # 保存配置文件
    $defaultConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $configFile -Encoding UTF8
    Write-Host "✅ 配置文件创建成功: $configFile" -ForegroundColor Green
} else {
    Write-Host "✅ 配置文件已存在: $configFile" -ForegroundColor Green
}

# 检查 EMQX 是否运行
Write-Host "`n🔍 检查 EMQX Broker..." -ForegroundColor Yellow
$emqxRunning = docker ps --filter "name=emqx" --format "{{.Names}}" 2>$null
if ($emqxRunning -eq "emqx") {
    Write-Host "✅ EMQX Broker 正在运行" -ForegroundColor Green
} else {
    Write-Host "⚠️  EMQX Broker 未运行" -ForegroundColor Yellow
    Write-Host "   请先启动 EMQX: docker start emqx" -ForegroundColor Yellow
    Write-Host "   或者运行: docker run -d --name emqx -p 1883:1883 -p 8083:8083 -p 8084:8084 -p 8883:8883 -p 18083:18083 emqx/emqx:latest" -ForegroundColor Yellow

    $response = Read-Host "`n是否继续启动模拟器？(y/n)"
    if ($response -ne "y") {
        Write-Host "❌ 已取消启动" -ForegroundColor Red
        exit 1
    }
}

# 启动模拟器
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "🎯 启动 MQTT 模块模拟器..." -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

python scripts/2026-02-09/mqtt_simulator.py
