local discordia = require('discordia')

table.remove(process.argv, 1) -- Removes file name from args

local port, firstShard, lastShard, maxShards = table.unpack(process.argv) -- Include extra arguments if you provided some in your options table
port, firstShard, lastShard, maxShards = tonumber(port), tonumber(firstShard), tonumber(lastShard), tonumber(maxShards) -- Changed to numbers as they are passed as strings in the arguments

local client = discordia.Client({
  firstShard = firstShard,
  lastShard = lastShard,
  shardCount = maxShards -- Optional
})

-- Enable IPC
local net = require('coro-net')
local ipc_emitter = discordia.Emitter()
local serverWrite

local function connectToServer()
  local read, write = net.connect(port)
  if not read then
    error('Connection Error', write) -- Could not connect
  else
    serverWrite = write -- Allow write to be called outside of this function
    coroutine.wrap(function()
      for data in read do
        ipc_emitter:emit('data', data)
      end
    end)()
  end
end

coroutine.wrap(connectToServer)()

client:on('ready', function()
  serverWrite('im ready')
end)

client:run('Bot <token>')