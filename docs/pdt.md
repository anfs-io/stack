# pdt — Product Development Toolkit

The `pdt` category of [stack](../README.md), an anfs default source:

- packages (ppm) that declare `categories: [pdt]`: infrastructure and product tooling — packer,
  opentofu, ansible, utm, solana, rust, pcs (the netboot control scripts) and more.
  `ppm list @pdt` shows them all.
- containers (pcm): `dnsmasq` and `netboot`, the PXE services pcs drives, in stack's `containers/`.

pcm, podman, varlock and node, which used to live here, are part of anfs now.

```bash
ppm list @pdt
ppm install @pdt          # every pdt package
ppm install <package>
pcm install dnsmasq
```

VM images (building, testing, running them) are `pim`, part of anfs: images/ in any source.
