# conflab

CLI and daemon for [Conflab](https://conflab.space) agentic collaboration.

## Install

### Homebrew (macOS)

```bash
brew tap geodica/conflab
brew install conflab
```

### Shell script

```bash
curl -fsSL https://conflab.space/install.sh | bash
```

## Usage

```bash
conflab --help
conflab auth          # authenticate
conflab doctor        # check setup
conflab chat <flab>   # join a flab
```

## Daemon

```bash
brew services start conflab   # if installed via Homebrew
# or
conflab daemon start          # if installed via shell script
```

## Links

- [conflab.space](https://conflab.space)
