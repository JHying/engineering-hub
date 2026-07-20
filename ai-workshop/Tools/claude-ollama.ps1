# claude-ollama.ps1 — Launch Claude Code CLI against a local Ollama model
#
# Purpose:
#   Ollama v0.14+ exposes an Anthropic Messages API-compatible endpoint
#   (/v1/messages), so Claude Code can talk to a local Ollama model instead
#   of Anthropic's API by redirecting ANTHROPIC_BASE_URL.
#   Reference: https://docs.ollama.com/api/anthropic-compatibility
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\Tools\claude-ollama.ps1
#   powershell -ExecutionPolicy Bypass -File .\Tools\claude-ollama.ps1 -Model qwen3-coder
#
# Caveat:
#   Tool calling (file edit, Bash, etc.) is weak or unsupported on most local
#   models, so Claude Code's agentic features may not work reliably except on
#   models documented as tool-capable (e.g. qwen3-coder, glm-4.7:cloud, gpt-oss:20b).
#
#   On CPU-only hosts (no GPU), expect the FIRST response to take many minutes:
#   Claude Code's fixed system-prompt/tool-schema overhead alone runs well into
#   the tens of thousands of tokens, and prefilling that on CPU is slow. Without
#   API_FORCE_IDLE_TIMEOUT=0, Claude Code aborts after 5 minutes of silence and
#   the request fails outright — this script sets it so long local inference at
#   least has a chance to finish instead of being killed.

param(
    [string]$Model
)

$ErrorActionPreference = 'Stop'

$models = docker exec ollama ollama list 2>$null |
    Select-Object -Skip 1 |
    ForEach-Object { ($_ -split '\s+')[0] } |
    Where-Object { $_ }

if (-not $models) {
    Write-Host 'No Ollama models found. Pull one first, e.g.:'
    Write-Host '  docker exec ollama ollama pull qwen3-coder'
    exit 1
}

if (-not $Model) {
    Write-Host 'Available Ollama models:'
    for ($i = 0; $i -lt $models.Count; $i++) {
        Write-Host "  [$i] $($models[$i])"
    }
    $choice = Read-Host 'Select a model number'
    if ($choice -notmatch '^\d+$' -or [int]$choice -ge $models.Count) {
        Write-Host 'Invalid selection.'
        exit 1
    }
    $Model = $models[[int]$choice]
}
elseif ($models -notcontains $Model) {
    Write-Host "Model '$Model' not found locally. Available: $($models -join ', ')"
    exit 1
}

Write-Host "Launching Claude Code with local Ollama model: $Model"
Write-Host '(Tool calling may be limited or unsupported on this model.)'

$env:ANTHROPIC_AUTH_TOKEN   = 'ollama'
$env:ANTHROPIC_BASE_URL     = 'http://localhost:11434'
$env:API_FORCE_IDLE_TIMEOUT = '0'
$env:API_TIMEOUT_MS         = '1800000'

claude --model $Model
