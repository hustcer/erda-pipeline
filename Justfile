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

# Test action locally
run:
  @$'(ansi g)Start `run` task...(ansi reset)'; \
  cd {{ERDA_PIPELINE_PATH}}; \
  $env.RUNNER_TEMP = './runner/temp'; \
  $env.RUNNER_TOOL_CACHE = './runner/cache'; \
  nu nu/main.nu

# Release a new version for `setup-nu`
release updateLog=('false'):
  @overlay use {{ join(ERDA_PIPELINE_PATH, 'nu', 'common.nu') }}; \
    overlay use {{ join(ERDA_PIPELINE_PATH, 'nu', 'release.nu') }}; \
    git-check --check-repo=1 {{ERDA_PIPELINE_PATH}}; \
    make-release --update-log={{updateLog}}

# Plugins need to be registered only once after nu v0.61
_setup:
  @register -e json {{ join(NU_DIR, _query_plugin) }}
