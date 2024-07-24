Autocomplete.sh
========================================================

## `--help` less, accomplish more: Command your terminal

> Command your terminal with intelligent suggestions

Autocomplete.sh adds AI-powered command-line suggestions directly to your terminal. Just type `<TAB><TAB>` and it calls an LLM (OpenAI by default) to return the top suggestions for you.

![Autocomplete.sh Demo](https://github.com/user-attachments/assets/6f2a8f81-49b7-46e9-8005-c8a9dd3fc033)

Use natural language without copying between CoPilot or ChatGPT

## Quick Start

```bash
wget -qO- https://autocomplete.sh/install.sh | bash
```

## Features

- **Context-Aware**: Considers terminal state, recent commands, and `--help` information
- **Flexible**: Supports various LLM models, from fast and cheap to powerful
- **Secure**: Enables local LLMs and sanitizes prompts for sensitive information
- **Efficient**: Caches recent queries for speed and convenience
- **Cost-Effective**: Monitors API call sizes and costs

## Supported Models

We support OpenAI, Groq, Anthropic, and Ollama models. Configure your model with:

```bash
autocomplete model
```

![Model Selection](https://github.com/user-attachments/assets/6206963f-81c2-4d68-b054-6ec88969ba0c)

## How It Works

Autocomplete.sh provides faster, more accurate suggestions by considering:

- Your machine's environment
- Recently executed commands
- Current directory contents
- Command-specific help information

View the full prompt with:

```bash
autocomplete command --dry-run "your command here"
```

## Tips and Tricks

1. For command parameters: `ffmpeg # reformat video to fit youtube` then `<TAB><TAB>`
2. For complex tasks: `# create a github repo, init a readme, and push it` then `<TAB><TAB>`

## Configuration

```bash
source autocomplete config
```

![Configuration Options](https://github.com/user-attachments/assets/61578f27-594f-4bc4-ba86-c5f99a41e8a9)

Update settings with:

```bash
autocomplete config set <key> <value>
```

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

```bash
git clone git@github.com:closedloop-technologies/autocomplete-sh.git
ln -s $PWD/autocomplete.sh $HOME/.local/bin/autocomplete
. autocomplete.sh install
```

### Testing

```bash
sudo apt install bats
bats tests
```

### Docker Testing

```bash
docker build -t autocomplete-sh .
docker run --rm -e OPENAI_API_KEY=$OPENAI_API_KEY autocomplete-sh
```

## Maintainers

Currently maintained by Sean Kruzel [@closedloop](https://github.com/closedloop) at [Closedloop.tech](https://Closedloop.tech)

Contributions and bug fixes are welcome!

## Support Open Source

The best way to support Autocomplete.sh is to just use it!

* [Just use it!](https://github.com/closedloop-technologies/autocomplete-sh?tab=readme-ov-file#quick%20start)
* [Share it!](https://x.com/intent/post?text=I+love+autocomplete.sh%21++I+just+press+%3CTAB%3E%3CTAB%3E+to+use+build+quickly+%40justbuild_ai)
* Star it! 

If you want to help me keep up the energy to build stuff like this, please:

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/skruzel)

## License

See the [MIT-LICENSE](./LICENSE) file for details.
