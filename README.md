# Multi-Process Sharding for Discordia

This module allows you to seperate your [discordia](https://github.com/SinisterRectus/Discordia) bot into multiple processes once required.
This is useful for larger bots where the need for more memory is required, greater than the 2GB limit on a single process.

## Usage

Place the **discordia-sharder** file in your deps folder.
To use the sharder, all you have to do is require the sharder and pass your data to the module:
`require('discordia-sharder')(file, options)`

### `file`: String
The path to your bot file which needs sharding

### `options`: Table
A table of options that you can pass to the sharder

options | default | information
--------|---------|------------
`port` | `1337` | (number) The port to run the IPC socket on
`maxShards` | `10` | (number) The number of shards your bot needs
`shardsPerProcess` | `1` | (number) The amount of shards running on a process
`waitTime` | `2500` | (number) The time - in ms - to wait between starting each process
`arguments` | `{}` | (array) Command-line arguments to pass to the file [These arguments go from process.argv[6] onwards]
`autoRestart` | `true` | (boolean) Automatically restart process if it errors and closes
`silent` | `false` | (boolean) Print output from child processes to main console
`logFile` | `nil` | (string) Path to the file you wish to log all child process output to
`timestamp` | `!%Y-%m-%dT%H:%M:%S` | (string) Timestamp used to log all output [Passed to `os.date`]

## `returns`: Table
The following data is returned from the module

### `shard_emitter`: EventEmitter
Emits `data` whenever anything is passed from the child process's **stdout**
```lua
shard_emitter:on('data', function(firstShardID, lastShardID, data)
  -- handle data
end)
```

Emits `error` whenever anything is passed from the child process's **stderr**
```lua
shard_emitter:on('error', function(firstShardID, lastShardID, data)
  -- handle error
end)
```

Emits `dead` whenever a child process **exits**
```lua
shard_emitter:on('dead', function(firstShardID, lastShardID)
  -- handle dead process
end)
```

### `ipc_emitter`: EventEmitter
Emits `data` whenever a child process writes to the main process
```lua
ipc_emitter:on('data', function(data)
  -- handle data
end)
```

### `write(str)`: Function
Send data to each child process, eg `write('hello from parent')`

## Setting up bot file
To access the arguments passed, you can use `process.argv`
```lua
local discordia = require('discordia')
table.remove(process.argv, 1)
local port, firstShard, lastShard, maxShards = table.unpack(process.argv)
```
You can also access any arguments you passed in the `arguments` shard option. These are available after `maxShards`

Then, to initiate the client, pass `firstShard` and `lastShard` in the options. All `argv` arguments are **strings**
```lua
local client = discordia.Client({
  firstShard = tonumber(firstShard),
  lastShard = tonumber(lastShard),
  shardCount = tonumber(maxShards) -- Optional
})
```
To access the IPC from the bot, you can do the following:
```lua
local net = require('coro-net')

coroutine.wrap(function()
  local read, write = net.connect(port)
  if not read then
      error('Connection Error', write) -- Could not connect
  else
      coroutine.wrap(function()
        for data in read do
          print(data)
        end
      end)()
    end
  end
end)()
```