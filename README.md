# AI Agent Docker Container

A portable Docker container with multiple AI coding assistants that you can launch in any project directory.

## What's Included

### AI Coding Assistants
- **Claude Code** - Anthropic's official CLI for code generation, refactoring, and debugging
- **OpenAI Codex** - OpenAI's code generation model
- **GitHub Copilot CLI** - Command-line suggestions and explanations
- **Gemini Pro** - Google's Gemini AI models for coding tasks
- **Aider** - AI pair programming in your terminal (supports Claude, GPT-4, Gemini)
- **Shell-GPT** - Natural language shell command generation
- **Fabric** - AI patterns framework for various development workflows

### Development Tools
- Node.js 22
- Python 3 with pip
- Go
- Git
- GitHub CLI (gh)

## Workflow

The intended workflow is:

1. **One-time setup**: Build the Docker image and configure your API keys
2. **Daily use**: Navigate to any project directory and launch the AI agent container
3. **Work**: Your current directory is mounted at `/workspace` with all AI tools available
4. **Exit**: Type `exit` and you're back in your host terminal

## One-Time Setup

### Step 1: Build the Docker Image

From this directory, build the image once:

```bash
docker build -t ai-agent:latest .
```

This creates the `ai-agent:latest` image that you'll reuse across all projects.

### Step 2: Create Your .env File

Create a `.env` file in a central location to store your API keys:

**Option A: Store in your home directory (Recommended)**

```bash
# Linux/Mac
mkdir -p ~/.config/ai-agent
cp .env.example ~/.config/ai-agent/.env
nano ~/.config/ai-agent/.env

# Windows (PowerShell)
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\ai-agent"
Copy-Item .env.example "$env:USERPROFILE\.config\ai-agent\.env"
notepad "$env:USERPROFILE\.config\ai-agent\.env"
```

**Option B: Store alongside the scripts (This directory)**

```bash
cp .env.example .env
nano .env  # or use your preferred editor
```

Fill in your API keys:
```env
ANTHROPIC_API_KEY=sk-ant-your-actual-key-here
OPENAI_API_KEY=sk-your-actual-key-here
GOOGLE_API_KEY=your-actual-key-here
GITHUB_TOKEN=ghp_your-actual-token-here
```

### Step 3: Set Up the Launch Script

You have two options:

**Option A: Add to your PATH (Recommended for frequent use)**

```bash
# Linux/Mac
chmod +x ai-agent.sh
sudo cp ai-agent.sh /usr/local/bin/ai-agent
# Or add this directory to your PATH

# Windows (PowerShell as Administrator)
# Add this directory to your PATH or copy to a PATH location
Copy-Item ai-agent.ps1 "C:\Windows\System32\ai-agent.ps1"
```

**Option B: Copy to individual projects (Simple but repetitive)**

Copy `ai-agent.sh` (Linux/Mac) or `ai-agent.ps1` (Windows) to each project where you want to use it.

### Step 4: Configure Script Path (If Using Option A for .env)

If you stored your `.env` in `~/.config/ai-agent/`, the scripts are already configured correctly.

If you stored it elsewhere, edit the scripts and update the `EnvFile` / `ENV_FILE` path at the top.

## Daily Use

Once setup is complete, using the AI agent is simple:

### 1. Clone or Navigate to Any Project

```bash
# Clone a new repository
git clone https://github.com/username/some-project.git
cd some-project

# Or navigate to an existing project
cd ~/projects/my-awesome-app
```

### 2. Launch the AI Agent Container

**Linux/Mac:**
```bash
ai-agent        # If in PATH
# or
./ai-agent.sh   # If copied to project directory
# or
/path/to/docker-containers/ai-agent/ai-agent.sh  # Full path
```

**Windows PowerShell:**
```powershell
ai-agent        # If in PATH
# or
.\ai-agent.ps1  # If copied to project directory
# or
C:\_Ktools\Scripts\private\docker-containers\ai-agent\ai-agent.ps1  # Full path
```

### 3. Use AI Tools

The container starts in `/workspace`, which is mapped to your current directory:

```bash
# You're now inside the container!
root@container:/workspace#

# All your project files are here
ls -la

# Use any AI tool
claude-code "help me understand this codebase"
aider main.py
sgpt "create a git command to show files changed in last week"
gemini "explain this function"
gh copilot suggest "run tests and show coverage"
```

### 4. Exit When Done

```bash
exit
```

You're back in your host terminal, all file changes are preserved in your project directory.

## Usage Examples

### Claude Code

```bash
# Interactive session
claude-code

# Direct commands
claude-code "refactor this function to use async/await"
claude-code "add error handling to app.js"
claude-code "explain what this code does"
```

### Aider - AI Pair Programming

```bash
# Start with Claude
aider

# Use GPT-4
aider --model gpt-4

# Use Gemini
aider --model gemini/gemini-pro

# Work on specific files
aider src/app.js src/utils.js

# Auto-commit changes
aider --auto-commits

# Ask Aider to implement a feature
aider
> Add user authentication with JWT tokens
```

### Shell-GPT (sgpt)

```bash
# Ask questions
sgpt "how do I find all large files in current directory"

# Generate shell commands
sgpt --shell "find files modified in last 7 days"

# Execute commands directly (with confirmation)
sgpt --shell --execute "create a backup of all .js files"

# Code generation
sgpt --code "python function to parse JSON and extract email addresses"
```

### Gemini Pro CLI

```bash
# Ask questions
gemini "explain how async/await works in JavaScript"

# Code review
gemini "review this code: $(cat app.js)"

# Generate code
gemini "create a Python function to validate email addresses"
```

### GitHub Copilot CLI

First-time setup (run once inside container):
```bash
gh auth login
gh extension install github/gh-copilot
```

Then use:
```bash
# Get command suggestions
gh copilot suggest "install dependencies and start dev server"

# Explain a command
gh copilot explain "docker run -it -v $(pwd):/app node:22"
```

### Fabric - AI Patterns

First-time setup (run once inside container):
```bash
fabric --setup
```

Then use:
```bash
# List available patterns
fabric --list

# Extract wisdom from content
cat article.md | fabric --pattern extract_wisdom

# Summarize
cat documentation.md | fabric --pattern summarize

# Create content
fabric --pattern create_essay "write about microservices"
```

## Advanced Usage

### Pass Arguments to Container

You can pass commands to run inside the container:

```bash
# Run a specific command
ai-agent bash -c "claude-code 'explain main.py' && exit"

# Run and exit immediately
ai-agent sgpt "summarize this project"
```

### Multiple Terminal Sessions

You can run multiple containers for the same project:

```bash
# Terminal 1
cd ~/projects/my-app
ai-agent

# Terminal 2 (same project)
cd ~/projects/my-app
ai-agent
```

Each gets its own container instance, but they share the same project files.

### Different Projects Simultaneously

```bash
# Terminal 1 - Project A
cd ~/projects/project-a
ai-agent

# Terminal 2 - Project B
cd ~/projects/project-b
ai-agent

# Terminal 3 - Project C
cd ~/projects/project-c
ai-agent
```

Each container is isolated but has access to its respective project directory.

### Custom .env Per Project

If you need different API keys for different projects:

```bash
# Create project-specific .env
cd ~/projects/client-project
cp ~/.config/ai-agent/.env .env.client
# Edit .env.client with client-specific keys

# Modify the launch script temporarily or create a wrapper
# Then run with custom env file
```

## Tips & Tricks

1. **Create shell aliases** (if script is not in PATH):
   ```bash
   # Linux/Mac (~/.bashrc or ~/.zshrc)
   alias ai='~/path/to/ai-agent.sh'

   # Windows (PowerShell $PROFILE)
   function ai { & C:\path\to\ai-agent.ps1 }
   ```

2. **Quick project setup**:
   ```bash
   git clone <repo> && cd <repo> && ai-agent
   ```

3. **Combine AI tools**:
   ```bash
   # Inside container
   sgpt --shell "find all TODO comments" | sh
   aider --yes "implement all TODOs"
   fabric --pattern create_documentation < main.py > docs/main.md
   ```

4. **Save container state** (advanced):
   ```bash
   # Commit container changes to new image
   docker commit ai-agent ai-agent:custom
   # Update script to use ai-agent:custom
   ```

5. **View running containers**:
   ```bash
   docker ps  # See all active AI agent containers
   ```
