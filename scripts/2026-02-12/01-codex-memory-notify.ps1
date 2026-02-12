param(
    [Parameter(Position = 0)]
    [string]$NotificationJson,
    [Parameter(Position = 1)]
    [string]$NotificationType
)

$ErrorActionPreference = "Stop"

# Codex notify may pass payload via argv or stdin; support both.
$rawInput = $NotificationJson
if ([string]::IsNullOrWhiteSpace($rawInput)) {
    try {
        $stdinText = [Console]::In.ReadToEnd()
        if (-not [string]::IsNullOrWhiteSpace($stdinText)) {
            $rawInput = $stdinText
        }
    } catch {
        # ignore
    }
}

if ([string]::IsNullOrWhiteSpace($rawInput)) {
    exit 0
}

$payload = $null
try {
    $payload = $rawInput | ConvertFrom-Json -Depth 16
} catch {
    # Some notify integrations may provide plain event type only.
    if ($rawInput -eq 'agent-turn-complete' -or $NotificationType -eq 'agent-turn-complete') {
        exit 0
    }
    exit 0
}

$type = [string]$payload.type
if ([string]::IsNullOrWhiteSpace($type)) {
    $type = $NotificationType
}
if ($type -ne 'agent-turn-complete') {
    exit 0
}

$endpoint = $env:CODEX_MEMORY_API_URL
if ([string]::IsNullOrWhiteSpace($endpoint)) {
    $endpoint = 'http://127.0.0.1:8888/api/memories'
}

$threadId = [string]$payload.'thread-id'
$turnId = [string]$payload.'turn-id'
$cwd = [string]$payload.cwd
$timestamp = (Get-Date).ToString('o')

function Add-Memory {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string[]]$Tags,
        [hashtable]$ExtraMetadata
    )

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return
    }

    $metadata = @{
        source = 'codex-notify-hook'
        thread_id = $threadId
        turn_id = $turnId
        working_directory = $cwd
        timestamp = $timestamp
    }

    if ($ExtraMetadata) {
        foreach ($k in $ExtraMetadata.Keys) {
            $metadata[$k] = $ExtraMetadata[$k]
        }
    }

    $body = @{
        content = $Content
        tags = $Tags
        metadata = $metadata
    } | ConvertTo-Json -Depth 12

    try {
        Invoke-RestMethod -Method Post -Uri $endpoint -ContentType 'application/json' -Body $body | Out-Null
    } catch {
        # Keep Codex flow uninterrupted even if memory service is temporarily unavailable.
    }
}

$userMessages = @()
if ($null -ne $payload.'input-messages') {
    if ($payload.'input-messages' -is [System.Array]) {
        $userMessages = $payload.'input-messages'
    } else {
        $userMessages = @([string]$payload.'input-messages')
    }
}

foreach ($msg in $userMessages) {
    $text = [string]$msg
    if (-not [string]::IsNullOrWhiteSpace($text)) {
        Add-Memory -Content ("User input: " + $text) -Tags @('codex', 'user-input', 'auto', 'belt_control_system')
    }
}

$assistantMsg = [string]$payload.'last-assistant-message'
if (-not [string]::IsNullOrWhiteSpace($assistantMsg)) {
    Add-Memory -Content ("Assistant output: " + $assistantMsg) -Tags @('codex', 'assistant-output', 'auto', 'belt_control_system')
}
