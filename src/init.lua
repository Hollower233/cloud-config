--!strict

-- CloudConfig 在服务端读取 DataStore，在客户端通过 Net 获取同一份快照。
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

local Net = require(script.Parent.Net)

type RawConfig = {
	server: { [string]: any },
	studio: { [string]: any },
}
type Snapshot = { [string]: any }

local DATA_STORE_NAME = "cloudConfig"
local DATA_STORE_KEY = "config"
local REMOTE_NAME = "CloudConfigGetAll"
local RETRY_MIN_WAIT = 1
local RETRY_MAX_WAIT = 60

local getAllConfigFunction = Net:RemoteFunction(REMOTE_NAME)
local serverSnapshot: Snapshot? = nil
local clientSnapshot: Snapshot? = nil

local function groupBy(rows: { any }, key: string): { [any]: { any } }
	local result = {}

	for _, row in rows do
		local value = row[key]
		result[value] = result[value] or {}
		table.insert(result[value], row)
	end

	return result
end

local function retryUntilSuccess<T>(callback: () -> T): T
	local currentWait = RETRY_MIN_WAIT

	while true do
		local success, result = pcall(callback)
		if success then
			return result
		end

		warn(`[CloudConfig] 读取配置失败，{currentWait} 秒后重试：{result}`)
		task.wait(currentWait)
		currentWait = math.min(currentWait * 2, RETRY_MAX_WAIT)
	end
end

local function loadRawConfig(): RawConfig
	local dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
	local rawConfig = retryUntilSuccess(function()
		return dataStore:GetAsync(DATA_STORE_KEY)
	end)

	if type(rawConfig) ~= "table" then
		warn(`[CloudConfig] 配置不是 table，已使用空配置，当前类型: {typeof(rawConfig)}`)
		return { server = {}, studio = {} }
	end

	return {
		server = if type(rawConfig.server) == "table" then rawConfig.server else {},
		studio = if type(rawConfig.studio) == "table" then rawConfig.studio else {},
	}
end

local function buildEntry(cfgName: string, data: any): { [string]: any }
	if type(data) ~= "table" then
		warn(`[CloudConfig] {cfgName} 配置不是 table，已回退为空配置，当前类型: {typeof(data)}`)
		return {}
	end
	if #data == 0 then
		return {}
	end
	if type(data[1]) ~= "table" then
		warn(`[CloudConfig] {cfgName} 首行数据不是 table，已回退为空配置`)
		return {}
	end

	local entry: { [string]: any } = { list = data }
	local indexedFields = {}
	local groupedFields = {}

	for fieldName, value in data[1] do
		if type(value) == "string" then
			local capitalizedName = fieldName:sub(1, 1):upper() .. fieldName:sub(2)
			local outputName = "by" .. capitalizedName
			entry[outputName] = {}
			table.insert(indexedFields, { name = fieldName, output = outputName })
		end
	end

	for _, row in data do
		for _, field in indexedFields do
			if not groupedFields[field.name] then
				local index = entry[field.output]
				local value = row[field.name]
				if index[value] then
					entry[field.output] = groupBy(data, field.name)
					groupedFields[field.name] = true
				else
					index[value] = row
				end
			end
		end
	end

	return entry
end

local function buildSnapshot(rawConfig: RawConfig): Snapshot
	local environment = if RunService:IsStudio() then "studio" else "server"
	local source = rawConfig[environment] or {}
	local snapshot: Snapshot = {}

	for configName, data in source do
		if configName == "misc" then
			snapshot[configName] = if type(data) == "table" then data else {}
		else
			snapshot[configName] = buildEntry(configName, data)
		end
	end

	return snapshot
end

local function fetchClientSnapshot(): Snapshot
	return getAllConfigFunction:InvokeServer() :: Snapshot
end

local function getAll(): Snapshot
	if RunService:IsServer() then
		return serverSnapshot :: Snapshot
	end

	if clientSnapshot == nil then
		clientSnapshot = fetchClientSnapshot()
	end

	return clientSnapshot :: Snapshot
end

if RunService:IsServer() then
	serverSnapshot = buildSnapshot(loadRawConfig())
	getAllConfigFunction.OnServerInvoke = function(_player)
		return serverSnapshot :: Snapshot
	end
end

return {
	getAll = getAll,
}
