# Autocomplete.sh Usage

> Ordinary `<TAB>` (and `<TAB><TAB>`) completion is **shell-native and provider-free** — it uses your shell's built-in completion and never calls an LLM. AI-powered suggestions always require an explicit action; `autocomplete command "…"` works in Bash and Zsh.

1. **Display Help Information**

   ```bash
   autocomplete --help
   ```

   *Check that the help text is clear and lists all available commands.*

2. **Install the Script**

   For a fresh install, download and run the installer for your shell:

   `$HOME/.local/bin` must already be in `PATH`. If it is not, add it before installing:

   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   ```

   ```bash
   wget -O install.sh https://autocomplete.sh/install.sh
   bash install.sh --shell bash --version main   # or: --shell zsh
   ```

   From a local checkout, install your development version the same way:

   ```bash
   ./docs/install.sh --shell bash --version dev   # or: --shell zsh
   ```

   Either way the `autocomplete` command lands at `$HOME/.local/bin/autocomplete` and the managed startup block is registered in `~/.bashrc` (Bash) or `~/.zshrc` (Zsh).

   If the `autocomplete` command is already on your PATH, registering the shell hooks in place works too:

   ```bash
   autocomplete install
   ```

3. **Reload Your Shell**

   ```bash
   source ~/.bashrc
   ```

   *Reload your bash configuration to activate Autocomplete.sh (or start a new shell).*

4. **Show Current Configuration**

   ```bash
   autocomplete config
   ```

   *Verify that your configuration (provider, model, endpoint, context switches, API key status, etc.) is loaded correctly.*

5. **Update a Configuration Value**

   ```bash
   autocomplete config set temperature 0.5
   ```

   *Change the temperature setting to test the config update and then run `autocomplete config` again to confirm the change.*

   *Context sections are opt-in and off by default — enable one the same way:*

   ```bash
   autocomplete config set context_history true
   ```

### Context — every section is opt-in and off by default

The base prompt always contains only the mode, your active shell, your input, and output instructions. A context section is appended only when its switch is `true` **and** the bounded helper produced something to include.

| Key | Default | What a request would include |
|---|---|---|
| `context_terminal` | `false` | Physical working directory, OS type, shell, terminal type — never username, hostname, or home |
| `context_environment` | `false` | Sorted environment variable names only (never values; `ACSH_*` excluded) |
| `context_history` | `false` | Recently run commands, with API keys, tokens, secrets, passwords, and `Authorization: Bearer …` redacted |
| `context_recent_files` | `false` | Current-directory file basenames only — no absolute paths, owners, or permissions |
| `context_help` | `false` | `--help` output of the first executable in your request (aliases, functions, and builtins are skipped) |

Section bounds: `max_environment_names=50`, `max_history_commands=10`, `max_recent_files=10`, `max_help_lines=40`, and `help_timeout_seconds=0.25`.

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

### Requests

- `request_headers_json` and `extra_body_json` apply only with the `openai-compatible` provider; non-default values with any other provider are a configuration error.
- `extra_body_json` is merged into the request body before the completion schema is applied, so it can add fields such as `max_tokens` or `chat_template_kwargs`. The reserved keys `model`, `messages`, `tools`, `tool_choice`, `response_format`, and `stream` are rejected.
- `Authorization` and `Content-Type` are managed by the client and cannot be overridden in `request_headers_json`.
- `request_timeout_seconds` (default `5`) bounds each provider request to five seconds.

6. **Display Usage Statistics**

   ```bash
   autocomplete usage
   ```

   *View log and cost metrics as well as cache information.*

7. **Display System Information**

   ```bash
   autocomplete system
   ```

   *Ensure that system and terminal details are being reported correctly (independent of AI context).*

8. **Inspect an AI Prompt (Dry Run — network-free)**

   ```bash
   autocomplete command --dry-run "reformat video to fit youtube"
   ```

   *Prints the exact prompt that would be sent — mode, active shell, your input, output instructions, plus any enabled context sections. No HTTP request is made, so it works fully offline.*

9. **Ask an AI for Suggestions**

   ```bash
   autocomplete command "reformat video to fit youtube"
   ```

   *Sends one bounded request to the configured provider, validates the response, and prints up to five suggested commands. Results are cached per query (`acsh-v1-*.txt`).*

### Bash-only live-line AI actions

Bash additionally provides explicit completion and rewrite previews:

```bash
autocomplete ai-complete "git ch"
autocomplete ai-rewrite "show failed units"
autocomplete context --mode ai-rewrite "show failed units"
```

`ai-complete` preserves the typed prefix; `ai-rewrite` proposes whole-line alternatives. Both print numbered previews and never execute a suggestion or modify the live line. Their default Readline bindings are <kbd>Ctrl-X Ctrl-A</kbd> and <kbd>Ctrl-X Ctrl-B</kbd>. Set `ACSH_AI_COMPLETE_KEY` or `ACSH_AI_REWRITE_KEY` before sourcing `autocomplete.sh` to choose another Readline sequence, or set either variable to an empty string to disable that binding. Zsh supports the cross-shell `autocomplete command "…"` interface instead.

10. **Interact with the Model Selection Menu**

    ```bash
    autocomplete model
    ```

    *This will open an interactive menu — use your arrow keys to navigate and press Enter to select a model (or press "q" to cancel). Includes OpenAI-compatible endpoints.*

11. **Disable Autocomplete**

    ```bash
    autocomplete disable
    ```

    *Removes Autocomplete's Tab registration, so `<TAB>` falls back to your shell's default completion. Explicit `autocomplete command "…"` calls still work.*

12. **Enable Autocomplete**

    ```bash
    autocomplete enable
    ```

    *Re-registers Tab completion and the CLI word-completion, and verifies that it is active.*

13. **Clear Cache and Logs**

    ```bash
    autocomplete clear
    ```

    *This will purge cached completions and log data — confirm the action when prompted.*

14. **Remove the Installation**

    ```bash
    autocomplete remove
    ```

    *Clean up by removing the configuration, cache, log files, the startup block, and the script — confirm the action when prompted.*

Running these commands sequentially (or in various orders to simulate different user scenarios) will help you put the script through its paces and ensure that all functionality works as expected.

### Example queries

Tab is native-only; when you want AI suggestions, use the explicit `autocomplete command "…"` interface with natural language:

#### Data Engineer

1. `autocomplete command "Hey, what files are hanging around in this folder?"`
2. `autocomplete command "Yo, can you pull out the first column from that CSV and find entries with a specific keyword?"`
3. `autocomplete command "Can you fire up Spark on that dataset and point it to where it needs to go?"`
4. `autocomplete command "Merge those CSV files based on that common column and save the result somewhere."`

#### Backend Developer

1. `autocomplete command "Yo, let's kickstart a new Git repo right here."`
2. `autocomplete command "Compile this C code into a usable program, please."`
3. `autocomplete command "Hey, could you run those tests we've got lying around?"`
4. `autocomplete command "Build that Docker image and let's spin it up on port 8080."`

#### Linux User

1. `autocomplete command "What's hogging all the resources on my system right now?"`
2. `autocomplete command "Can you hook me up with that package using APT?"`
3. `autocomplete command "Let's make sure this script is ready to roll by tweaking its permissions."`
4. `autocomplete command "Fire up that service we've been talking about."`

#### Terminal Novice

1. `autocomplete command "Take me to that other folder, please."`
2. `autocomplete command "Can we create a new file with this name?"`
3. `autocomplete command "Can you copy this file over to that place?"`
4. `autocomplete command "What's inside this file? Show me."`

#### Efficiency Seeker

1. `autocomplete command "Can you swap out that text across all these files at once?"`
2. `autocomplete command "Bundle up this directory into a nice little package, would you?"`
3. `autocomplete command "Let's open up that compressed file and see what's inside."`
4. `autocomplete command "Hey, can you find all instances of this word in that file and count them?"`

#### Documentation Seeker

1. `autocomplete command "Can you tell me more about how this command works?"`
2. `autocomplete command "I'm looking for something related to this keyword; got any leads?"`
3. `autocomplete command "Give me a hand understanding these built-in shell commands, please."`
4. `autocomplete command "Show me everything we've got installed, especially that package."`
