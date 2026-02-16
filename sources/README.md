# Upstream Source Code

This directory ships the upstream source inputs used to build this package so
others can reproduce the iOS build.

## Included archives

- `upstream/Python-3.14.3.tgz` (CPython source)
- `upstream/pip-26.0.1.tar.gz` (pip source)

Verify integrity:

```sh
shasum -a 256 -c SHA256SUMS
```

Extract examples:

```sh
tar -xzf upstream/Python-3.14.3.tgz
tar -xzf upstream/pip-26.0.1.tar.gz
```

## Refresh sources

Run:

```sh
./fetch-sources.sh
```

That script downloads fresh copies from official URLs and rewrites
`SHA256SUMS`.
