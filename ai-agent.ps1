# AI Agent Container Launcher (PowerShell)
# Maps current directory to /workspace and runs with layered Claude Code config

# Configuration
$ClaudeHome = "$env:USERPROFILE\.claude"
$ImageName = "ai-agent:latest"
$VolumeName = "ai-agent-claude"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Parse flags
$EnvFile = $null
$ContainerName = $null
$SkillProfiles = $null
$UseRm = $false
$i = 0
while ($i -lt $args.Count) {
    $arg = $args[$i]
    if ($arg -eq "--env" -and ($i + 1) -lt $args.Count) {
        $EnvFile = $args[$i + 1]; $i += 2
    } elseif ($arg -match '^--env=(.+)$') {
        $EnvFile = $matches[1]; $i++
    } elseif ($arg -eq "--name" -and ($i + 1) -lt $args.Count) {
        $ContainerName = $args[$i + 1]; $i += 2
    } elseif ($arg -match '^--name=(.+)$') {
        $ContainerName = $matches[1]; $i++
    } elseif ($arg -eq "--skills" -and ($i + 1) -lt $args.Count) {
        $SkillProfiles = $args[$i + 1]; $i += 2
    } elseif ($arg -match '^--skills=(.+)$') {
        $SkillProfiles = $matches[1]; $i++
    } elseif ($arg -eq "--rm") {
        $UseRm = $true; $i++
    } elseif ($arg -eq "--lite") {
        $ImageName = "ai-agent:lite"; $i++
    } elseif ($arg -eq "--browsing") {
        $ImageName = "ai-agent:browsing"; $i++
    } else {
        break
    }
}
$PassArgs = if ($i -lt $args.Count) { $args[$i..($args.Count - 1)] } else { @() }

# Handle subcommands
if ($PassArgs.Count -gt 0 -and $PassArgs[0] -eq "sync") {
    if (-not $ContainerName) {
        $ContainerName = (Get-Location | Split-Path -Leaf)
    }
    try {
        docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "not running" }
    } catch {
        Write-Host "Docker is not running!" -ForegroundColor Red; exit 1
    }
    $null = New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\projects"
    $running = docker ps --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
    $stopped = docker ps -a --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
    if ($running) {
        Write-Host "Syncing from running container: $ContainerName" -ForegroundColor Cyan
    } elseif ($stopped) {
        Write-Host "Syncing from stopped container: $ContainerName" -ForegroundColor Cyan
    } else {
        Write-Host "Container not found: $ContainerName" -ForegroundColor Red
        Write-Host "Specify with --name, or run from the project directory"
        exit 1
    }
    docker cp "${ContainerName}:/home/agent/.claude/projects/." "$env:USERPROFILE\.claude\projects\" 2>$null
    Write-Host "Session logs synced to ~\.claude\projects\" -ForegroundColor Green
    exit 0
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
$DockerArgs = @("run", "-it")
if ($UseRm) {
    $DockerArgs += "--rm"
} else {
    if (-not $ContainerName) {
        $ContainerName = (Get-Location | Split-Path -Leaf)
    }
    $DockerArgs += "--name"
    $DockerArgs += $ContainerName
}

# Load .env and pass vars
if ($EnvFile -and (Test-Path $EnvFile)) {
    Write-Host "Loading API keys from: $EnvFile" -ForegroundColor Green
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $line = $line -replace '^export\s+', ''
            if ($line -match '^[^=]+=') {
                $DockerArgs += "-e"
                $DockerArgs += $line
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

# Volumes
$CurrentDir = (Get-Location).Path
$DockerArgs += "-v"; $DockerArgs += "${CurrentDir}:/workspace"
$DockerArgs += "-v"; $DockerArgs += "${VolumeName}:/home/agent/.claude"

# Optional: host CLAUDE.md override (staged for entrypoint processing)
$ClaudeMd = Join-Path $ClaudeHome "CLAUDE.md"
if (Test-Path $ClaudeMd) {
    $DockerArgs += "-v"; $DockerArgs += "${ClaudeMd}:/opt/host-config/CLAUDE.md:ro"
    Write-Host "Mounting host CLAUDE.md" -ForegroundColor Green
}

# Optional: host settings.json override (staged for entrypoint processing)
$ClaudeSettings = Join-Path $ClaudeHome "settings.json"
if (Test-Path $ClaudeSettings) {
    $DockerArgs += "-v"; $DockerArgs += "${ClaudeSettings}:/opt/host-config/settings.json:ro"
    Write-Host "Mounting host settings.json" -ForegroundColor Green
}

# Optional: host credentials — staged outside the named volume so the
# entrypoint can copy them in (bind-mounting a file inside a named-volume
# directory is unreliable; the volume wins).
$ClaudeCreds = Join-Path $ClaudeHome ".credentials.json"
if (Test-Path $ClaudeCreds) {
    $DockerArgs += "-v"; $DockerArgs += "${ClaudeCreds}:/opt/host-config/.credentials.json:ro"
    Write-Host "Mounting host credentials" -ForegroundColor Green
}

# Optional: git config
$GitConfig = Join-Path $env:USERPROFILE ".gitconfig"
if (Test-Path $GitConfig) {
    $DockerArgs += "-v"; $DockerArgs += "${GitConfig}:/home/agent/.gitconfig:ro"
}

if ($SkillProfiles) {
    $DockerArgs += "-e"; $DockerArgs += "SKILL_PROFILES=$SkillProfiles"
}

# Pass host UID/GID so the entrypoint can remap the agent user and avoid
# corrupting bind-mounted workspace ownership. On Windows/WSL2, Docker Desktop
# handles UID mapping internally, so we use 1000 as the conventional WSL default.
$DockerArgs += "-e"; $DockerArgs += "HOST_UID=1000"
$DockerArgs += "-e"; $DockerArgs += "HOST_GID=1000"
$DockerArgs += "-w"; $DockerArgs += "/workspace"
$DockerArgs += $ImageName

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
