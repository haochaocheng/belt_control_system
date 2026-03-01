#!/usr/bin/env powershell
# UTF-8
# Memory System Fix Script

param(
    [switch]$Verify = $false,
    [switch]$Repair = $false
)

$ErrorActionPreference = "Stop"

function Test-MemoryService {
    Write-Host "Checking HTTP server status..." -ForegroundColor Cyan
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:8888/api/memories?page=1&page_size=1" -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "OK: HTTP server is running" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "ERROR: HTTP server not responding" -ForegroundColor Red
        return $false
    }
}

function Test-HooksScripts {
    Write-Host "Checking Hooks scripts..." -ForegroundColor Cyan

    $scripts = @(
        "C:\Users\54999\.claude\hooks\core\user-prompt-submit.js",
        "C:\Users\54999\.claude\hooks\core\stop-save-conversation.js"
    )

    $allExist = $true
    foreach ($script in $scripts) {
        if (Test-Path $script) {
            Write-Host "OK: Script exists: $script" -ForegroundColor Green
        } else {
            Write-Host "ERROR: Script missing: $script" -ForegroundColor Red
            $allExist = $false
        }
    }

    return $allExist
}

function Test-SettingsConfig {
    Write-Host "Checking settings.json..." -ForegroundColor Cyan

    $settingsPath = "$env:USERPROFILE\.claude\settings.json"

    if (-not (Test-Path $settingsPath)) {
        Write-Host "ERROR: settings.json not found" -ForegroundColor Red
        return $false
    }

    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

        if ($settings.model -eq "claude-opus-4-6") {
            Write-Host "OK: Model is claude-opus-4-6" -ForegroundColor Green
        } else {
            Write-Host "WARN: Model is $($settings.model), should be claude-opus-4-6" -ForegroundColor Yellow
        }

        if ($settings.hooks.Stop -and $settings.hooks.UserPromptSubmit) {
            Write-Host "OK: Hooks configuration exists" -ForegroundColor Green
        } else {
            Write-Host "ERROR: Hooks configuration missing" -ForegroundColor Red
            return $false
        }

        if ($settings.mcpServers."mcp-memory-service") {
            Write-Host "OK: MCP server configuration exists" -ForegroundColor Green
        } else {
            Write-Host "ERROR: MCP server configuration missing" -ForegroundColor Red
            return $false
        }

        return $true
    } catch {
        Write-Host "ERROR: Failed to parse settings.json" -ForegroundColor Red
        return $false
    }
}

function Test-HooksLogs {
    Write-Host "Checking Hooks logs..." -ForegroundColor Cyan

    $logDir = "$env:USERPROFILE\.claude\logs"
    $userPromptLog = "$logDir\user-prompt-submit-debug.log"
    $stopLog = "$logDir\stop-conversation-debug.log"

    if (Test-Path $userPromptLog) {
        $lastLine = Get-Content $userPromptLog -Tail 1
        Write-Host "Last UserPromptSubmit: $lastLine" -ForegroundColor Cyan
    }

    if (Test-Path $stopLog) {
        $lastLine = Get-Content $stopLog -Tail 1
        Write-Host "Last Stop: $lastLine" -ForegroundColor Cyan
    }
}

function Repair-Settings {
    Write-Host "Repairing settings.json..." -ForegroundColor Cyan

    $settingsPath = "$env:USERPROFILE\.claude\settings.json"

    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        $settings.model = "claude-opus-4-6"

        if (-not $settings.hooks) {
            $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue @{}
        }

        $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8

        Write-Host "OK: settings.json repaired" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "ERROR: Repair failed" -ForegroundColor Red
        return $false
    }
}

function Show-Summary {
    Write-Host "========== Diagnostic Summary ==========" -ForegroundColor Cyan
    Write-Host "1. HTTP Server: $(if (Test-MemoryService) { 'OK' } else { 'ERROR' })" -ForegroundColor Cyan
    Write-Host "2. Hooks Scripts: $(if (Test-HooksScripts) { 'OK' } else { 'ERROR' })" -ForegroundColor Cyan
    Write-Host "3. Configuration: $(if (Test-SettingsConfig) { 'OK' } else { 'ERROR' })" -ForegroundColor Cyan
    Write-Host "========== Diagnostic Complete ==========" -ForegroundColor Cyan
}

if ($Verify) {
    Write-Host "Starting diagnostic..." -ForegroundColor Green
    Test-MemoryService | Out-Null
    Test-HooksScripts | Out-Null
    Test-SettingsConfig | Out-Null
    Test-HooksLogs
    Show-Summary
} elseif ($Repair) {
    Write-Host "Starting repair..." -ForegroundColor Green
    Repair-Settings | Out-Null
    Write-Host "Repair complete. Please restart Claude Code." -ForegroundColor Green
} else {
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "  .\fix-memory-system.ps1 -Verify   # Run diagnostic" -ForegroundColor Cyan
    Write-Host "  .\fix-memory-system.ps1 -Repair   # Repair settings" -ForegroundColor Cyan
}
