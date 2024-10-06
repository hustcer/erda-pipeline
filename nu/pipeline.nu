#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/06/28 15:33:15
# TODO:
#  [x] 执行新流水线之前可以查询是否有正在运行的流水线，如果有则停止执行，也可以加上 `-f` 强制执行
#  [x] 执行新流水线之前可以查询同一 Commit 是否已经被部署过，如果部署过则停止执行，也可以加上 `-f` 强制执行
#  [x] 允许查询某个 target 下的最近20条流水线记录
#  [x] Erda OpenAPI Session 过期后自动续期
#  [x] 自动根据分支名称推断目标环境是属于 DEV, TEST, STAGING 还是 PROD
#  [x] 非ID方式查询流水线分页结果时自动输出正在执行的所有流水线的详细信息
#  [ ] 允许停止正在执行的流水线
# Description: 创建 Erda 流水线并执行，同时可以查询流水线执行结果

use common.nu [has-ref build-line hr-line log]

const NA = 'N/A'
const ERDA_HOST = 'https://erda.cloud'
const PIPELINE_POLLING_INTERVAL = 3sec

export-env {
  # $env.config.table.mode = 'light'
  # FIXME: 去除前导空格背景色
  $env.config.color_config.leading_trailing_space_bg = { attr: n }
}

# 判断是否需要重试，如果返回 true 则重试，否则不重试
def should-retry [resp: any] {
  let isEmpty = ($resp | is-empty)
  let noAuth = ($resp | describe) == 'string' and ($resp =~ 'auth failed' or $resp =~ 'Unauthorized')
  $isEmpty or $noAuth
}

# Check if the required environment variable was set, quit if not
def check-envs [] {
  # 部署/查询 Pipeline 操作需要先配置 ERDA_USERNAME & ERDA_PASSWORD
  let envs = ['ERDA_USERNAME' 'ERDA_PASSWORD']
  let empties = ($envs | filter {|it| $env | get -i $it | is-empty })
  if ($empties | length) > 0 {
    print $'Please set (ansi r)($empties | str join ',')(ansi reset) in your environment first...'
    exit 5
  }
}

# Renew Erda session by username and password if expired
export def get-auth [] {
  print 'Renewing Erda session...'
  let query = { username: $env.ERDA_USERNAME, password: $env.ERDA_PASSWORD } | url build-query
  let RENEW_URL = $'https://openapi.erda.cloud/login?($query)'
  mut renew = (curl --silent -X POST $RENEW_URL | from json)
  if ($renew | is-empty) {
    $renew = (curl --silent -X POST $RENEW_URL | from json)
  }
  if ($renew | describe) == 'string' {
    print $'Erda session renew failed with message: (ansi r)($renew)(ansi reset)'; exit 8
  }
  $'cookie: OPENAPISESSION=($renew.sessionid)'
}

# Check if the pipeline config was set correctly, quit if not
def check-pipeline-conf [conf: any] {
  let keys = ['pid', 'appId', 'branch', 'appName', 'pipeline']

  let empties = ($keys | filter {|it| $conf | get -i $it | is-empty })
  if ($empties | length) > 0 {
    print $'Please set (ansi r)($empties | str join ',')(ansi reset) in the following pipeline config:'
    print $conf; exit 1
  }
}

# 根据 AppID、Branch、Pipeline 查询最近的流水线执行记录
def query-cicd [aid: int, appName: string, branch: string, erdaEnv: string, pipeline: string, count?: int = 20, --auth: string] {
  # Possible env values: DEV,TEST,STAGING,PROD
  let cicd = {
    ymlNames: $'($aid)/($erdaEnv)/($branch)/($pipeline)',
    appID: $aid, branches: $branch, sources: 'dice', pageNo: 1, pageSize: $count
  }
  let cicdUrl = $'($ERDA_HOST)/api/terminus/cicds?($cicd | url build-query)'

  # Query the id of newly created CICD
  mut ci = (curl --silent -H $auth $cicdUrl | from json)
  # Check session expired, and renew if needed
  if (should-retry $ci) {
    $ci = (curl --silent -H (get-auth) $cicdUrl | from json)
  }
  # log 'Query CICD: ' ($ci.data.pipelines | select id commit status | table -e)
  if ($ci | describe) == 'string' or ($ci | is-empty) {
    print $'Query CICD failed in query-cicd with message: (ansi r)($ci)(ansi reset)'; exit 1
  }
  if not $ci.success {
    print $'(ansi r)Query CICD failed, Please try again ...(ansi reset)'
    print ($ci | table -e)
    exit 1
  }
  return $ci
}

# 格式化流水线查询结果，以更友好的方式呈现
def format-pipeline-data [pipelines: list] {
  return (
    $pipelines
      | select -i id commit status normalLabels extra timeBegin timeUpdated filterLabels
      | upsert id {|it| $it | get-pipeline-url }
      | upsert timeBegin {|it| if ($it | get -i timeBegin | is-empty) { $NA } else { $it.timeBegin } }
      | update commit {|it| $it.commit | str substring 0..9 }
      | upsert Comment {|it| $it.normalLabels.commitDetail | from json | get -i comment | str trim }
      | upsert Author {|it| $it.normalLabels.commitDetail | from json | get -i author }
      | update status {|it| $'(ansi pb)($it.status)(ansi reset)' }
      | upsert Runner {|it| $it.extra | get -i runUser | default {name: $NA} | get name }
      | upsert Begin {|it| if $it.timeBegin == $NA { $it.timeBegin } else { $it.timeBegin | into datetime | date humanize } }
      | upsert Updated {|it| $it.timeUpdated | into datetime | date humanize }
      | reject extra timeBegin timeUpdated normalLabels filterLabels
      | rename ID Commit Status
  )
}

# Render pipeline ID as a clickable link while querying latest CICDs
def get-pipeline-url [--as-raw-string] {
  let $pipeline = $in
  let id = $pipeline.id
  let appid = $pipeline.filterLabels.appID
  let pid = $pipeline.filterLabels.projectID
  let link = $'($ERDA_HOST)/terminus/dop/projects/($pid)/apps/($appid)/pipeline/obsoleted?pipelineID=($id)'
  if $as_raw_string { $link } else {
    # FIXME: 无法正确渲染链接, 因为 ansi link 在 extra feature 里面
    # $link | ansi link --text $'($id)'
    return $id
  }
}

# 查询指定目标上最新的N条流水线执行结果
def query-latest-cicd [pipeline: record, --watch, --auth: string, --show-running-detail] {
  let app = $pipeline
  let environment = $app.environment
  check-envs

  print $'Querying latest CICDs for (ansi pb)($app.appName) on ($app.branch)(ansi reset) branch:'; hr-line -c pb
  let ci = (query-cicd $app.appId $app.appName $app.branch $environment $app.pipeline 10 --auth $auth)
  if ($ci.data.total == 0) {
    print $'No CICD found for (ansi pb)($app.appName)(ansi reset) on (ansi g)($app.branch)(ansi reset) branch'; exit 0
  }
  let pipelines = (format-pipeline-data $ci.data.pipelines)
  print ($pipelines | table -ew 150)
  print 'URL of the latest pipeline:'; hr-line
  print ($ci.data.pipelines | first | get-pipeline-url --as-raw-string)
  print (char nl)
  if ($show_running_detail) {
    let running = $ci.data.pipelines | where status == 'Running'
    if ($running | length) == 0 { return }
    print $'Detail of the running pipelines:'; hr-line
    $running | get ID | each {|it| query-cicd-by-id $it --auth $auth --watch=$watch }
  }
}

# 检查是否有正在执行的流水线，如果有则显示其概要信息并退出
def check-cicd [aid: int, appName: string, branch: string, erdaEnv: string, pipeline: string, --auth: string] {
  print $'Checking running CICDs for (ansi pb)($appName)(ansi reset) with (ansi g)($pipeline)(ansi reset) from (ansi g)($branch)(ansi reset) branch'
  let ci = (query-cicd $aid $appName $branch $erdaEnv $pipeline --auth $auth)
  if ($ci.data.total == 0) { return true }

  # Update the remote-tracking branches to get the latest commit ID
  # git fetch origin $branch
  # Always use the remote commit id for checking, `str trim` is required here
  let commitID = if (has-ref $'origin/($branch)') { git rev-parse $'origin/($branch)' | str trim } else { '' }
  # Possible pipeline status: Running,Success,Failed,StopByUser
  let running = ($ci.data.pipelines | where status == 'Running')
  # log 'latest' ($ci.data.pipelines | select id commit status)
  let deployed = ($ci.data.pipelines | where commit == $commitID | where status == 'Success')
  let nRunning = ($running | length)
  let nDeployed = ($deployed | length)
  # 没有正在部署的流水线，也未曾部署过则直接返回以执行下一步
  if $nRunning == 0 and $nDeployed == 0 { return true }
  if $nRunning > 0 {
    print $'There are running pipelines, please wait with patience or re-run with `-f` flag.'
  } else if $nDeployed > 0 {
    print $'The commit (ansi p)($commitID | str substring 0..9)@($branch)(ansi reset) has been deployed, re-run with `-f` flag to deploy it again.'
  }
  let result = if $nRunning > 0 { $running } else { $deployed }
  hr-line 96 -abc pb
  print (format-pipeline-data $result)
  return false
}

# 创建 CICD 流水线并返回其对应 ID
def create-cicd [aid: int, appName: string, branch: string, pipeline: string, --auth: string] {
  let cicdUrl = $'($ERDA_HOST)/api/terminus/cicds'
  let cicd = { appID: $aid, branch: $branch, pipelineYmlName: $pipeline }
  print $'Initialize CICD for (ansi pb)($appName)(ansi reset) with (ansi g)($pipeline)(ansi reset) from (ansi g)($branch)(ansi reset) branch'

  # Query the ID of newly created CICD
  mut ci = (curl --silent -H $auth --data-raw $'($cicd | to json)' $cicdUrl | from json)
  # Check session expired, and renew if needed
  if (should-retry $ci) {
    $ci = (curl --silent -H (get-auth) --data-raw $'($cicd | to json)' $cicdUrl | from json)
  }
  if ($ci | describe) == 'string' { print $'Initialize CICD failed with message: (ansi r)($ci)(ansi reset)'; exit 1 }
  if $ci.success { print $'(ansi g)Initialize CICD successfully...(ansi reset)'; return $ci.data.id }
  print $'(ansi r)Initialize CICD failed, Please try again ...(ansi reset)'
  print ($ci | table -e)
  exit 1
}

# 执行指定 ID 的流水线
def run-cicd [id: int, appid: int, pid: int, --watch, --auth: string] {
  let runUrl = $'($ERDA_HOST)/api/terminus/cicds/($id)/actions/run'
  mut run = (curl --silent -H $auth -X POST $runUrl | from json)
  let url = $'($ERDA_HOST)/terminus/dop/projects/($pid)/apps/($appid)/pipeline/obsoleted?pipelineID=($id)'
  # Check session expired, and renew if needed
  if (should-retry $run) {
    $run = (curl --silent -H (get-auth) -X POST $runUrl | from json)
  }
  if $run.success {
    print $'CICD started, You can query the pipeline running status with id: (ansi g)($id)(ansi reset)'
    print $'Or visit ($url) for more details'
  }
  if $watch { watch-cicd-status $id }
}

# 根据流水线 ID 轮询流水线执行结果并显示, 轮询间隔为 2 秒
export def watch-cicd-status [id: int] {
  let auth = (get-auth)
  let stages = polling-stage-status $id $auth
  let total = $stages | length
  const UNFINISHED_STATUS = [Born, Created, Analyzed, Queue, Running]
  const FINISH_STATUS = [Success, Failed, StopByUser, NoNeedBySystem]
  print $'(char nl)Pipeline Running Detail:'; hr-line

  # pipelineTasks status: Created,Analyzed,Success,Queue,Running,Failed,StopByUser,NoNeedBySystem
  for stage in ($stages | enumerate) {
    let stageStatus = $stage.item.pipelineTasks | get status
    let tasks = $stage.item.pipelineTasks | get name | str join ', '
    let duration = $'($stage.item.pipelineTasks | get costTimeSec | math sum)sec' | into duration
    let stageSuccess = $stageStatus | all {|it| $it == 'Success' }
    let stageFailed = $stageStatus | any {|it| $it == 'Failed' }
    let stageStopped = $stageStatus | any {|it| $it == 'StopByUser' }
    let stageSkipped = $stageStatus | all {|it| $it == 'NoNeedBySystem' }
    let stageUnfinished = $stageStatus | any {|it| $it in $UNFINISHED_STATUS }
    let indicator = if $stageSuccess {
        $'(ansi g)✓(ansi reset)  Stage: (ansi g)($tasks)(ansi reset) Finished Successfully! Time cost: ($duration)'
      } else if $stageSkipped {
        $'(ansi y)☕(ansi reset) Stage: (ansi y)($tasks)(ansi reset) Was skipped!' # 💥 💭 👻 💨 ☕
      } else if $stageFailed {
        $'(ansi y)⚠(ansi reset)  Stage: (ansi y)($tasks)(ansi reset) Failed! Time cost: ($duration)'
      } else if $stageStopped {
        $'(ansi y)👻(ansi reset) Stage: (ansi y)($tasks)(ansi reset) Was stopped! Time cost: ($duration)'
      } else if $stageUnfinished {
        $'(ansi pb)🪄(ansi reset) Stage: (ansi g)($tasks)(ansi reset) is Running...'
      } else {
        $'(ansi r)✗(ansi reset) Unknown Status: ($stageStatus | str join ",")'
      }

    $env.config.table.mode = 'psql'
    print $'Stage ($stage.index + 1)/($total): ($indicator)'
    mut counter = 0
    mut keepPolling = $stageUnfinished
    while $keepPolling {
      $counter += 1
      print (build-line $counter *)  # * 💤 👣 ✨ 🍵 ⚡ 🎉 🔹 🔸
      if ($counter == 90) { $counter = 0; print -n (char nl) }
      let pollingStages = polling-stage-status $id $auth --sid $stage.item.id
      let tasks = $pollingStages | flatten | get pipelineTasks
      let status = $tasks | get status
      if ($status | any {|it| $it in $UNFINISHED_STATUS }) {
        $keepPolling = true
      } else {
        $keepPolling = false
        let duration = $'($tasks | get costTimeSec | math sum)sec' | into duration
        print $'(char nl)Stage finished with status:(char nl)'
        $tasks | select name status | rename Name Status | print
        print $'(char nl)Time cost of this stage: ($duration)'
        hr-line 60 -c grey66
      }
      sleep $PIPELINE_POLLING_INTERVAL
    }
  }
  # Refresh the query result and print the final costTimeSec
  let query = fetch-cicd-detail $id $auth
  let totalTime = $'($query.data.costTimeSec)sec' | into duration
  print $'(char nl)Pipeline run finished with status: (ansi p)($query.data.status)(ansi reset)! Total time cost: ($totalTime)'
}

# 查询流水线执行结果的相应阶段的详细信息
def polling-stage-status [id: int, auth: string, --sid: int] {
  let query = fetch-cicd-detail $id $auth
  const PIPELINE_TASK_COLUMNS = [id name type status costTimeSec queueTimeSec timeBegin timeEnd extra]
  # pipelineTasks status: Created,Success,Queue,Running,Failed,StopByUser
  let stages = $query.data.pipelineStages
    | select id pipelineTasks
    | upsert pipelineTasks {|it| $it.pipelineTasks | select ...$PIPELINE_TASK_COLUMNS }
  let stages = if not ($sid | is-empty) { $stages | where id == $sid } else { $stages }
  $stages
}

# 查询流水线执行结果的详细信息
export def fetch-cicd-detail [id: int, auth: string, --host: string = $ERDA_HOST] {
  let queryUrl = $'($host)/api/terminus/pipelines/($id)'
  mut query = (curl --silent -H $auth $queryUrl | from json)

  # Check session expired, and renew if needed
  loop {
    if (should-retry $query) {
      $query = (curl --silent -H $auth $queryUrl | from json)
    } else { break }
  }
  $query
}

# 根据流水线 ID 查询流水线执行结果
def query-cicd-by-id [id: int, --watch, --auth: string] {
  let queryUrl = $'($ERDA_HOST)/api/terminus/pipelines/($id)'
  mut query = (curl --silent -H $auth $queryUrl | from json)

  # Check session expired, and renew if needed
  if (should-retry $query) {
    $query = (curl --silent -H (get-auth) $queryUrl | from json)
  }
  if ($query | describe) == 'string' { print $'Query CICD by id failed with message: (ansi r)($query)(ansi reset)'; exit 1 }
  if (not $query.success ) { print $'Query CICD failed with error message: (ansi r)($query.err.msg)(ansi reset)'; exit 1 }
  let timeEnd = if ($query.data.timeEnd | is-empty) { $'(ansi wd)---Not Yet!---(ansi reset)' } else { $query.data.timeEnd }

  let output = {
    App: $query.data.applicationName
    Branch: $query.data.branch
    Status: $'(ansi pb)($query.data.status)(ansi reset)'
    Runner: $query.data.extra.runUser.name
    Committer: $query.data.commitDetail.author
    Commit: ($query.data.commit | str substring 0..9)
    Comment: ($query.data.commitDetail.comment | str trim)
    Begin: $query.data.timeBegin
    End: $timeEnd
    Duration: ($'($query.data.costTimeSec)sec' | into duration)
    # 此处之所以没有直接用 $appid & $pid 是因为可能存在在 A 应用仓库中查询 B 应用的流水线执行结果的情况，故而以返回数据为准
    URL: $'($ERDA_HOST)/terminus/dop/projects/($query.data.projectID)/apps/($query.data.applicationID)/pipeline/obsoleted?pipelineID=($id)'
  }
  print $'(char nl)(ansi pb)Current Running Status of CICD ($id):(ansi reset)'
  print '----------------------------------------------------------'
  print $output
  # print ($query | table -e)     # Just for debugging purpose
  if $watch { watch-cicd-status $id }
}

# 创建 Erda 流水线并执行，同时可以查询流水线执行结果
export def main [
  operation: string,      # 目前支持两种操作类型，run 和 query, run 用于创建并执行 CICD, query 用于查询 CICD 执行结果
  pipeline?: record,      # 当操作为 run 时必须指定，用于指定流水线的配置信息
  --watch(-w),            # 持续轮询并显示正在执行的流水线的详细信息
  --auth(-a): string,     # API调用的授权信息
  --force(-f),            # 当操作为 run 时生效，即便已经有正在运行的流水线或者已经部署过也会强制重新执行
  --cid(-i): int,         # 当操作为 query 时生效，用于查询 CICD 执行结果，如果不传则查询最近 10 条流水线执行结果
] {
  check-envs

  match $operation {
    run | r => {
      # 根据流水线 ID 查询无需加载其他环境变量，也不需要 .termixrc 文件
      let isIdQuery = ($operation in ['query', 'q']) and ($cid > 0)
      check-pipeline-conf $pipeline
      let app = $pipeline

      # 以下为应用级别配置，应用的所有开发者保持一致，可以放在代码仓库里面
      let pid = $app.pid
      let appid = $app.appId
      let branch = $app.branch
      let appName = $app.appName
      let environment = $app.environment
      # 检查是否有正在执行的流水线以及是否该 Commit 已经部署过
      if not $force {
        if not (check-cicd $appid $appName $branch $environment $app.pipeline --auth $auth) { return }
      }
      let cicdid = (create-cicd $appid $appName $branch $app.pipeline --auth $auth)
      run-cicd ($cicdid | into int) $appid $pid --auth $auth --watch=$watch

    }
    query | q => {
      # 未指定 cid 则查询最近 10 条流水线执行结果
      if ($cid | is-empty) {
        check-pipeline-conf $pipeline
        query-latest-cicd $pipeline --auth $auth --watch=$watch --show-running-detail; exit 0
      }
      if ($cid | describe) != 'int' {
        print $'Invalid value for --cid: (ansi r)($cid)(ansi reset), should be an integer number.'; exit 1
      }
      query-cicd-by-id $cid --auth $auth --watch=$watch
    }
    _ => {
      print $'Unsupported operation: (ansi r)($operation)(ansi reset), should be (ansi g)run(ansi reset) or (ansi g)query(ansi reset)'
      exit 1
    }
  }
}

# 创建 Erda 流水线并执行，默认情况下会检查是否有流水线正在执行或者是否该 Commit 已经部署过，若有则停止并给予提示
export def erda-deploy [
  pipeline: record,       # 指定待执行的流水线的配置信息
  --watch(-w),            # 执行流水线时持续轮询并显示该流水线各个 Stage 的详细执行信息
  --auth(-a): string,     # API调用的授权信息
  --force(-f),            # 即便已经有正在运行的流水线，或者即便该 Commit 对应的分支已经部署过也会强制重新部署
] {
  main run $pipeline --force=$force --auth $auth --watch=$watch
}

# 根据流水线 ID 或目标环境查询流水线执行结果, 例如: 单应用: t dq 997636681239659; t dq test, 多应用: t dq dev -a all
export def erda-query [
  pipeline?: record,      # 指定待查询的流水线的配置信息
  --watch(-w),            # 持续轮询并显示指定流水线各个 Stage 的详细执行信息
  --auth(-a): string,     # API调用的授权信息
  --cid(-i): any,         # 用于通过流水线的执行 ID 查询 CICD 执行结果，如果指定该参数则忽略 dest 参数
] {
  # 允许非指定流水线ID的查询
  if ($cid | is-empty) {
    main query $pipeline --auth $auth --watch=$watch
  } else {
    main query --cid $cid --auth $auth --watch=$watch
  }
}
