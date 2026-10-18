# zsh completion for Apple's `container`

Tab completion in zsh for [`container`](https://github.com/apple/container),
Apple's tool for running Linux containers on macOS.

## Features

- **Every subcommand and option** of `container` 1.5.0, with descriptions,
  including nested groups such as `container system dns create`.
- **Aliases** work the same as the full names: `cp`, `rm`, `ls`, and the group
  shortcuts `i` (image), `m` (machine), `n` (network), `r` (registry),
  `s` (system) and `v` (volume).
- **Live values** from the container service, filtered to what makes sense:
  - `stop`, `kill`, `exec`, `stats` and `clean` offer only running containers,
    and `start` only stopped ones; each container is shown with its state and
    image
  - image references for `run`, `create`, `image rm`, `image tag`, `--init-image`
    and so on
  - networks (`--network`), volumes (`-v`), container machines, local DNS
    domains and registry logins
- **Structured arguments**:
  - `container cp`: completing a container inserts `name:` so you can type the
    path inside it; anything else completes local files
  - `-v`: volume names or host paths
  - `--mount`: `type=`, `source=`, `target=`, `readonly`, …
  - `--ulimit`: limit names (`nofile=`, …), then a `soft[:hard]` hint
  - also `--cap-add`/`--cap-drop` capabilities, `kill -s` signals, `-e` exported
    variables, `machine set` keys (`cpus=`, `memory=`, …), and the fixed values
    of `--format`, `--arch`, `--platform` and `--progress`
- **Commands run inside the container**: once you have typed the image in
  `run`/`create`, or the container in `exec`, it stops offering `container`
  options, matching how the CLI passes the rest to the process.
- `container help <command> [<subcommand>]` completes command names.

If the container service isn't running, the live values simply complete
nothing; everything else still works.

### Why not `container --generate-completion-script zsh`?

The generated script lists the options, but container IDs,
images, networks, volumes and most option values complete nothing.

## Installation

### With the installer

```zsh
git clone git@github.com:peturingi/zsh-container-completion.git zsh-container-completion
cd zsh-container-completion
./install.sh
exec zsh
```

| Option              |                                                               |
|---------------------|---------------------------------------------------------------|
| `-d`, `--dir DIR`   | install into `DIR` instead of `~/.zsh/completions`            |
| `-n`, `--no-rc`     | don't touch `~/.zshrc`; you put `DIR` on `fpath` yourself     |
| `-u`, `--uninstall` | remove `_container` and the installer's block from `~/.zshrc` |
| `-h`, `--help`      | show help                                                     |


### Manually

Copy `_container` into any directory on your `fpath`, for example:

```zsh
mkdir -p ~/.zsh/completions
cp _container ~/.zsh/completions/
```

Then put the directory on `fpath` in `~/.zshrc`, **before** `compinit` runs.
If you have [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh), add it before `source $ZSH/oh-my-zsh.sh`:

```zsh
fpath=(~/.zsh/completions $fpath)
source $ZSH/oh-my-zsh.sh        # or: autoload -Uz compinit && compinit
```

Finally, clear the cache and restart the shell:

```zsh
rm -f ~/.zcompdump*
exec zsh
```

With oh-my-zsh you can instead copy `_container` into
`$ZSH_CUSTOM/plugins/container/` and add `container` to `plugins=(...)`, since
oh-my-zsh puts each plugin's directory on `fpath`.

## Updating

Pull the latest version and run `./install.sh` again.

## Uninstalling

```zsh
./install.sh --uninstall
exec zsh
```

If you added the `fpath` line yourself, the uninstaller leaves it in place.

## Troubleshooting

- **Options complete but containers and images don't:** check that the service is
  running with `container system status`, and start it with
  `container system start`.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).

The option names and help text this completion describes come from Apple's
[container](https://github.com/apple/container) project.

This project is not affiliated with Apple.
