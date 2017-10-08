local discordia = require('discordia')
local spawn = require('coro-spawn')
local split = require('coro-split')
local net = require('coro-net')
local timer = require('timer')

local fs, fsopen, fswrite -- Lazy required
local format = string.format
local unpack = table.unpack

-- Do not edit, pass options to function instead
local sharding_options = {
  port = 1337,
  maxShards = 10,
  shardsPerProcess = 1,
  waitTime = 2500,
  arguments = {},
  autoRestart = true,
  silent = false,
  logFile = nil,
  timestamp = '!%Y-%m-%dT%H:%M:%S'
}

local ipc_emitter = discordia.Emitter()
local shard_emitter = discordia.Emitter()

local logFile
local serverWrite

local function loadServer()
  print("LOADING IPC SERVER")
  net.createServer(sharding_options.port, function(read, write)
    serverWrite = write
    coroutine.wrap(function()
      for data in read do
        ipc_emitter:emit("data", data)
      end
    end)()
  end)
end

local function runShard(...)
  local args = {...}

  -- args[1]: File
  -- args[2]: Port
  -- args[3]: firstShard
  -- args[4]: lastShard
  -- args[5]: maxShards
  -- args[...]: Optional Arguments

  local child = spawn('luvit', {
    args = args
  })

  local function readstdout()
    local line = {nil, ' | ', format("Shards %s to %s", args[3], args[4]), ' | ', nil}
    for data in child.stdout.read do
      shard_emitter:emit("data", args[3], args[4], data)
      if not sharding_options.silent then
        print(data)
      end
      if logFile then
        line[1] = os.date(sharding_options.timestamp)
        line[5] = data
        fswrite(logFile, line)
      end
    end
    if not child.stdout.handle:is_closing() then
      child.stdout.handle:close()
    end
  end

  local function readstderr()
    local line = {nil, ' | ', format("Shards %s to %s", args[3], args[4]), ' | ', nil}
    for data in child.stderr.read do
      shard_emitter:emit("error", args[3], args[4], data)
      if not sharding_options.silent then
        print("----------------------")
        print(format("Process Error: Shards %s to %s", args[3], args[4]))
        print("----------------------")
        print(data)
        print("----------------------")
      end

      if logFile then
        line[1] = os.date(sharding_options.timestamp)
        line[5] = data
        fswrite(logFile, line)
      end
    end
    if not child.stderr.handle:is_closing() then
      child.stderr.handle:close()
    end
  end

  split(readstdout, readstderr, child.waitExit)
  shard_emitter:emit("dead", args[3], args[4])
  if sharding_options.autoRestart then
    runShard(...)
  end
end

return function (file, options)
  loadServer()

  for key, value in pairs(options) do
    sharding_options[key] = value
  end

  if sharding_options.logFile then
    fs = require('coro-fs')
    fsopen, fswrite = fs.open, fs.write

    logFile = fsopen(sharding_options.logFile)
  end

  local first, last = 0, -1
  local processes = math.ceil(sharding_options.maxShards / sharding_options.shardsPerProcess)

  for _ = 1, processes do
    print("----------------------")
    if not last then break end

    first = last + 1
    if last + 1 > sharding_options.maxShards then
      first = nil
      break
    end

    last = (first + sharding_options.shardsPerProcess) - 1
    if last > sharding_options.maxShards then
      last = sharding_options.maxShards
    elseif (first > sharding_options.maxShards) then
      break
    end

    print("Starting Process")
    print("First Shard:", first, "Last Shard:", last)

    local args = sharding_options.arguments or {}
    coroutine.wrap(runShard)(file, sharding_options.port, first, last, sharding_options.maxShards, unpack(args))
    timer.sleep(sharding_options.waitTime)
  end

  return {
    writeServer = serverWrite,
    ipc_emitter = ipc_emitter,
    shard_emitter = shard_emitter
  }
end