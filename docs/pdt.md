# pdt — Product Development Toolkit

The `pdt` category of [stack](../README.md), an anfs default source:

- packages (ppm) that declare `categories: [pdt]`: infrastructure and product tooling —
  opentofu, ansible, solana, rust, pcs (the netboot control scripts) and more.
  `ppm list @pdt` shows them all.
- containers (pcm): `dnsmasq` and `netboot`, the PXE services pcs drives, in stack's `containers/`.

pcm, podman, varlock and node, which used to live here, are part of anfs now.

```bash
ppm list @pdt
ppm install @pdt          # every pdt package
ppm install <package>
pcm install dnsmasq
```

Machines and the images they run from (building, testing, running them) are `pmm`, part of anfs:
`machines/` in any source, with the images in `machines/images/`.
