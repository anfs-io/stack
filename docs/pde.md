
# Personal Package Manager Core Packages

## Usage

- add sources (git repos with a packages subdir) to $HOME/.config/ppm/sources.list

```bash
ppm add https://github.com/maxcole/pdos-core.git'
echo 'https://github.com/maxcole/rjayroach-coder.git' >> $HOME/.config/ppm/sources.list
$HOME/.local/bin/ppm update
```

### Install

- The ppm script iterates over items in sources.list looking for the requested packages to install

```bash
$HOME/.local/bin/ppm install zsh git nvim tmux
$HOME/.local/bin/ppm install mise ruby coder builder
```


### List available packages

```bash
ppm list
```


# Developing
```bash
rm -rf $HOME/.cache/ppm $HOME/.local/bin/ppm
mkdir -p $HOME/.config/ppm $HOME/.local/bin
git clone git@github.com:maxcole/ppm.git $HOME/.cache/ppm
ln -s $HOME/.cache/ppm/ppm $HOME/.local/bin/ppm
echo 'git@github.com:maxcole/ppm-core.git' > $HOME/.config/ppm/sources.list
$HOME/.local/bin/ppm update
```


# Manual Dependencies

- sudo priviledges
