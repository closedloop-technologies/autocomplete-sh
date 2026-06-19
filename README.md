Autocomplete.sh
========================================================

## `--help` less, accomplish more: Command your terminal

> Command your terminal with intelligent suggestions

Autocomplete.sh adds AI-powered command-line suggestions directly to your terminal. Type `<TAB><TAB>` and it calls an LLM to return command suggestions based on your shell context.

![Autocomplete.sh Demo](https://github.com/user-attachments/assets/6f2a8f81-49b7-46e9-8005-c8a9dd3fc033)

Use natural language without copying between your terminal and ChatGPT.

## Quick Start

```bash
wget -qO- https://autocomplete.sh/install.sh | bash
```

or:

```bash
curl -fsSL https://autocomplete.sh/install.sh | bash
```

### Zsh

The installer detects zsh, installs the Bash implementation as `autocomplete`, and adds a small zsh shim at `~/.autocomplete/autocomplete.zsh` that registers completion with `compdef`.

```zsh
source ~/.zshrc
```

## Features

- **Context-aware**: Considers terminal state, recent commands, current directory files, and command `--help` output.
- **Current model APIs**: Uses OpenAI's Responses API for current GPT models by default.
- **Flexible providers**: Supports OpenAI, Anthropic, Groq, and Ollama/local models.
- **Structured output**: Requests JSON command arrays and parses provider-specific response formats.
- **Safer prompts**: Redacts common API keys, tokens, UUIDs, and long hashes from command history.
- **Efficient**: Caches recent queries and logs token usage/cost estimates.
- **Portable shell behavior**: Avoids GNU-only `sed -i` and `find -printf` paths in core flows.

## Supported Models

Configure your model with:

```bash
autocomplete model
```

Set a model directly with:

```bash
autocomplete model openai gpt-5.4-mini
autocomplete model openai gpt-5.5
autocomplete model anthropic claude-sonnet-4-6
autocomplete model groq openai/gpt-oss-120b
autocomplete model ollama qwen2.5-coder
```

Default: `openai/gpt-5.4-mini` via `https://api.openai.com/v1/responses`.

Provider environment variables:

```bash
export OPENAI_API_KEY=...
export ANTHROPIC_API_KEY=...
export GROQ_API_KEY=...
```

Ollama runs against `http://localhost:11434/api/chat` and does not require a hosted API key.

![Model Selection](https://github.com/user-attachments/assets/6206963f-81c2-4d68-b054-6ec88969ba0c)

## How It Works

Autocomplete.sh builds a compact prompt from:

- Your current command line
- Current machine and terminal context
- Recently executed commands, with common secrets redacted
- Current directory files
- Command-specific `--help` output when available

View the prompt without calling a model:

```bash
autocomplete command --dry-run "ls # show largest files"
```

Run a one-off suggestion call:

```bash
autocomplete command "ffmpeg # reformat video to fit youtube"
```

## Tips and Tricks

1. For command parameters: `ffmpeg # reformat video to fit youtube`, then `<TAB><TAB>`.
2. For complex tasks: `# create a github repo, init a readme, and push it`, then `<TAB><TAB>`.
3. For local-only usage: run Ollama locally, then `autocomplete model ollama qwen2.5-coder`.

## Configuration

```bash
autocomplete config
```

![Configuration Options](https://github.com/user-attachments/assets/61578f27-594f-4bc4-ba86-c5f99a41e8a9)

Update settings with:

```bash
autocomplete config set <key> <value>
```

Examples:

```bash
autocomplete config set reasoning_effort low
autocomplete config set max_tokens 512
autocomplete config set cache_size 25
autocomplete config set api_key "$OPENAI_API_KEY"
```

`api_key` maps to the active provider, so after `autocomplete model groq openai/gpt-oss-120b`, it stores `groq_api_key`.

## Usage Tracking

```bash
autocomplete usage
```

![Usage Statistics](https://github.com/user-attachments/assets/0fc611b9-fb4c-4f68-bf01-8e6ecdcf7410)

## Use Cases

- **Data engineers**: Manipulate datasets efficiently.
- **Backend developers**: Build, test, and deploy faster.
- **Linux users**: Navigate unfamiliar systems with less documentation hunting.
- **Terminal novices**: Learn by seeing plausible commands in context.
- **Efficiency seekers**: Streamline repetitive shell workflows.
- **Documentation seekers**: Quickly understand command options.

## Development

### Local Installation

```bash
git clone git@github.com:closedloop-technologies/autocomplete-sh.git
cd autocomplete-sh
ln -sf "$PWD/autocomplete.sh" "$HOME/.local/bin/autocomplete"
autocomplete install
```

Install the local development version with:

```bash
./docs/install.sh dev
```

### Testing

```bash
sudo apt install bats shellcheck
./run_tests.sh
```

The Bats tests mock provider responses by default, so they do not require a live OpenAI API call.

### Docker Testing

```bash
docker build -t autocomplete-sh .
docker run --rm autocomplete-sh
```

## Maintainers

Currently maintained by Sean Kruzel [@closedloop](https://github.com/closedloop) at [Closedloop.tech](https://Closedloop.tech).

Contributions and bug fixes are welcome.

## Support Open Source

The best way to support Autocomplete.sh is to use it.

- [Just use it!](https://github.com/closedloop-technologies/autocomplete-sh?tab=readme-ov-file#quick-start)
- [Share it!](https://x.com/intent/post?text=I+love+autocomplete.sh%21++I+just+press+%3CTAB%3E%3CTAB%3E+to+just+build+quickly+%40JustBuild_ai)
- Star it.

If you want to help me keep up the energy to build stuff like this, please:

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/skruzel)

## License

See the [MIT-LICENSE](./LICENSE) file for details.
