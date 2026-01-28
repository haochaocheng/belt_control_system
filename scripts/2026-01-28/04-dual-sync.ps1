# 双重同步脚本 - GitHub + GitLab
# 日期: 2026-01-28
# 功能: 同时推送到 GitHub 和本地 GitLab
# 优势: 网络断开时至少能推送到本地 GitLab

# UTF-8 强制配置
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 配置参数
$localRepo = "E:\2025\3_gongkongji\belt_control_system"
$githubRemote = "github"
$gitlabRemote = "gitlab"
$logFile = "$localRepo\dual-sync-log.txt"

function Write-Log {
    param([string]$message, [string]$color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $message"
    Add-Content -Path $logFile -Value $logMessage -Encoding UTF8
    Write-Host $logMessage -ForegroundColor $color
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  双重同步脚本 - GitHub + GitLab" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "========== 开始双重同步 ==========" "Cyan"

# 1. 检查本地仓库
if (-not (Test-Path $localRepo)) {
    Write-Log "❌ 本地仓库不存在：$localRepo" "Red"
    exit 1
}

Set-Location $localRepo
Write-Log "✅ 本地仓库：$localRepo" "Green"

# 2. 检查当前分支
try {
    $currentBranch = git rev-parse --abbrev-ref HEAD 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "❌ 无法获取当前分支" "Red"
        exit 1
    }
    Write-Log "✅ 当前分支：$currentBranch" "Green"
} catch {
    Write-Log "❌ 获取分支失败：$($_.Exception.Message)" "Red"
    exit 1
}

# 3. 检查未提交的更改
$status = git status --porcelain 2>&1
if ($status) {
    Write-Log "⚠️ 发现未提交的更改" "Yellow"
    Write-Log $status "Yellow"
}

# 4. 检查远程仓库配置
Write-Log "检查远程仓库配置..." "Cyan"
$remotes = git remote -v 2>&1

$hasGitHub = $remotes -match $githubRemote
$hasGitLab = $remotes -match $gitlabRemote

if (-not $hasGitHub) {
    Write-Log "⚠️ GitHub 远程仓库未配置" "Yellow"
}

if (-not $hasGitLab) {
    Write-Log "⚠️ GitLab 远程仓库未配置" "Yellow"
}

# 5. 推送到 GitLab（本地，优先）
Write-Log "========== 推送到 GitLab（本地）==========" "Cyan"

if ($hasGitLab) {
    try {
        Write-Log "推送到 GitLab..." "Cyan"
        $gitlabResult = git push $gitlabRemote $currentBranch 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Log "✅ GitLab 推送成功" "Green"
            $gitlabSuccess = $true
        } else {
            # 尝试设置上游分支
            if ($gitlabResult -match "set-upstream") {
                Write-Log "设置 GitLab 上游分支..." "Cyan"
                $gitlabResult = git push --set-upstream $gitlabRemote $currentBranch 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Log "✅ GitLab 推送成功（已设置上游）" "Green"
                    $gitlabSuccess = $true
                } else {
                    Write-Log "❌ GitLab 推送失败：$gitlabResult" "Red"
                    $gitlabSuccess = $false
                }
            } else {
                Write-Log "❌ GitLab 推送失败：$gitlabResult" "Red"
                $gitlabSuccess = $false
            }
        }

        # 推送标签
        if ($gitlabSuccess) {
            Write-Log "推送标签到 GitLab..." "Cyan"
            git push $gitlabRemote --tags 2>&1 | Out-Null
        }

    } catch {
        Write-Log "❌ GitLab 推送异常：$($_.Exception.Message)" "Red"
        $gitlabSuccess = $false
    }
} else {
    Write-Log "⏭️ 跳过 GitLab（未配置）" "Yellow"
    $gitlabSuccess = $false
}

# 6. 推送到 GitHub（远程）
Write-Log "========== 推送到 GitHub（远程）==========" "Cyan"

if ($hasGitHub) {
    try {
        Write-Log "推送到 GitHub..." "Cyan"
        $githubResult = git push $githubRemote $currentBranch 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Log "✅ GitHub 推送成功" "Green"
            $githubSuccess = $true
        } else {
            # 尝试设置上游分支
            if ($githubResult -match "set-upstream") {
                Write-Log "设置 GitHub 上游分支..." "Cyan"
                $githubResult = git push --set-upstream $githubRemote $currentBranch 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Log "✅ GitHub 推送成功（已设置上游）" "Green"
                    $githubSuccess = $true
                } else {
                    Write-Log "⚠️ GitHub 推送失败（可能网络问题）：$githubResult" "Yellow"
                    $githubSuccess = $false
                }
            } else {
                Write-Log "⚠️ GitHub 推送失败（可能网络问题）：$githubResult" "Yellow"
                $githubSuccess = $false
            }
        }

        # 推送标签
        if ($githubSuccess) {
            Write-Log "推送标签到 GitHub..." "Cyan"
            git push $githubRemote --tags 2>&1 | Out-Null
        }

    } catch {
        Write-Log "⚠️ GitHub 推送异常（可能网络问题）：$($_.Exception.Message)" "Yellow"
        $githubSuccess = $false
    }
} else {
    Write-Log "⏭️ 跳过 GitHub（未配置）" "Yellow"
    $githubSuccess = $false
}

# 7. 同步结果总结
Write-Log "========== 同步结果总结 ==========" "Cyan"

if ($gitlabSuccess -and $githubSuccess) {
    Write-Log "✅ 双重同步成功：GitLab + GitHub" "Green"
    $exitCode = 0
} elseif ($gitlabSuccess) {
    Write-Log "⚠️ 部分成功：GitLab ✅ | GitHub ❌（可能网络问题）" "Yellow"
    Write-Log "   代码已安全保存到本地 GitLab" "Green"
    $exitCode = 0
} elseif ($githubSuccess) {
    Write-Log "⚠️ 部分成功：GitLab ❌ | GitHub ✅" "Yellow"
    Write-Log "   代码已保存到 GitHub" "Green"
    $exitCode = 0
} else {
    Write-Log "❌ 同步失败：GitLab ❌ | GitHub ❌" "Red"
    $exitCode = 1
}

# 8. 显示同步统计
Write-Log "========== 同步统计 ==========" "Cyan"
$commitCount = git rev-list --count HEAD 2>&1
Write-Log "总提交数：$commitCount" "White"

$lastCommit = git log -1 --pretty=format:"%h - %s (%cr)" 2>&1
Write-Log "最新提交：$lastCommit" "White"

Write-Log "========== 双重同步完成 ==========" "Green"
Write-Log ""

# 9. 显示摘要
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  同步结果" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($gitlabSuccess) {
    Write-Host "  GitLab (本地): ✅ 成功" -ForegroundColor Green
} else {
    Write-Host "  GitLab (本地): ❌ 失败" -ForegroundColor Red
}

if ($githubSuccess) {
    Write-Host "  GitHub (远程): ✅ 成功" -ForegroundColor Green
} else {
    Write-Host "  GitHub (远程): ❌ 失败" -ForegroundColor Yellow
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($gitlabSuccess) {
    Write-Host "✅ 代码已安全保存到本地 GitLab" -ForegroundColor Green
    if (-not $githubSuccess) {
        Write-Host "⚠️ GitHub 同步失败（可能网络问题），但本地已备份" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ 本地 GitLab 同步失败，请检查 GitLab 是否运行" -ForegroundColor Yellow
    Write-Host "   docker-compose -f D:\gitlab\docker-compose.yml ps" -ForegroundColor White
}

Write-Host ""
Write-Host "📝 日志文件：$logFile" -ForegroundColor Cyan

exit $exitCode
