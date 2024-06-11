# autocomplete-sh

LLM autocomplete commands in the terminal!  Less `--help` and `man` and more getting stuff done.

It should run only when the default completion returns no results.

- Fix multiple suggestions
- have it work with prefix #
- install to .bashrc and remove it
- read from config
- package and distribute it
- set up github pages to show the README

## Core Tasks

- [x] It should call a language model to generate the completion
- [ ] It should install a bash completion script for all commands
- [ ] It should have a configuration file to specify the language model and API key
- [ ] A CLI to manage the configuration file and install / uninstall the bash completion script

### Context should include

- [x] environment variables
- [x] files
- [x] command history
- [x] help text

### Nice to Haves

- [ ] Caching
- [ ] Support for other shells
- [ ] Support for custom language models
- [ ] previous command outputs and errors
- [ ] Add Security Badge <https://www.bestpractices.dev/en/projects/9056/edit#all>

## File Structure

```

# The script should be placed in
/usr/bin/autocomplete # if apt-get install autocomplete
/usr/local/bin/autocomplete # if installed manually

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
