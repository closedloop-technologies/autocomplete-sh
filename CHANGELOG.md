# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]


## [v0.5.0] - 2025-02-26

### Added
- Added Zsh support to the autocomplete script.

## [v0.4.4] - 2025-02-26

### Changed
- Replaced `exit` with `return` in `error_exit` for safer handling in completion contexts.
- Improved error handling by preferring `echo_error` over `error_exit`.
- Formatted help message with a heredoc.
- Added custom API key mapping for OLLAMA.
- Added a non-interactive option to `remove_command`.

## [v0.4.3] - 2025-02-26

### Changed
- Bumped `ACSH_VERSION` to 0.4.3.

## [v0.4.2] - 2025-02-26

### Added
- Added glitch animation to copied text and a copy button on the landing page.
- Added titles to iframe elements for accessibility.
- Added a fallback alert when `glitchElement` is not found.

### Changed
- Rewrote the `copyToClipboard` function for better UX.
- Renamed the configuration section to "Supported Language Models".
- Improved landing-page layout, styling, and terminology.

### Fixed
- Fixed clipboard copy when `navigator.clipboard` is missing.
- Fixed the install-command-button selector.
- Fixed the API key check to exclude the OLLAMA provider.

### Removed
- Removed redundant background color classes.

### Docs
- Expanded `USAGE.md` with detailed command examples.
- Added development-version install instructions and landing-page imagery.

## [v0.4.1] - 2024-07-22

### Changed
- Added a warning for potential false-negative status results.

## [v0.4.0] - 2024-07-22

### Added
- Added a BATS test framework and test suite for `autocomplete.sh`.
- Added support for multiple API keys and providers; `model_command` now takes a provider and model name.
- Added a Docker image for testing the install.

### Changed
- Added a `-y` flag to `remove_command` for non-interactive removal.
- Updated the Dockerfile entrypoint to separate the BATS command and test directory.
- Allowed specifying a branch or version in `docs/install.sh`.

### Infrastructure
- Added curl, jq, and bash-completion to the Docker image.

## [v0.3.4] - 2024-07-22

### Fixed
- Install script now sources `.bashrc` to correctly detect `bash_completion`.

## [v0.3.3] - 2024-07-22

### Changed
- Switched `install.sh` to `type -t` instead of `command -v` for checking `_init_completion`.

### Infrastructure
- Added jq and bash-completion to the Docker image.
- Added install-time checks for jq and bash-completion.

## [v0.3.2] - 2024-07-22

### Added
- Added a Dockerfile to create a Docker image for the project.

### Changed
- Improved `autocomplete.sh` install messages and set a default install location of `/usr/local/bin`.

### Docs
- Added instructions for testing the installation with Docker.

## [v0.3.1] - 2024-07-18

### Added
- Added the `gpt-4o-mini` model to the autocomplete model list.

## [v0.3.0] - 2024-07-17

### Added
- Added support for multiple AI providers and models, including OLLAMA, Groq, and dynamic API key assignment.
- Added the ability to set model and endpoint configuration.
- Added Google Analytics, GitHub repo link, and a basic logo to the landing page.

### Changed
- Refactored payload building and response handling for provider-specific flows.
- Refactored `config_command` into `set_config` for readability.
- Updated the help message to include the `model` command.

### Fixed
- Fixed `check_if_enabled`.
- Fixed the API key check to exclude the OLLAMA provider.
- Fixed sorting of model keys in `model_command`.

## [v0.2.7b] - 2024-06-13

### Changed
- Improved `install.sh` and the config enabled status.

### Fixed
- Fixed config enabled status reporting.

## [v0.2.6b] - 2024-06-13

### Fixed
- Fixed a `read` syntax error.

## [v0.2.6] - 2024-06-13

### Changed
- Bumped the version.

## [v0.2.5] - 2024-06-13

### Fixed
- Fixed password input not prompting from the install script.

## [v0.2.4] - 2024-06-13

### Added
- Added an MVP landing page with GitHub Pages configuration.

### Changed
- Rewrote the README and development install scripts; formatted the config file.

### Fixed
- Improved the security of command history handling.

## [v0.2.3] - 2024-06-12

### Changed
- Bumped the version with minor changes.

## [v0.2.2] - 2024-06-12

### Changed
- Improved the CLI and cleaned up configuration.
- Cleaned up unused config variables and improved echo output.

### Fixed
- Fixed a usage CLI error when the logfile was missing.

## [v0.2.1] - 2024-06-12

### Changed
- Bumped the version in the install file.

## [v0.2.0] - 2024-06-12

### Added
- Added a `set key value` command to the CLI.
- Added usage and logging.
- Added config and install files.

### Changed
- Redacted the API key from output.

## [v0.1.0] - 2024-06-11

### Added
- Initial release: a bash completion script that calls OpenAI.
- Added CLI commands, function-calling API, caching, and retry logic.
- Added command history and shell environment variable support.

[Unreleased]: https://github.com/klarrimore/autocomplete-sh/compare/v0.5.0...HEAD
[v0.5.0]: https://github.com/klarrimore/autocomplete-sh/compare/v0.4.4...v0.5.0
[v0.4.4]: https://github.com/klarrimore/autocomplete-sh/compare/v0.4.3...v0.4.4
[v0.4.3]: https://github.com/klarrimore/autocomplete-sh/compare/v0.4.2...v0.4.3
[v0.4.2]: https://github.com/klarrimore/autocomplete-sh/compare/v0.4.1...v0.4.2
[v0.4.1]: https://github.com/klarrimore/autocomplete-sh/compare/v0.4.0...v0.4.1
[v0.4.0]: https://github.com/klarrimore/autocomplete-sh/compare/v0.3.4...v0.4.0
[v0.3.4]: https://github.com/klarrimore/autocomplete-sh/compare/v0.3.3...v0.3.4
[v0.3.3]: https://github.com/klarrimore/autocomplete-sh/compare/v0.3.2...v0.3.3
[v0.3.2]: https://github.com/klarrimore/autocomplete-sh/compare/v0.3.1...v0.3.2
[v0.3.1]: https://github.com/klarrimore/autocomplete-sh/compare/v0.3.0...v0.3.1
[v0.3.0]: https://github.com/klarrimore/autocomplete-sh/compare/v0.2.7b...v0.3.0
[v0.2.7b]: https://github.com/klarrimore/autocomplete-sh/compare/v0.2.6b...v0.2.7b
[v0.2.6b]: https://github.com/klarrimore/autocomplete-sh/compare/v0.2.6...v0.2.6b
[v0.2.6]: https://github.com/klarrimore/autocomplete-sh/compare/v0.2.5...v0.2.6
[v0.2.5]: https://github.com/klarrimore/autocomplete-sh/compare/v0.2.4...v0.2.5
[v0.2.4]: https://github.com/klarrimore/autocomplete-sh/compare/v0.2.3...v0.2.4
[v0.2.3]: https://github.com/klarrimore/autocomplete-sh/compare/v0.2.2...v0.2.3
[v0.2.2]: https://github.com/klarrimore/autocomplete-sh/compare/v0.2.1...v0.2.2
[v0.2.1]: https://github.com/klarrimore/autocomplete-sh/compare/v0.2.0...v0.2.1
[v0.2.0]: https://github.com/klarrimore/autocomplete-sh/compare/v0.1.0...v0.2.0
[v0.1.0]: https://github.com/klarrimore/autocomplete-sh/releases/tag/v0.1.0
