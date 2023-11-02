# Erda-Pipeline Action

本 Github Action 通过 Github 的 Workflow 调用 [Nushell](https://github.com/nushell/nushell) 脚本然后再利用该脚本来执行或者查询 [Erda](https://erda.cloud/) 流水线。开发这个 Action 的初衷是为了解决无法在手机上执行 & 查看 Erda 流水线执行状态的问题，因为 Github 支持在手机上执行 Workflow，而 Erda 目前尚不支持。

## 使用说明

### 执行流水线

创建一个自有仓库，在 `.github/workflows` 目录下添加一个 Github Workflow, 比如 `deploy-docs-dev.yml` 内容如下：

```yaml
name: Run-Erda-Pipeline
on:
  push:
    branches:
      - develop # 设置 develop 分支 push 上去的时候自动执行流水线，在生成执行记录后可以根据情况决定是否启用

jobs:
  Run-Pipeline:
    runs-on: ubuntu-latest
    name: Run fe-docs@feature/latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4.1.0

      - name: Run Erda Pipeline
        uses: hustcer/erda-pipeline@v1.3
        with:
          action: "run" # 打算对流水线执行的操作目前可以为：run & query, 未来可能会添加 cancel 支持
          pid: 213 # Project ID，可以从应用的 URL 链接里面获取
          app-id: 7542 # App ID, 可以从应用的 URL 链接里面获取
          app-name: "Fe-Docs" # 应用名，这个名字可以自己随便定义，在流水线执行记录里面会打印出来，方便识别
          branch: "feature/latest" # 打算执行或者查询的流水线所在的分支
          pipeline: "pipeline.yml" # 打算执行或者查询的流水线文件, 比如：'.erda/pipelines/pc.yml' 等, 默认为 'pipeline.yml'
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          ERDA_USERNAME: ${{ secrets.ERDA_USERNAME }} # Erda 登陆用户名
          ERDA_PASSWORD: ${{ secrets.ERDA_PASSWORD }} # Erda 登陆密码
```

参考示例: [Test.yml](https://github.com/hustcer/erda-pipeline/blob/main/.github/workflows/test.yml)

> **Important**
>
> 1. 想要该流水线顺利运行你需要在应用 Setting --> Secrets and variables --> Actions --> New repository secret 里面添加两个 Secrets
>    命名分别为 `ERDA_USERNAME` & `ERDA_PASSWORD`, 并在其中填入 Erda 的登陆用户名和密码
> 2. 初次需要将该流水线设置为分支 push 的时候自动触发生成一条执行记录，之后就可以在手机端选择该执行记录然后重复执行该 Workflow 了，虽然后续执行
>    的是同一条记录，但是由于 Nushell 脚本执行流水线的时候始终使用的是指定应用指定分支的最新代码所以不用担心 Erda 应用里最新代码没有生效的问题

之后就可以在手机端通过 GitHub App 执行 Erda 的流水线了，执行结果可以查看 Github Action 的输出日志, [输出示例](https://github.com/hustcer/erda-pipeline/actions/runs/6695125684/job/18207644662)。

### 查询流水线最近执行记录

在 `.github/workflows` 目录下添加一个 Github Workflow, 比如 `query-docs-dev.yml` 内容如下：

```yaml
name: Query-Erda-Pipeline
on:
  push:
    branches:
      - develop # 设置 develop 分支 push 上去的时候自动执行流水线，在生成执行记录后可以根据情况决定是否启用

jobs:
  Run-Pipeline:
    runs-on: ubuntu-latest
    name: Run fe-docs@feature/latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4.1.0

      - name: Run Erda Pipeline
        uses: hustcer/erda-pipeline@v1.3
        with:
          action: "query" # 打算对流水线执行的操作目前可以为：run & query, 未来可能会添加 cancel 支持
          pid: 213 # Project ID，可以从应用的 URL 链接里面获取
          app-id: 7542 # App ID, 可以从应用的 URL 链接里面获取
          app-name: "Fe-Docs" # 应用名，这个名字可以自己随便定义，在流水线执行记录里面会打印出来，方便识别
          branch: "feature/latest" # 打算执行或者查询的流水线所在的分支
          pipeline: "pipeline.yml" # 打算执行或者查询的流水线文件, 比如：'.erda/pipelines/pc.yml' 等, 默认为 'pipeline.yml'
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          ERDA_USERNAME: ${{ secrets.ERDA_USERNAME }} # Erda 登陆用户名
          ERDA_PASSWORD: ${{ secrets.ERDA_PASSWORD }} # Erda 登陆密码
```

参考示例: [Test.yml](https://github.com/hustcer/erda-pipeline/blob/main/.github/workflows/test.yml)

> **Important**
>
> 1. 想要该流水线顺利运行你需要在应用 Setting --> Secrets and variables --> Actions --> New repository secret 里面添加两个 Secrets
>    命名分别为 `ERDA_USERNAME` & `ERDA_PASSWORD`, 并在其中填入 Erda 的登陆用户名和密码
> 2. 初次需要将该流水线设置为分支 push 的时候自动触发生成一条执行记录，之后就可以在手机端选择该执行记录然后重复执行该 Workflow 了

之后就可以在手机端通过 GitHub App 查询 Erda 的流水线的最近执行记录了，查询结果可以查看 Github Action 的输出日志, [输出示例](https://github.com/hustcer/erda-pipeline/actions/runs/6695125684/job/18207651324)。

### 友情提示

1. 你的代码仓库里面只需要有相应的 Github Workflow 即可，不需要将此仓库的脚本等加入进去；
2. 示例中的代码 checkout 步骤通过 `uses: actions/checkout@v4.1.0` 完成，不过这仅适用于可公开访问的仓库，对于私有仓库需要指定仓库及私钥，参考[这里说明](https://github.com/actions/checkout#checkout-multiple-repos-private)；
3. 建议在一个 Workflow 里面同时加入执行和查询的 Job，这样只需要一个流水线即可完成两个操作，虽然 Erda 流水线的执行是异步的，查询的时候可能 Erda 流水线尚未结束，但是 Github App 允许你单独启动指定的 Job，你可以在稍后重新单独执行下查询 Job 即可查看流水线的最新执行情况；

### 输入

| 名称       | 必填 | 描述                                                                               | 类型   | 默认值         |
| ---------- | ---- | ---------------------------------------------------------------------------------- | ------ | -------------- |
| `action`   | 是   | 打算对流水线执行的操作目前可以为：`run` 或者 `query`, 未来可能会添加 `cancel` 支持 | string | `run`          |
| `pid`      | 是   | Project ID，可以从应用的 URL 链接里面获取                                          | string | -              |
| `app-id`   | 是   | App ID, 可以从应用的 URL 链接里面获取                                              | string | -              |
| `app-name` | 是   | 应用名，这个名字可以自己随便定义，在流水线执行记录里面会打印出来，方便识别         | string | -              |
| `branch`   | 是   | 打算执行或者查询的流水线所在的分支                                                 | string | -              |
| `pipeline` | 是   | 打算执行或者查询的流水线文件, 比如：`.erda/pipelines/pc.yml` 等                    | string | `pipeline.yml` |

## 许可

Licensed under:

- MIT license ([LICENSE](LICENSE) or http://opensource.org/licenses/MIT)
