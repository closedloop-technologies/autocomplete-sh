Autocomplete.sh
========================================================

## `--help` less, accomplish more: Command your terminal

> Command your terminal with intelligent suggestions

Autocomplete.sh brings AI-powered command-line suggestions to your terminal. Press `<TAB>` (or `<TAB><TAB>`) and you get your shell's own native completions — fast, provider-free, and never an LLM call. When you want an AI to compose a command, ask for it explicitly:

```bash
autocomplete command "reformat this video to fit youtube"
```

![Autocomplete.sh Demo](https://github.com/user-attachments/assets/6f2a8f81-49b7-46e9-8005-c8a9dd3fc033)

Use natural language without copying between CoPilot or ChatGPT

## Quick Start

Download the installer, then run it for your shell:

`$HOME/.local/bin` must already be in `PATH`. If it is not, run:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

```bash
wget -O install.sh https://autocomplete.sh/install.sh
bash install.sh --shell bash --version main   # or: --shell zsh
```

The installer places the `autocomplete` command at `$HOME/.local/bin/autocomplete` and sets up your shell. Start a new shell (or `source ~/.bashrc` / `source ~/.zshrc`): Tab completion is live immediately, and AI suggestions are one explicit action away —

```bash
autocomplete command "list the files here, largest first"
```

Choose a provider — OpenAI, Groq, Anthropic, Ollama, or any OpenAI-compatible endpoint — with:

```bash
autocomplete model
```

## Features

- **Native Tab**: `<TAB>` / `<TAB><TAB>` use your shell's built-in completion. Provider-free, offline, instant — no LLM involved.
- **Context-Aware**: Opt-in terminal state, environment variable names, recent commands, recent files, and `--help` output — every section off by default.
- **Flexible**: Supports various LLM models, from fast and cheap to powerful, plus any OpenAI-compatible endpoint.
- **Secure**: Enables local LLMs and sanitizes prompts for sensitive information.
- **Efficient**: Caches recent requests for speed and convenience.
- **Cost-Effective**: Monitors API call sizes and costs.

## Supported Models

We support OpenAI, Groq, Anthropic, and Ollama — plus any server that speaks the OpenAI Chat Completions API. Configure your model with:

```bash
autocomplete model
```

![Model Selection](https://github.com/user-attachments/assets/6206963f-81c2-4d68-b054-6ec88969ba0c)

## How It Works

`<TAB>` stays 100% shell-native; AI suggestions always require an explicit action. Bash and Zsh support `autocomplete command "…"`, while Bash also provides non-executing `ai-complete` and `ai-rewrite` actions for the live command line. Each request builds a prompt containing your shell, its mode, and your input — plus any context sections you enabled:

- Your machine's environment — sorted variable *names* only, never values
- Recently executed commands — with secrets redacted
- Current directory contents — file basenames only
- Command-specific help — `--help` output of the first command in your request

Preview the exact prompt, network-free:

```bash
autocomplete command --dry-run "your command here"
```

### Bash-only live-line AI actions

Bash users can request a numbered preview without executing a suggestion or changing the live command line:

```bash
autocomplete ai-complete "git ch"          # prefix-preserving completion
autocomplete ai-rewrite "show failed units" # whole-line rewrite
autocomplete context --mode ai-completion "git ch"
```

The default Readline bindings are <kbd>Ctrl-X Ctrl-A</kbd> for completion and <kbd>Ctrl-X Ctrl-B</kbd> for rewrite. Override `ACSH_AI_COMPLETE_KEY` or `ACSH_AI_REWRITE_KEY` before sourcing `autocomplete.sh`; set either variable to an empty string to disable that binding. These commands and bindings are Bash-only. Zsh continues to use `autocomplete command "…"`.

## Tips and Tricks

1. For command parameters: `autocomplete command "reformat video to fit youtube"`
2. For complex tasks: `autocomplete command "create a github repo, init a readme, and push it"`

## Configuration

```bash
autocomplete config              # view current settings
autocomplete config set <key> <value>
```

![Configuration Options](https://github.com/user-attachments/assets/61578f27-594f-4bc4-ba86-c5f99a41e8a9)

### Context — every section is opt-in and off by default

The base prompt always contains only the mode, your active shell, your input, and output instructions. A context section is appended only when its switch is `true` **and** the bounded helper produced something to include.

| Key | Default | What a request would include |
|---|---|---|
| `context_terminal` | `false` | Physical working directory, OS type, shell, terminal type — never username, hostname, or home |
| `context_environment` | `false` | Sorted environment variable names only (never values; `ACSH_*` excluded) |
| `context_history` | `false` | Recently run commands, with API keys, tokens, secrets, passwords, and `Authorization: Bearer …` redacted |
| `context_recent_files` | `false` | Current-directory file basenames only — no absolute paths, owners, or permissions |
| `context_help` | `false` | `--help` output of the first executable in your request (aliases, functions, and builtins are skipped) |

Section bounds: `max_environment_names` 50, `max_history_commands` 10, `max_recent_files` 10, `max_help_lines` 40, `help_timeout_seconds` 0.25.

Enable a section and see exactly what a request would send:

```bash
autocomplete config set context_history true
autocomplete command --dry-run "your command here"
```

### Providers

Support for OpenAI, Groq, Anthropic, and Ollama is built in. The `openai-compatible` provider targets any local or remote server that implements the OpenAI Chat Completions API — no product-specific endpoint required. A generic local example:

```bash
autocomplete config set provider openai-compatible
autocomplete config set endpoint http://localhost:8080/v1/chat/completions
autocomplete config set model your-model-name
autocomplete config set request_timeout_seconds 5
autocomplete config set extra_body_json '{"chat_template_kwargs":{"enable_thinking":false}}'
```

`openai_compatible_api_key` may be left empty: the `Authorization` header is then omitted, so keyless local endpoints work as-is. Set it (or export `OPENAI_COMPATIBLE_API_KEY`) to send `Authorization: Bearer …`.

Notes:

- `request_headers_json` and `extra_body_json` apply only with the `openai-compatible` provider; non-default values with any other provider are a configuration error.
- `extra_body_json` is merged into the request body before the completion schema is applied, so it can add fields such as `max_tokens` or `chat_template_kwargs`. The reserved keys `model`, `messages`, `tools`, `tool_choice`, `response_format`, and `stream` are rejected.
- `Authorization` and `Content-Type` are managed for you and cannot be overridden in `request_headers_json`.
- `request_timeout_seconds` (default `5`) bounds each provider request.

## Usage Tracking

```bash
autocomplete usage
```

![Usage Statistics](https://github.com/user-attachments/assets/0fc611b9-fb4c-4f68-bf01-8e6ecdcf7410)

## Use Cases

- **Data Engineers**: Manipulate datasets efficiently
- **Backend Developers**: Deploy updates swiftly
- **Linux Users**: Navigate systems seamlessly
- **Terminal Novices**: Build command-line confidence
- **Efficiency Seekers**: Streamline repetitive tasks
- **Documentation Seekers**: Quickly understand commands

## Development

### Local Installation

Install your local checkout with the installer:

```bash
git clone git@github.com:closedloop-technologies/autocomplete-sh.git
cd autocomplete-sh
./docs/install.sh --shell bash --version dev   # or: --shell zsh
```

This installs the local script to `$HOME/.local/bin/autocomplete` and registers it in your shell.

### Testing

```bash
sudo apt install bats
bats tests
```

### Docker Testing

```bash
docker build -t autocomplete-sh .
docker run --rm autocomplete-sh
```

## Maintainers

Currently maintained by Sean Kruzel [@closedloop](https://github.com/closedloop) at [Closedloop.tech](https://Closedloop.tech)

Contributions and bug fixes are welcome!

## Support Open Source

The best way to support Autocomplete.sh is to just use it!

- [Just use it!](https://github.com/closedloop-technologies/autocomplete-sh?tab=readme-ov-file#quick-start)
- [Share it!](https://x.com/intent/post?text=I+love+autocomplete.sh%21++%22autocomplete+command%22+helps+me+build+quickly+%40JustBuild_ai)
- Star it!

If you want to help me keep up the energy to build stuff like this, please:

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/skruzel)

## License

See the [MIT-LICENSE](./LICENSE) file for details.
