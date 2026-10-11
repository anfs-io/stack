# stack

The anfs-io packages (ppm), containers (pcm) and skills (psm), in one anfs source. The toolkit and
its conventions are in the `core` source (anfs-io/system): read its CLAUDE.md for how packages,
layering, hooks and declared software work.

## Structure

```
packages/<name>/     package.yml (required), optional install.sh and home/ (stowed to $HOME)
containers/<name>/   pcm
skills/<name>/       psm
docs/<category>.md   what each category holds
```

Packages are flat. A package's groups are `categories: [...]` in its package.yml (ai, pde, pdt,
utils); a new category needs no directory, only packages that declare it. `depends:` uses bare
names.
