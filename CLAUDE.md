# PDE-PPM

PPM package repository for personal development environment setup.

## Structure

All packages follow the same pattern: `packages/<name>/install.sh` with optional `home/` directory for stow.

```bash
# Check any package's dependencies
grep -A2 "dependencies()" packages/*/install.sh
```
