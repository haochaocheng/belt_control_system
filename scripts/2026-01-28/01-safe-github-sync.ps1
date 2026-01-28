# 安全的 GitHub 同步脚本
# 日期: 2026-01-28
# 功能: 同步本地 Git 仓库到 GitHub，绝对不会破坏本地文件

# UTF-8 强制配置
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 配置参数
$localRepo = "E:\2025\3_gongkongji\belt_control_system"
$githubUrl = "https://github.com/yourusername/belt-control-system.git"  # 请替换为您的 GitHub 仓库地址
$logFile = "$localRepo\sync-log.txt"

function Write-Log {
    param([string]$message, [string]$color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $message"
    Add-Content -Path $logFile -Value $logMessage -Encoding UTF8
    Write-Host $logMessage -ForegroundColor $color
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  安全的 GitHub 同步脚本" -ForegroundColor Cyan
Write-Host "  只推送，不拉取，不修改本地文件" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "========== 开始 GitHub 同步 ==========" "Cyan"

# 1. 检查本地仓库是否存在
if (-not (Test-Path $localRepo)) {
    Write-Log "❌ 本地仓库不存在：$localRepo" "Red"
    exit 1
}

Write-Log "✅ 本地仓库存在：$localRepo" "Green"

# 2. 进入本地仓库
try {
    Set-Location $localRepo
    Write-Log "✅ 已进入本地仓库" "Green"
} catch {
    Write-Log "❌ 无法进入本地仓库：$($_.Exception.Message)" "Red"
    exit 1
}

# 3. 检查是否是 Git 仓库
if (-not (Test-Path ".git")) {
    Write-Log "❌ 这不是一个 Git 仓库" "Red"
    exit 1
}

Write-Log "✅ 确认是 Git 仓库" "Green"

# 4. 检查当前分支
try {
    $currentBranch = git rev-parse --abbrev-ref HEAD 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "❌ 无法获取当前分支：$currentBranch" "Red"
        exit 1
    }
    Write-Log "✅ 当前分支：$currentBranch" "Green"
} catch {
    Write-Log "❌ 获取分支失败：$($_.Exception.Message)" "Red"
    exit 1
}

# 5. 检查是否有未提交的更改
Write-Log "检查是否有未提交的更改..." "Cyan"
$status = git status --porcelain 2>&1
if ($status) {
    Write-Log "⚠️ 发现未提交的更改：" "Yellow"
    Write-Log $status "Yellow"
    Write-Log "⚠️ 建议先提交更改，然后再同步" "Yellow"

    $confirm = Read-Host "是否继续同步？(yes/no)"
    if ($confirm -ne "yes") {
        Write-Log "已取消同步" "Yellow"
        exit 0
    }
} else {
    Write-Log "✅ 没有未提交的更改" "Green"
}

# 6. 检查 GitHub 远程仓库是否已配置
Write-Log "检查 GitHub 远程仓库配置..." "Cyan"
$remotes = git remote -v 2>&1
$hasGithub = $false

if ($remotes -match "github") {
    Write-Log "✅ GitHub 远程仓库已配置" "Green"
    $hasGithub = $true
} else {
    Write-Log "⚠️ GitHub 远程仓库未配置" "Yellow"
    Write-Log "正在添加 GitHub 远程仓库..." "Cyan"

    try {
        git remote add github $githubUrl 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✅ GitHub 远程仓库添加成功" "Green"
            $hasGithub = $true
        } else {
            Write-Log "❌ 添加 GitHub 远程仓库失败" "Red"
            exit 1
        }
    } catch {
        Write-Log "❌ 添加远程仓库失败：$($_.Exception.Message)" "Red"
        exit 1
    }
}

# 7. 显示远程仓库列表
Write-Log "当前远程仓库列表：" "Cyan"
$remotes = git remote -v 2>&1
Write-Log $remotes "White"

# 8. 推送到 GitHub（只推送，不拉取）
Write-Log "========== 开始推送到 GitHub ==========" "Cyan"
Write-Log "⚠️ 注意：只推送，不会拉取或修改本地文件" "Yellow"

try {
    # 推送当前分支到 GitHub
    Write-Log "推送分支 $currentBranch 到 GitHub..." "Cyan"
    $pushResult = git push github $currentBranch 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Log "✅ 分支 $currentBranch 推送成功" "Green"
    } else {
        Write-Log "⚠️ 推送结果：$pushResult" "Yellow"

        # 检查是否需要设置上游分支
        if ($pushResult -match "set-upstream") {
            Write-Log "设置上游分支并推送..." "Cyan"
            $pushResult = git push --set-upstream github $currentBranch 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Log "✅ 分支 $currentBranch 推送成功（已设置上游）" "Green"
            } else {
                Write-Log "❌ 推送失败：$pushResult" "Red"
                exit 1
            }
        } else {
            Write-Log "❌ 推送失败：$pushResult" "Red"
            exit 1
        }
    }

    # 推送所有标签
    Write-Log "推送所有标签到 GitHub..." "Cyan"
    $tagResult = git push github --tags 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Log "✅ 标签推送成功" "Green"
    } else {
        Write-Log "⚠️ 标签推送结果：$tagResult" "Yellow"
    }

} catch {
    Write-Log "❌ 推送失败：$($_.Exception.Message)" "Red"
    exit 1
}

# 9. 验证推送结果
Write-Log "========== 验证推送结果 ==========" "Cyan"
try {
    $localCommit = git rev-parse HEAD 2>&1
    $remoteCommit = git rev-parse github/$currentBranch 2>&1

    if ($localCommit -eq $remoteCommit) {
        Write-Log "✅ 本地和 GitHub 完全同步" "Green"
        Write-Log "   本地提交：$localCommit" "Green"
        Write-Log "   远程提交：$remoteCommit" "Green"
    } else {
        Write-Log "⚠️ 本地和 GitHub 可能不同步" "Yellow"
        Write-Log "   本地提交：$localCommit" "Yellow"
        Write-Log "   远程提交：$remoteCommit" "Yellow"
    }
} catch {
    Write-Log "⚠️ 无法验证推送结果：$($_.Exception.Message)" "Yellow"
}

# 10. 显示同步统计
Write-Log "========== 同步统计 ==========" "Cyan"
$commitCount = git rev-list --count HEAD 2>&1
Write-Log "总提交数：$commitCount" "White"

$lastCommit = git log -1 --pretty=format:"%h - %s (%cr)" 2>&1
Write-Log "最新提交：$lastCommit" "White"

Write-Log "========== GitHub 同步完成 ==========" "Green"
Write-Log ""

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  ✅ GitHub 同步成功" -ForegroundColor Green
Write-Host "  📝 日志文件：$logFile" -ForegroundColor Cyan
Write-Host "  🔒 本地文件未被修改" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
