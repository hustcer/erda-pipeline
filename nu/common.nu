#!/usr/bin/env nu
# Author: hustcer
# Created: 2022/05/01 18:36:56
# Usage:
#   use source command to load it

# If current host is Windows
export def windows? [] {
  # Windows / Darwin
  (sys).host.name == 'Windows'
}

# Check if some command available in current shell
export def is-installed [ app: string ] {
  (which $app | length) > 0
}

# Get the specified env key's value or ''
export def 'get-env' [
  key: string       # The key to get it's env value
  default?: string  # The default value for an empty env
] {
  $env | get -i $key | default $default
}

# Get the specified config from `termix.toml` by key
export def 'get-conf' [
  key: string       # The key to get it's value from termix.toml
  default?: any     # The default value for an empty conf
] {
  # books.toml config file path
  let _SHARE_CONF = ([$env.SHARE_NU_DIR 'share.toml'] | path join)
  let result = (open $_SHARE_CONF | get $key)
  if ($result | is-empty) { $default } else { $result }
}

# Get TERMIX_TMP_PATH from env first and fallback to HOME/.termix-nu
export def get-tmp-path [] {
  # let homeEnv = if (windows?) { 'USERPROFILE' } else { 'HOME' }
  let DEFAULT_TMP = [$nu.home-path '.termix-nu'] | path join
  # 先从环境变量里面查找临时文件路径
  let tmpDir = (get-env TERMIX_TMP_PATH '')
  # 如果环境变量里面没有配置临时文件路径，则使用 HOME 目录下的 .termix 目录
  let tmpPath = if ($tmpDir | is-empty) {
    if not ($DEFAULT_TMP | path exists) { mkdir $DEFAULT_TMP }
    $DEFAULT_TMP
  } else { $tmpDir }
  if not ($tmpPath | path exists) {
    print $'(ansi r)Path ($tmpPath) does not exist, please create it and try again...(ansi reset)(char nl)(char nl)'
    exit 3
  }
  # print $'Using (ansi g)($tmpPath)(ansi reset) as the temporary directory...(char nl)'
  $tmpPath
}

# Check if a git repo has the specified ref: could be a branch or tag, etc.
export def has-ref [
  ref: string   # The git ref to check
] {
  let checkRepo = (do -i { git rev-parse --is-inside-work-tree } | complete)
  if not ($checkRepo.stdout =~ 'true') { return false }
  # Brackets were required here, or error will occur
  let parse = (do -i { (git rev-parse --verify -q $ref) })
  if ($parse | is-empty) { false } else { true }
}

# Compare two version number, return `true` if first one is higher than second one,
# Return `null` if they are equal, otherwise return `false`
export def compare-ver [
  from: string,
  to: string,
] {
  let dest = ($to | str downcase | str trim -c 'v' | str trim)
  let source = ($from | str downcase | str trim -c 'v' | str trim)
  # Ignore '-beta' or '-rc' suffix
  let v1 = ($source | split row '.' | each {|it| ($it | parse -r '(?P<v>\d+)' | get v | get 0 )})
  let v2 = ($dest | split row '.' | each {|it| ($it | parse -r '(?P<v>\d+)' | get v | get 0 )})
  for $v in $v1 -n {
    let c1 = ($v1 | get -i $v.index | default 0 | into int)
    let c2 = ($v2 | get -i $v.index | default 0 | into int)
    if $c1 > $c2 {
      return true
    } else if ($c1 < $c2) {
      return false
    }
  }
  return null
}

# Compare two version number, return true if first one is lower then second one
export def is-lower-ver [
  from: string,
  to: string,
] {
  (compare-ver $from $to) == false
}

# Create a line by repeating the unit with specified times
def build-line [
  times: int,
  unit: string = '-',
] {
  0..<$times | reduce -f '' { |i, acc| $unit + $acc }
}

# Log some variables
export def log [
  name: string,
  var: any,
] {
  print $'(ansi g)(build-line 18)> Debug Begin: ($name) <(build-line 18)(ansi reset)'
  print $var
  print $'(ansi g)(build-line 20)>  Debug End <(build-line 20)(char nl)(ansi reset)'
}

export def hr-line [
  width?: int = 90,
  --color(-c): string = 'g',
  --blank-line(-b),
  --with-arrow(-a),
] {
  print $'(ansi $color)(build-line $width)(if $with_arrow {'>'})(ansi reset)'
  if $blank_line { char nl }
}


# parallel { print "Oh" } { print "Ah" } { print "Eeh" }
export def parallel [...closures] {
  $closures | par-each {
    |c| do $c
  }
}
