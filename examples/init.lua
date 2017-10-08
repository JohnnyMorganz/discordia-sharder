local sharder = require('discordia-sharder')('bot.lua', {
  -- Options go here
})

local ipc_emitter, shard_emitter, write = sharder.ipc_emitter, sharder.shard_emitter, sharder.write

-- Shard Emitter Functionalities

shard_emitter:on('data', function(firstShardID, lastShardID, data)
  -- handle data
end)

shard_emitter:on('error', function(firstShardID, lastShardID, error)
  -- handle error
end)

shard_emitter:on('dead', function(firstShardID, lastShardID)
  -- handle restart
end)

-- IPC Emitter Functionalities

ipc_emitter:on('data', function(data)
  -- handle data
end)

write('hello from master')