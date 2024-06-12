# autocomplete-sh

LLM autocomplete commands in the terminal!  

Less `--help`, `man` and searching, more getting stuff done.

It should run only when the default completion returns no results.

- install to .bashrc and remove it
- read from config
- package and distribute it
- set up github pages to show the README

## Usage

```bash
autocomplete --help
```

### Example

```bash
ffmpeg "make a video from images"<TAB><TAB>
```

```bash
! "run the last command"<TAB><TAB>
```

```bash


## Core Tasks

- [x] It should call a language model to generate the completion
- [x] It should install a bash completion script for all commands
- [x] It should have a configuration file to specify the language model and API key
- [x] A CLI to manage the configuration file and install / uninstall the bash completion script

### Context should include

- [x] environment variables
- [x] files
- [x] command history
- [x] help text

### Nice to Haves

- [x] Caching
- [ ] Support for other shells
- [ ] Support for custom language models
- [ ] previous command outputs and errors
- [ ] Add Security Badge <https://www.bestpractices.dev/en/projects/9056/edit#all>

## File Structure

```

# The script should be placed in
/usr/local/bin/autocomplete # if installed manually
<!-- /usr/bin/autocomplete # if apt-get install autocomplete -->


# Configuration Files
~/.autocomplete/config
~/.autocomplete/cache/...
```

## Inspiration

<https://github.com/nvm-sh/nvm/tree/master>

## Maintainers

Currently maintained by Sean Kruzel [@closedloop](https://github.com/closedloop) as a member of [Closedloop.tech](https://Closedloop.tech)

More maintainers and bug fixers are quite welcome, and we hope to grow the community around this project.
Governance will be re-evaluated as the project evolves.

## License

See the [LICENSE](./LICENSE) file for details.


## Development



Pre Commit Hooks

    pip install pre-commit
    pre-commit install

Tests

    sudo apt install bats
    bats tests

# Tests to run
- [ ] install             Install the autocomplete script from .bashrc
- [ ] remove              Remove the autocomplete script from .bashrc
- [ ] info                Displays status and config values
- [ ] system              Displays system information
- [ ] config set <key> <value>  Set a configuration value
- [ ] enable              Enable the autocomplete script
- [ ] disable             Disable the autocomplete script
- [ ] command             Run the autocomplete command
- [ ] command --dry-run   Only show the prompt without running the command
- [ ] command --explain   Show the explanation for the command