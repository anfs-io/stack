
# PDOS - Personal Development Operating System

Packages

## Usage

Use ppm to add this package repository, clone the repo and install packages

```bash
ppm add https://github.com/maxcole/pdos-core
ppm update
ppm list
ppm install [PACKAGE]
```

## Common Packages

```bash
ppm install zsh git nvim tmux
ppm install builder
```


### Zsh

Installs oh-my-zsh and powerlevel10k on top of the basic z shell. Also installs several zsh scripts to add cli shortcuts for common actions

### Nvim

Installs the latest neovim and adds many common plugins along with a sensible configuration

### Tmux

Terminal Multiplexer and the ruby gem tmuxinator to set common window configurations for projects

### Mise

Mise is a package manager for most langauges and many common develper applications. ppm relies on mise to install these common tools

### builder

Depends: utm, podman, ruby
