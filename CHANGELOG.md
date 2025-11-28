# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-XX-XX

### Added

- Initial release
- Core tracing: `Langfuse.trace/1`, `Langfuse.span/2`, `Langfuse.generation/2`, `Langfuse.event/2`
- Scoring: `Langfuse.score/2` with numeric, categorical, and boolean support
- Sessions: `Langfuse.Session` for grouping related traces
- Prompts: `Langfuse.Prompt` for fetching, caching, and compiling prompts
- Client API: `Langfuse.Client` for datasets, score configs, and management
- Async batching with `Langfuse.Ingestion` GenServer
- Telemetry events for observability
- Graceful shutdown with pending event flush
