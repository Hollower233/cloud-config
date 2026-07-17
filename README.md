# CloudConfig

从 Roblox DataStore 读取配置，并在客户端和服务端提供同一份只读快照的 Wally 包。

## 安装

```toml
[dependencies]
CloudConfig = "hollower233/cloud-config@0.1.0"
```

该包依赖并会自动安装 `sleitnick/net@0.2.0`。

## 使用

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CloudConfig = require(ReplicatedStorage.Packages.CloudConfig)

local config = CloudConfig.getAll()
```

服务端首次加载时读取 DataStore `cloudConfig` 的 `config` 键。客户端首次调用时通过 `CloudConfigGetAll` RemoteFunction 取得缓存快照。

数据格式：

```lua
{
    server = { Items = { { id = "apple", price = 10 } } },
    studio = { Items = { { id = "apple", price = 1 } } },
}
```

普通表格配置会暴露 `list` 以及基于首行字符串字段生成的索引，例如 `Items.byId.apple`。
