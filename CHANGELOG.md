# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [0.7.0-beta] - 2026-05-25

### Fixed
- `Span.addEvent` now correctly passes tags to the event; previously tags were silently dropped because `ActivityEvent` is immutable
- Removed `meta.process.command_line` from service tags — it could leak secrets passed as CLI arguments
- `SetResourceBuilder` inside `WithTracing` and `WithMetrics` was duplicating the `ConfigureResource` setup and dropping `host.name`; resource configuration is now handled solely by `ConfigureResource`
- Removed dead `tracerProvider` mutable and `flush()` function — neither had any effect when using the DI-managed provider via `use_otel`
- CI `build-nix` job referenced undefined `eval` dependency; now correctly depends on `flake-check`
- Removed `pkgs.prek` reference from `flake.nix` (package does not exist; `pre-commit-hooks` manages the binary itself)

### Added
- `aarch64-linux` added to supported Nix systems
