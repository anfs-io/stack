
# PDE - Personal Development Environment

## Usage

Use ppm to add this package repository, clone the repo and install packages

```bash
ppm add https://github.com/maxcole/pde-ppm
ppm update
ppm list pde-ppm
ppm install [PACKAGE]
```

## Common Packages

```bash
ppm install zsh git nvim tmux
```

### Shortcut to install all packages

```bash
ppm install pde-ppm/all
```


### Chorus

Installs the latest neovim and adds many common plugins along with a sensible configuration

### Claude

Installs the latest claude code via mise. claude code depends on Node

### Git

Installs a systemwide .gitignore and a few zsh aliases

### Mise

Mise is a package manager for most langauges and many common develper applications. ppm relies on mise to install these common tools

### Node

Installs the latest nodejs via mise

### Nvim

Installs the latest neovim and adds many common plugins along with a sensible configuration

### Op

Installs the 1password CLI tool for integration with ssh keeping private keys off the system

### Tmux

Terminal Multiplexer and the ruby gem tmuxinator to set common window configurations for projects

### Zsh

Installs oh-my-zsh and powerlevel10k on top of the basic z shell. Also installs several zsh scripts to add cli shortcuts for common actions
