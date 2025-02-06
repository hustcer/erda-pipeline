# Changelog
All notable changes to this project will be documented in this file.

## [1.11.0] - 2025-02-06

### Deps

- Upgrade Nushell to v0.102, refactor `compare-ver` common util

## [1.10.0] - 2024-12-06

### Miscellaneous Tasks

- Upgrade `Nushell` to v0.100

## [1.9.0] - 2024-10-06

### Features

- Add query and watch pipeline support

## [1.8.0] - 2024-10-06

### Documentation

- Update README.md

### Features

- Add watch pipeline running status support

### Miscellaneous Tasks

- Always use hustcer/erda-pipeline@v1

### Deps

- Upgrade Nu to v0.98.0 as the shell engine

## [1.7] - 2024-09-16

### Features

- Add `environment` input support
- Make v1 always point to the latest v1.x.x release

## [1.6] - 2024-06-30

### Deps

- Upgrade `actions/checkout` and `Nu` to latest

## [1.5] - 2024-02-07

### Bug Fixes

- Fix Nu module import path error
- Fix release script

### Deps

- Upgrade actions/checkout, setup-nu and Nu version
- Upgrade setup-nu and Nu version

## [1.3] - 2023-11-02

### Bug Fixes

- Fix Nu module import path error

## [1.2] - 2023-10-31

### Bug Fixes

- Try to fix empty response issue

### Miscellaneous Tasks

- Update erda-pipeline action in test workflow

## [1.1] - 2023-10-30

### Bug Fixes

- Hide detail if there is no running pipelines

### Features

- Add .github/workflows/test.yml
- Show more detail of running pipelines

## [1.0.0] - 2023-10-30

### Features

- Add run erda pipeline by workflow support
- Add query erda pipeline support
- Add just task for running and querying erda pipeline

### Refactor

- Remove unnecessary description and environment input
