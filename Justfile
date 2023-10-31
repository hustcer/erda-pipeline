# Author: hustcer
# Create: 2023/10/29 18:05:20
# Description:
#   Some helper task for erda-pipeline
# Ref:
#   1. https://github.com/casey/just
#   2. https://www.nushell.sh/book/

set shell := ['nu', '-c']

# The export setting causes all just variables
# to be exported as environment variables.

set export := true
set dotenv-load := true

# If positional-arguments is true, recipe arguments will be
# passed as positional arguments to commands. For linewise
# recipes, argument $0 will be the name of the recipe.

set positional-arguments := true

# Just commands aliases
alias r := run
alias q := query

# Use `just --evaluate` to show env vars

# Used to handle the path separator issue
ERDA_PIPELINE_PATH := parent_directory(justfile())
NU_DIR := parent_directory(`(which nu).path.0`)
_query_plugin := if os_family() == 'windows' { 'nu_plugin_query.exe' } else { 'nu_plugin_query' }

# To pass arguments to a dependency, put the dependency
# in parentheses along with the arguments, just like:
# default: (sh-cmd "main")

# List available commands by default
default:
  @just --list --list-prefix "··· "

# Test run erda pipeline locally
run:
  @$'(ansi g)Start `run` task...(ansi reset)'; \
    cd {{ERDA_PIPELINE_PATH}}; \
    overlay use {{ join(ERDA_PIPELINE_PATH, 'nu', 'pipeline.nu') }}; \
    let auth = (get-auth); \
    let args = { action: 'run', pid: 213, appId: 7542, appName: 'Fe-Docs', branch: 'feature/latest', pipeline: 'pipeline.yml' }; \
    erda-deploy $args --auth $auth

# Test query erda pipeline locally
query:
  @$'(ansi g)Start `query` task...(ansi reset)'; \
    cd {{ERDA_PIPELINE_PATH}}; \
    overlay use {{ join(ERDA_PIPELINE_PATH, 'nu', 'pipeline.nu') }}; \
    let auth = (get-auth); \
    let args = { action: 'run', pid: 213, appId: 7542, appName: 'Fe-Docs', branch: 'feature/latest', pipeline: 'pipeline.yml' }; \
    erda-query $args --auth $auth

# Release a new version for `erda-pipeline`
release updateLog=('false'):
  @overlay use {{ join(ERDA_PIPELINE_PATH, 'nu', 'common.nu') }}; \
    overlay use {{ join(ERDA_PIPELINE_PATH, 'nu', 'release.nu') }}; \
    git-check --check-repo=1 {{ERDA_PIPELINE_PATH}}; \
    make-release --update-log {{updateLog}}

# Plugins need to be registered only once after nu v0.61
_setup:
  @register -e json {{ join(NU_DIR, _query_plugin) }}
