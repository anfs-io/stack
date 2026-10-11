# pdt — Product Development Toolkit

An [anfs](https://github.com/anfs-io/system) source, in anfs's default `system.list`:

- `packages/` (ppm): infrastructure and product tooling — packer, opentofu, ansible, utm, solana,
  rust, pcs (the netboot control scripts) and more. `ppm list pdt` shows them all.
- `containers/` (pcm): `dnsmasq` and `netboot`, the PXE services pcs drives.

pcm, podman, varlock and node, which used to live here, are part of anfs now.

```bash
ppm list pdt
ppm install pdt/<package>
pcm install pdt/dnsmasq
```

VM images (building, testing, running them) are `pim`, part of anfs: images/ in any source.
