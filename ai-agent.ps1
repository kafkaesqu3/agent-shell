# AI Agent Container Launcher (PowerShell)
# Maps current directory to /workspace and runs with layered Claude Code config

# Configuration
$ClaudeHome = "$env:USERPROFILE\.claude"
$ImageName = "ai-agent:latest"
$VolumeName = "ai-agent-claude"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Parse --env flag (must be first arg)
$EnvFile = $null
$PassArgs = $args
if ($args.Count -ge 2 -and $args[0] -eq "--env") {
    $EnvFile = $args[1]
    $PassArgs = $args[2..($args.Count - 1)]
} elseif ($args.Count -ge 1 -and $args[0] -match '^--env=(.+)$') {
    $EnvFile = $matches[1]
    $PassArgs = $args[1..($args.Count - 1)]
}

# Resolve .env file: --env flag > .env in current dir > .env in script dir > ~/.config/ai-agent/.env
if (-not $EnvFile) {
    if (Test-Path ".env") {
        $EnvFile = ".env"
    } elseif (Test-Path (Join-Path $ScriptDir ".env")) {
        $EnvFile = Join-Path $ScriptDir ".env"
    } elseif (Test-Path "$env:USERPROFILE\.config\ai-agent\.env") {
        $EnvFile = "$env:USERPROFILE\.config\ai-agent\.env"
    }
}

Write-Host "AI Agent Container" -ForegroundColor Cyan
Write-Host "Working directory: $(Get-Location)"
Write-Host ""

# Check Docker
try {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Docker not running" }
} catch {
    Write-Host "Docker is not running!" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and try again."
    exit 1
}
Write-Host "Docker is running" -ForegroundColor Green

# Build docker args
$DockerArgs = @("run", "-it", "--rm")

# Load .env and pass vars
if ($EnvFile -and (Test-Path $EnvFile)) {
    Write-Host "Loading API keys from: $EnvFile" -ForegroundColor Green
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $matches[1]
                $value = $matches[2]
                $DockerArgs += "-e"
                $DockerArgs += $key
                [Environment]::SetEnvironmentVariable($key, $value, 'Process')
            }
        }
    }
} else {
    Write-Host "No .env file found" -ForegroundColor Yellow
    Write-Host "  Searched: .env (current dir), $ScriptDir\.env, ~\.config\ai-agent\.env"
    Write-Host "  Use --env <path> to specify, or copy an env template:"
    Write-Host "    cp .env.example .env     # then fill in your keys"
    Write-Host "    cp .env.claude .env      # Claude-only"
    Write-Host "    cp .env.full .env        # all AI tools"
    Write-Host "    cp .env.browsing .env    # browsing + search"
}

Write-Host ""

# Volume: current directory
$CurrentDir = (Get-Location).Path
$DockerArgs += "-v"
$DockerArgs += "${CurrentDir}:/workspace"

# Volume: persistent Claude state
$DockerArgs += "-v"
$DockerArgs += "${VolumeName}:/root/.claude"

# Optional: host CLAUDE.md override
$ClaudeMd = Join-Path $ClaudeHome "CLAUDE.md"
if (Test-Path $ClaudeMd) {
    $DockerArgs += "-v"
    $DockerArgs += "${ClaudeMd}:/root/.claude/CLAUDE.md.host:ro"
    Write-Host "Mounting host CLAUDE.md" -ForegroundColor Green
}

# Optional: host settings.json override
$ClaudeSettings = Join-Path $ClaudeHome "settings.json"
if (Test-Path $ClaudeSettings) {
    $DockerArgs += "-v"
    $DockerArgs += "${ClaudeSettings}:/root/.claude/settings.json.host:ro"
    Write-Host "Mounting host settings.json" -ForegroundColor Green
}

# Optional: host credentials
$ClaudeCreds = Join-Path $ClaudeHome ".credentials.json"
if (Test-Path $ClaudeCreds) {
    $DockerArgs += "-v"
    $DockerArgs += "${ClaudeCreds}:/root/.claude/.credentials.json:ro"
    Write-Host "Mounting host credentials" -ForegroundColor Green
}

# Optional: git config
$GitConfig = Join-Path $env:USERPROFILE ".gitconfig"
if (Test-Path $GitConfig) {
    $DockerArgs += "-v"
    $DockerArgs += "${GitConfig}:/root/.gitconfig:ro"
}

$DockerArgs += "-w"
$DockerArgs += "/workspace"
$DockerArgs += $ImageName

# Pass through arguments (excluding --env flag already parsed)
if ($PassArgs.Count -gt 0) {
    $DockerArgs += $PassArgs
}

Write-Host ""
Write-Host "Available AI tools:" -ForegroundColor Green
Write-Host "  - claude         (Anthropic Claude Code)"
Write-Host "  - aider          (AI pair programming)"
Write-Host "  - sgpt           (Shell-GPT)"
Write-Host "  - gemini         (Google Gemini)"
Write-Host "  - gh copilot     (GitHub Copilot CLI)"
Write-Host "  - fabric         (AI patterns)"
Write-Host ""
Write-Host "Type 'exit' to leave the container"
Write-Host "===================================="
Write-Host ""

& docker @DockerArgs
