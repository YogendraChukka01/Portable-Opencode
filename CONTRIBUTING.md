# Contributing to Portable-Opencode

Thank you for considering contributing!

## Getting Started

1. Fork the repository
2. Clone your fork
3. Create a branch: `git checkout -b fix/amazing-fix`
4. Make your changes
5. Test on both Windows and Linux if possible
6. Submit a Pull Request

## Testing

- **Windows**: Run `opencode.bat --version` on a USB drive
- **Linux**: Run `./opencode.sh --version` on a USB drive

## Guidelines

- Keep scripts compatible with Windows Batch and POSIX Bash
- Test checksum verification changes carefully
- Document any new environment variables in the README
