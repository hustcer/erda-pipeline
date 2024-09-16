#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/10/29 19:56:56
# Description: Script to release erda-pipeline
#
# TODO:
#   [√] Make sure the release tag does not exist;
#   [√] Make sure there are no uncommit changes;
#   [√] Update change log if required;
#   [√] Create a release tag and push it to the remote repo;
# Usage:
#   Change `version` in meta.json and then run: `just release` OR `just release true`

export def 'make-release' [
  --update-log(-u)      # Add this flag to update CHANGELOG.md
] {

  cd $env.ERDA_PIPELINE_PATH
  let releaseVer = (open meta.json | get actionVer)

  if (has-ref $releaseVer) {
  	print $'The version ($releaseVer) already exists, Please choose another version.(char nl)'
  	exit 5
  }
  let majorTag = $releaseVer | split row '.' | first
  let statusCheck = (git status --porcelain)
  if not ($statusCheck | is-empty) {
  	print $'You have uncommit changes, please commit them and try `release` again!(char nl)'
  	exit 5
  }
  if ($update_log) {
    git cliff --unreleased --tag $releaseVer --prepend CHANGELOG.md;
    git commit CHANGELOG.md -m $'update CHANGELOG.md for ($releaseVer)'
  }
  # Delete tags that not exist in remote repo
  git fetch origin --prune '+refs/tags/*:refs/tags/*'
  let commitMsg = $'A new release for version: ($releaseVer) created by Release command of erda-pipeline.'
  git tag $releaseVer -am $commitMsg
  # Remove local major version tag if exists and ignore errors
  do -i { git tag -d $majorTag | complete | ignore }
  git checkout $releaseVer; git tag $majorTag
  git push origin $majorTag $releaseVer --force
}
