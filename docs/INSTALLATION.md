# Installation Guide

## Prerequisites

- **Python 3.10+** with pip
- **Git** for cloning the repository
- **Claude Code CLI** installed and configured

Optional:
- **Playwright Chromium** - install.sh attempts this automatically; failure is non-fatal; needed only for SPA rendering and screenshots

## Quick Install

### Plugin Install (Claude Code 1.0.33+)

The recommended path. Inside Claude Code:

```
/plugin marketplace add AgriciDaniel/claude-seo
/plugin install claude-seo@agricidaniel-claude-seo
/seo setup
```

Plugin installation does not run package managers. `/seo setup` is an explicit,
one-time provisioning step that writes the virtual environment and browser only
to Claude's persistent plugin data. Use `/seo doctor` for a read-only check.

### Manual Install (Unix, macOS, Linux)

```bash
git clone --depth 1 https://github.com/AgriciDaniel/claude-seo.git
bash claude-seo/install.sh
```

Review-then-run alternative:

```bash
curl -fsSL https://raw.githubusercontent.com/AgriciDaniel/claude-seo/main/install.sh > install.sh
cat install.sh        # review
bash install.sh       # run when satisfied
rm install.sh
```

### Manual Install (Windows, PowerShell)

```powershell
git clone --depth 1 https://github.com/AgriciDaniel/claude-seo.git
powershell -ExecutionPolicy Bypass -File claude-seo\install.ps1
```

The Windows path uses `git clone` rather than `irm | iex` because Claude Code's own security guardrails flag piped remote-script execution. Inspect `install.ps1` before running.

### One-Command Run From a Source Checkout (Windows)

Install and sign in to the Claude Code CLI, open PowerShell in the cloned repo,
then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-claude-seo.ps1
```

The launcher asks for a website, prepares the isolated dependencies if needed,
loads this repo as a local plugin, and starts an interactive audit. Claude Code
will still ask for permission before using tools. After reviewing the results,
type `/exit` to close Claude Code; the launcher then opens the saved
`{domain}-audit/` folder. To skip the URL prompt, pass `-Url https://example.com`.

## Manual Installation

1. **Clone the repository**

```bash
git clone https://github.com/AgriciDaniel/claude-seo.git
cd claude-seo
```

2. **Run the installer**

```bash
./install.sh
```

3. **Verify the managed runtime**

The installer delegates dependency and Chromium provisioning to the same runtime
used by every skill. It creates `~/.claude/skills/seo/.venv/` and never falls
back to global or user package installation.

```bash
~/.claude/skills/seo/bin/claude-seo doctor
```

If core setup failed, rerun the inspected installer. If only Chromium failed,
the installer reports a degraded result and raw-fetch analysis remains available.

## Installation Paths

The installer copies files to:

| Component | Path |
|-----------|------|
| Main skill | `~/.claude/skills/seo/` |
| Sub-skills | `~/.claude/skills/seo-*/` |
| Subagents | `~/.claude/agents/seo-*.md` |
| Runtime launcher | `~/.claude/skills/seo/bin/claude-seo` |
| Isolated Python | `~/.claude/skills/seo/.venv/` |

## Verify Installation

Claude SEO runs as slash commands inside Claude Code, not directly in PowerShell
or a shell. Open Claude Code from the website project you want to analyze:

```bash
claude
```

For marketplace installs, provision the isolated runtime once. Manual installers
already perform this setup. Then check readiness and run an audit in the Claude
Code prompt:

```text
/seo setup
/seo doctor
/seo audit https://example.com
```

Use `/seo` in the Claude Code prompt to display the command help.

## Uninstallation

If installed as a plugin:

```
/plugin uninstall claude-seo@agricidaniel-claude-seo
/plugin marketplace remove AgriciDaniel/claude-seo
```

If installed manually, run the uninstaller from a fresh clone:

```bash
git clone --depth 1 https://github.com/AgriciDaniel/claude-seo.git
bash claude-seo/uninstall.sh
```

`uninstall.sh` removes all installed sub-skills, sub-agents, and the plugin's MCP entries from `~/.claude/settings.json`. Do not maintain a hand-coded `rm` list. The shipped uninstaller is the canonical source.

## Upgrading

To upgrade to the latest version:

Caution: Prefer downloading, inspecting, then running remote scripts; the pipe-to-shell form below is the less-safe convenience option.

```bash
# Uninstall current version
curl -fsSL https://raw.githubusercontent.com/AgriciDaniel/claude-seo/main/uninstall.sh | bash

# Install new version
curl -fsSL https://raw.githubusercontent.com/AgriciDaniel/claude-seo/main/install.sh | bash
```

## Troubleshooting

### "Skill not found" error

Ensure the skill is installed in the correct location:

```bash
ls ~/.claude/skills/seo/SKILL.md
```

If the file doesn't exist, re-run the installer.

### Python dependency errors

Run the managed setup again:

```bash
~/.claude/skills/seo/bin/claude-seo setup
```

### Playwright screenshot errors

Run the managed setup again and inspect the result:

```bash
~/.claude/skills/seo/bin/claude-seo setup
~/.claude/skills/seo/bin/claude-seo doctor
```

### Permission errors on Unix

Make sure scripts are executable:

```bash
chmod +x ~/.claude/skills/seo/scripts/*.py
```
