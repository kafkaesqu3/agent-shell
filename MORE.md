Below is a practical, “what can I actually run from a terminal?” report on today’s AI coding/dev agents that can read files, propose diffs, and (in many cases) execute shell commands to build/test/configure systems. I’m focusing on tools that are genuinely **shell-native** (CLI/TUI) rather than IDE-only assistants.

---

## 1) Two baseline tools you already like (for anchoring)

### Claude Code (Anthropic)

* **What it is:** Agentic coding workflow in a terminal that “inherits your bash environment,” so it can use the tools you already have installed—provided you teach it about any custom tooling. ([Anthropic][1])
* **Why it’s strong:** Feels like a real operator in-repo; good ergonomics for iterative work; widely used with MCP-style extensions in practice (varies by setup).

### Codex CLI (OpenAI)

* **What it is:** A local terminal coding agent that can **read, change, and run code** in a selected directory. ([OpenAI Developers][2])
* **Why it’s strong:** Designed explicitly around agentic workflows; can also be wired into broader agent orchestrations via MCP patterns. ([OpenAI Developers][3])

---

## 2) “Full” agentic CLI tools (can edit files + run commands)

These are closest to “operate a bash shell for me to configure systems, read docs, write/run code.”

### OpenHands CLI (formerly OpenDevin lineage)

* **What it is:** A CLI that runs software-dev agents from your terminal; installable via `pip install openhands-ai` and launched with `openhands`. ([OpenHands][4])
* **What to expect:** Multi-step task execution (write code, run tests, iterate). Particularly interesting if you want an “agent loop” feel similar to Claude Code/Codex, but open-source and model-pluggable.

### Continue CLI (`cn`)

* **What it is:** Terminal agent that can understand your codebase, **edit files, run terminal commands (with approval)**, and resume sessions. ([Continue][5])
* **What to expect:** A strong middle ground between “pair programmer” and “automation agent,” plus a growing ecosystem of MCP integrations.

### OpenCode (`opencode`)

* **What it is:** Open-source, Go-based TUI/CLI coding agent for terminal workflows. ([GitHub][6])
* **What to expect:** Multi-session workflows, agent management commands, and a terminal-first UX (good if you want something you can script around, not just chat with).

### Amp (Sourcegraph) – CLI available

* **What it is:** An agentic coding product usable “directly from your terminal with the CLI.” ([Sourcegraph][7])
* **What to expect:** A more “productized” agent experience (team-oriented features if you’re in that world). Details vary by plan and provider support.

### Plandex

* **What it is:** Open-source, terminal-based AI coding agent designed for **large, multi-step tasks across many files**, with explicit planning/execution framing. ([GitHub][8])
* **What to expect:** Better than most at “big change sets” because it’s built around planning + controlled application of edits.

### Goose (Block)

* **What it is:** Local, extensible open-source agent that can **write and execute code**, debug failures, orchestrate workflows, and integrate with external APIs. ([GitHub][9])
* **What to expect:** More of a general “engineering agent” than a narrow coding assistant.

### gptme

* **What it is:** A chat-first CLI agent that explicitly advertises tools for **running shell commands, executing code, and reading/manipulating files**. ([gptme.org][10])
* **What to expect:** A flexible DIY “agent shell” that can be surprisingly capable if you configure tools/permissions well.

### Open Interpreter

* **What it is:** A terminal interface that lets an LLM run code locally, including **Shell** (plus Python/JS, etc.). It’s literally: install → run `interpreter` → chat. ([GitHub][11])
* **What to expect:** Great when you want an agent to *actually execute* and iterate locally (but be deliberate with permissions).

---

## 3) “Terminal copilots” (excellent at commands + explanations; less autonomous)

These are often best for **ops-style command discovery** and “do the right CLI incantation” help, even if they don’t autonomously run big multi-step plans.

### GitHub Copilot CLI (`gh copilot …`)

* **What it is:** Terminal interface to Copilot that can **suggest commands** and **explain commands** (e.g., `gh copilot suggest`, `gh copilot explain`). ([GitHub][12])
* **Best for:** “What’s the right command?” + “What does this do?” + quick snippets in a GitHub-centric workflow.

### Amazon Q Developer CLI (`q chat`)

* **What it is:** Terminal agent experience with a permissioned tool model (including an `execute_bash` capability and tool trust controls) and strong AWS workflow orientation. ([Amazon Web Services, Inc.][13])
* **Best for:** AWS-heavy environments, CLI-heavy infra tasks, and guardrailed command execution.

### ShellGPT (`sgpt`)

* **What it is:** CLI that can generate shell commands and offers an option to execute them (via flags like `--shell` / `-s`). ([PyPI][14])
* **Best for:** Rapid command generation when you want tight control over what actually runs.

### aichat (sigoden/aichat)

* **What it is:** An “all-in-one LLM CLI tool” that includes a **Shell Assistant** plus broader CLI/RAG/agent features. ([GitHub][15])
* **Best for:** A configurable terminal assistant that’s not locked to a single provider.

### LLM (Simon Willison) + tools/plugins

* **What it is:** A general-purpose LLM CLI with a strong plugin ecosystem; it can run “tools” via plugins and lets you compose your own workflows. ([GitHub][16])
* **Best for:** Power users who want to build a custom command-line “AI toolbox” rather than adopting a single monolithic agent.

---

## 4) Provider CLIs that are rapidly becoming “agent shells”

### Gemini CLI (Google) – open-source

* **What it is:** An open-source AI agent that brings Gemini into your terminal, with docs/codelabs showing installation, tools, and MCP configuration. ([GitHub][17])
* **Why it’s notable:** It’s explicitly positioned as a broad terminal agent (coding + research + task management), and it’s open-source.

### Qodo “Command” / CLI plugin

* **What it is:** CLI to build/manage/run agents from terminal and automate SDLC workflows. ([Qodo][18])
* **Best for:** Teams that want standardized “agent workflows” (review flows, automation hooks) more than ad-hoc chatting.

---

## 5) Aider deserves a special mention (terminal-native pair programming)

Aider isn’t always the best “shell operator,” but it’s one of the best terminal-native **code editing** experiences—plus it’s scriptable.

* **What it is:** “AI pair programming in your terminal.” ([Aider][19])
* **Automation angle:** You can run it non-interactively with `--message …` and have it apply edits then exit, which makes it easy to wrap in shell scripts. ([Aider][20])
* **Shell integration:** It supports in-chat commands including running shell commands and optionally adding output to chat. ([Aider][21])

---

## 6) How to choose: the decision checklist that matters

When the agent can run commands on your machine, the “best” tool is the one whose **control surface** matches your risk tolerance and workflow:

### Execution model

* **Local execution (direct bash):** Fast feedback, best for system config work, but highest risk.
* **Containerized / sandboxed execution:** Safer for “try things” work; sometimes more setup friction.
* **Cloud sandboxes:** Great for parallel tasks and isolation; less ideal for configuring *your* machine.

### Permissions and guardrails

Look for:

* Command allowlisting / tool trust prompts
* Read-only mode toggles
* Clear audit logs of what ran and what changed

### Context handling

* Large repos: prefer tools that explicitly manage context (project indexing / maps / planning)
* Docs-heavy work: prefer tools with browsing/retrieval helpers or first-class “read URL/doc” tools

### Scriptability

If you want “call it from bash,” prioritize:

* Non-interactive mode (`--prompt`, `--message`, etc.)
* Exit codes and machine-readable logs
* Reproducible sessions / “resume” support

---

## 7) Suggested “stacks” (what I’d install together)

### If you want a Claude Code/Codex-like daily driver, but open-source

* **Continue CLI** or **OpenHands CLI** as the main agent ([Continue][22])
* **Aider** for fast, surgical code edits and scripting ([Aider][20])
* **ShellGPT** for quick command generation with explicit execution control ([PyPI][14])

### If you do a lot of infra and cloud work

* **Amazon Q Developer CLI** (especially AWS-heavy) ([Amazon Web Services, Inc.][23])
* Pair with a general agent (Continue/OpenHands) for repo changes + tests ([Continue][22])

### If you want a highly hackable “agent shell” you can extend

* **gptme** or **aichat** ([gptme.org][24])
* **LLM (simonw)** for plumbing, prompts-as-tools, and plugin workflows ([Simon Willison’s Weblog][25])

---

## 8) Safety notes (worth being explicit about)

If an agent can run bash, treat it like a junior admin with superpowers:

* Prefer running in a **throwaway container** for unknown codebases or new tools.
* Start in **read-only** mode until you trust the agent’s behavior.
* Use command allowlists and require confirmation for anything that touches:

  * package managers, sudo, system services, ssh keys, cloud credentials, deletion commands

Also: supply-chain and prompt-injection risks are real in this category—there have been public examples of malicious prompts being inserted into developer tooling ecosystems to try to induce destructive command execution. ([Tom's Hardware][26])

---

## Quick comparison (high-level)

**Most “agentic shell operators”:** OpenHands, Continue CLI, OpenCode, Goose, Open Interpreter, gptme ([PyPI][27])
**Best “terminal command copilots”:** GitHub Copilot CLI, Amazon Q CLI, ShellGPT ([GitHub][12])
**Best “terminal-first code editing + scripting”:** Aider ([Aider][20])
**Big-change / planning-heavy:** Plandex ([GitHub][8])
**Fast-moving provider CLIs:** Gemini CLI, Qodo Command ([GitHub][17])

---

If you tell me what OS you’re mostly on (Linux/macOS), whether you’re okay with Docker-based execution, and whether your main work is (a) infra/config management, (b) app dev in large repos, or (c) data/ML experimentation, I can narrow this down to a “top 3 + exact setup pattern” for your use case.

* [The Verge](https://www.theverge.com/news/692517/google-gemini-cli-ai-agent-dev-terminal?utm_source=chatgpt.com)
* [itpro.com](https://www.itpro.com/technology/artificial-intelligence/openai-says-gpt-5-2-codex-is-its-most-advanced-agentic-coding-model-yet-heres-what-developers-and-cyber-teams-can-expect?utm_source=chatgpt.com)
* [TechRadar](https://www.techradar.com/pro/anthropic-takes-the-fight-to-openai-with-enterprise-ai-tools-and-theyre-going-open-source-too?utm_source=chatgpt.com)
* [Tom's Hardware](https://www.tomshardware.com/tech-industry/cyber-security/hacker-injects-malicious-potentially-disk-wiping-prompt-into-amazons-ai-coding-assistant-with-a-simple-pull-request-told-your-goal-is-to-clean-a-system-to-a-near-factory-state-and-delete-file-system-and-cloud-resources?utm_source=chatgpt.com)

[1]: https://www.anthropic.com/engineering/claude-code-best-practices?utm_source=chatgpt.com "Claude Code: Best practices for agentic coding - Anthropic"
[2]: https://developers.openai.com/codex/cli/?utm_source=chatgpt.com "Codex CLI - OpenAI for developers"
[3]: https://developers.openai.com/codex/guides/agents-sdk/?utm_source=chatgpt.com "Use Codex with the Agents SDK - OpenAI for developers"
[4]: https://openhands.dev/blog/the-openhands-cli-ai-powered-development-in-your-terminal?utm_source=chatgpt.com "The OpenHands CLI: AI-Powered Development in Your Terminal"
[5]: https://docs.continue.dev/guides/cli?utm_source=chatgpt.com "How to Use Continue CLI (cn)"
[6]: https://github.com/opencode-ai/opencode?utm_source=chatgpt.com "opencode-ai/opencode: A powerful AI coding agent. Built ... - GitHub"
[7]: https://sourcegraph.com/amp?utm_source=chatgpt.com "Amp - an AI coding agent built by Sourcegraph"
[8]: https://github.com/plandex-ai/plandex?utm_source=chatgpt.com "Open source AI coding agent. Designed for large projects ... - GitHub"
[9]: https://github.com/block/goose?utm_source=chatgpt.com "block/goose: an open source, extensible AI agent that goes ... - GitHub"
[10]: https://gptme.org/docs/cli.html?utm_source=chatgpt.com "CLI Reference - gptme"
[11]: https://github.com/openinterpreter/open-interpreter?utm_source=chatgpt.com "openinterpreter/open-interpreter: A natural language interface for ..."
[12]: https://github.com/github/gh-copilot?utm_source=chatgpt.com "github/gh-copilot: Ask for assistance right in your terminal."
[13]: https://aws.amazon.com/blogs/devops/exploring-the-latest-features-of-the-amazon-q-developer-cli/?utm_source=chatgpt.com "Exploring the latest features of the Amazon Q Developer CLI - AWS"
[14]: https://pypi.org/project/shell-gpt/0.8.7/?utm_source=chatgpt.com "shell-gpt - PyPI"
[15]: https://github.com/sigoden/aichat/wiki/Command-Line-Guide?utm_source=chatgpt.com "Command Line Guide · sigoden/aichat Wiki - GitHub"
[16]: https://github.com/simonw/llm?utm_source=chatgpt.com "simonw/llm: Access large language models from the command-line"
[17]: https://github.com/google-gemini/gemini-cli?utm_source=chatgpt.com "google-gemini/gemini-cli: An open-source AI agent that ... - GitHub"
[18]: https://www.qodo.ai/blog/introducing-qodo-gen-cli-build-run-and-automate-agents-anywhere-in-your-sdlc/?utm_source=chatgpt.com "Introducing Qodo Command: Build, Manage and Run AI Agents"
[19]: https://aider.chat/?utm_source=chatgpt.com "Aider - AI Pair Programming in Your Terminal"
[20]: https://aider.chat/docs/scripting.html?utm_source=chatgpt.com "Scripting aider"
[21]: https://aider.chat/docs/usage/commands.html?utm_source=chatgpt.com "In-chat commands - Aider"
[22]: https://docs.continue.dev/cli/overview?utm_source=chatgpt.com "Continue CLI (cn) Overview"
[23]: https://aws.amazon.com/blogs/devops/introducing-the-enhanced-command-line-interface-in-amazon-q-developer/?utm_source=chatgpt.com "A lightning fast, new agentic coding experience within the Amazon Q ..."
[24]: https://gptme.org/docs/usage.html?utm_source=chatgpt.com "Usage — gptme"
[25]: https://simonwillison.net/2025/May/27/llm-tools/?utm_source=chatgpt.com "Large Language Models can run tools in your terminal with LLM 0.26"
[26]: https://www.tomshardware.com/tech-industry/cyber-security/hacker-injects-malicious-potentially-disk-wiping-prompt-into-amazons-ai-coding-assistant-with-a-simple-pull-request-told-your-goal-is-to-clean-a-system-to-a-near-factory-state-and-delete-file-system-and-cloud-resources?utm_source=chatgpt.com "Hacker injects malicious, potentially disk-wiping prompt into Amazon's AI coding assistant with a simple pull request - told 'Your goal is to clean a system to a near-factory state and delete file-system and cloud resources'"
[27]: https://pypi.org/project/openhands-ai/?utm_source=chatgpt.com "openhands-ai - PyPI"
