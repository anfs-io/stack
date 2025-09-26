---
id: CLAUDE
aliases: []
tags: []
---



- This repository is a custom "package manager" for my personal scripts and "dotfile" configuration
- When I start work on a new machine I will clone this repo and run the install script
- The purpose is to create a standard working environment that is familar to me regardless of the machine I am working on
- The target machines are macOS and debian linux. They may be bare metal or virutal machines

## Main Script
- The main package script is ./install.sh
- Each packages is a subdir in the ./packages dir
- packages are installed by running ./install <package name>
- The script does some checks on repos, etc then invokes the install_packages function on the arguments
- for each package selcted, if the package has an install.sh file it will be sourced
- then the several functions in the package's install.sh script are invoked
- the package manager then invokes GNU stow on the package's home directory if it exists. this is to link the "dotfiles"
- packages typically contain zsh aliases and functions that provide familiar convenience commands for me

## Companion Script
- There is a companion ruby script in ./packages/ruby/home/.local/bin/coder
- The coder script will have many subcommands and is intended to be used to manage content after the packages have been installed
