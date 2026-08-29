# Portability verification notes

## Verified upstream packaging facts

- OpenCode publishes Linux musl packages such as `opencode-linux-x64-musl` and `opencode-linux-arm64-musl`.
- Official Node.js release directories currently publish Linux x64 musl archives, but the standard portable Node.js release set does not provide a Linux ARM64 musl archive.
- Therefore this portable launcher supports musl Linux x64 and explicitly rejects musl Linux ARM64 instead of attempting a nonexistent Node.js download.

## Test policy

A release should be tested on:

1. Windows x64
2. Windows ARM64 where available
3. Linux x64 glibc
4. Linux ARM64 glibc
5. Linux x64 musl
6. A USB filesystem with `noexec` enabled to verify the diagnostic path

Static syntax checks are not a substitute for running the launcher on real target systems.
