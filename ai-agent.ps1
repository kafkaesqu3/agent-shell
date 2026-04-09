# AI Agent Container Launcher (PowerShell)
# Maps current directory to /workspace and runs with layered Claude Code config
param(
    [Alias('h')]
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$PassedArgs = @()
)

# Configuration
$ClaudeHome = "$env:USERPROFILE\.claude"
$ImageName = "ai-agent:latest"
$VolumeName = "ai-agent-claude"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Show-Usage {
    Write-Host @"
Usage: ai-agent.ps1 [OPTIONS] [SUBCOMMAND]

Launch an AI agent Docker container with the current directory mounted as /workspace.

Options:
  --env <path>        Path to .env file (default: auto-detected)
  --name <name>       Container name (default: current directory name)
  --skills <profiles> Comma-separated skill profiles to activate
  --rm                Remove container on exit (ephemeral mode)
  --lite              Use ai-agent:lite image (Claude Code only)
  --browsing          Use ai-agent:browsing image (base + Chromium)
  --work               Load .env.work profile (Databricks / work credentials)
  --local [MODEL]      Load .env.local profile; optionally set CLAUDE_MODEL=MODEL
  --host              Run in WSL on this machine instead of Docker (still applies env/profile)
  --yolo              Enable --dangerously-skip-permissions (passed through to claude)
  -h, --help          Show this help message

Subcommands:
  sync                Copy session logs from container to ~\.claude\projects\

.env resolution order:
  1. --env flag
  2. .env in current directory
  3. .env in script directory
  4. ~\.config\ai-agent\.env

Examples:
  .\ai-agent.ps1                           # launch with auto-detected .env
  .\ai-agent.ps1 --env ~\.env.work         # use specific env file
  .\ai-agent.ps1 --browsing --rm           # ephemeral browsing container
  .\ai-agent.ps1 --name myproject sync     # sync logs from named container
"@
}

# Handle help flag (also caught by param() -Help alias, but guard here too)
if ($Help) { Show-Usage; exit 0 }

# Parse remaining flags
$EnvFile = $null
$ContainerName = $null
$SkillProfiles = $null
$UseRm = $false
$ProfileName = ""
$ClaudeModel = ""
$HostMode = $false
$i = 0
while ($i -lt $PassedArgs.Count) {
    $arg = $PassedArgs[$i]
    if ($arg -eq "--help") {
        Show-Usage; exit 0
    } elseif ($arg -eq "--env" -and ($i + 1) -lt $PassedArgs.Count) {
        $EnvFile = $PassedArgs[$i + 1]; $i += 2
    } elseif ($arg -match '^--env=(.+)$') {
        $EnvFile = $matches[1]; $i++
    } elseif ($arg -eq "--name" -and ($i + 1) -lt $PassedArgs.Count) {
        $ContainerName = $PassedArgs[$i + 1]; $i += 2
    } elseif ($arg -match '^--name=(.+)$') {
        $ContainerName = $matches[1]; $i++
    } elseif ($arg -eq "--skills" -and ($i + 1) -lt $PassedArgs.Count) {
        $SkillProfiles = $PassedArgs[$i + 1]; $i += 2
    } elseif ($arg -match '^--skills=(.+)$') {
        $SkillProfiles = $matches[1]; $i++
    } elseif ($arg -eq "--rm") {
        $UseRm = $true; $i++
    } elseif ($arg -eq "--lite") {
        $ImageName = "ai-agent:lite"; $i++
    } elseif ($arg -eq "--browsing") {
        $ImageName = "ai-agent:browsing"; $i++
    } elseif ($arg -eq "--work") {
        $ProfileName = "work"; $i++
    } elseif ($arg -eq "--local") {
        $ProfileName = "local"
        if ($i + 1 -lt $PassedArgs.Count -and -not $PassedArgs[$i + 1].StartsWith("--")) {
            $ClaudeModel = $PassedArgs[$i + 1]; $i++
        }
        $i++
    } elseif ($arg -eq "--host") {
        $HostMode = $true; $i++
    } else {
        break
    }
}
$PassArgs = if ($i -lt $PassedArgs.Count) { $PassedArgs[$i..($PassedArgs.Count - 1)] } else { @() }

# Translate --yolo in passthrough args
$PassArgs = @($PassArgs | ForEach-Object { if ($_ -eq '--yolo') { '--dangerously-skip-permissions' } else { $_ } })

# When invoked as 'claude', inject 'claude' as the container command so that
# 'claude foo' maps to 'docker run ... claude foo' inside the container.
$InvokedAs = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
if ($InvokedAs -eq 'claude' -and ($PassArgs.Count -eq 0 -or $PassArgs[0] -ne 'sync')) {
    $PassArgs = @('claude') + $PassArgs
}

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

# Resolve profile env file: CWD > script dir > ~/.config/ai-agent/
$ProfileEnv = ""
if ($ProfileName -ne "") {
    foreach ($dir in @((Get-Location).Path, $ScriptDir, "$env:USERPROFILE\.config\ai-agent")) {
        $candidate = Join-Path $dir ".env.$ProfileName"
        if (Test-Path $candidate) { $ProfileEnv = $candidate; break }
    }
    if ($ProfileEnv -eq "") {
        Write-Host "Warning: no .env.$ProfileName found (searched CWD, script dir, ~\.config\ai-agent\)" -ForegroundColor Yellow
    }
}

# --- Host mode: pass env vars to WSL and exec claude-host there ---
if ($HostMode) {
    $check = wsl command -v claude-host 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "claude-host not found in WSL - run install.sh --path to set up" -ForegroundColor Red
        exit 1
    }
    $wslEnvArgs = @()
    foreach ($file in @($EnvFile, $ProfileEnv) | Where-Object { $_ -and (Test-Path $_) }) {
        Get-Content $file | ForEach-Object {
            $line = $_.Trim() -replace '^export\s+', ''
            if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
                $wslEnvArgs += "$($matches[1])=$($matches[2])"
            }
        }
    }
    if ($ClaudeModel -ne "") { $wslEnvArgs += "CLAUDE_MODEL=$ClaudeModel" }
    & wsl env @wslEnvArgs claude-host @PassArgs
    exit $LASTEXITCODE
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
    Write-Host "Mode: ephemeral (--rm)" -ForegroundColor Yellow
} else {
    if (-not $ContainerName) {
        $ContainerName = (Get-Location | Split-Path -Leaf)
    }
    $DockerArgs += "--name"
    $DockerArgs += $ContainerName
    Write-Host "Container name: $ContainerName" -ForegroundColor Cyan
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

# Load profile env (overrides base vars)
if ($ProfileEnv -ne "" -and (Test-Path $ProfileEnv)) {
    Write-Host "Loading profile from: $ProfileEnv" -ForegroundColor Green
    Get-Content $ProfileEnv | ForEach-Object {
        $line = $_ -replace '^export\s+', ''
        if ($line -match '^[A-Za-z_][A-Za-z0-9_]*=') {
            $DockerArgs += "-e"; $DockerArgs += $line
        }
    }
}
if ($ClaudeModel -ne "") {
    $DockerArgs += "-e"; $DockerArgs += "CLAUDE_MODEL=$ClaudeModel"
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

# Optional: host credentials - staged outside the named volume so the
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
