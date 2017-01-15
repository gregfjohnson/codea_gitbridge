#! /usr/bin/env lua
-----------------------------------------------------------------------------
-- Copyright (c) Greg Johnson, Gnu Public Licence v. 2.0.
-----------------------------------------------------------------------------
local scriptDir = debug.getinfo(1).source:match('@(.*)')

if scriptDir:match('[/\\]') then
    scriptDir = scriptDir:gsub('[/\\][^/\\]*$', '')
else
    scriptDir = '.'
end

package.path =    scriptDir .. '/GitBridge/?;'
               .. scriptDir .. '/GitBridge/?.lua;' .. package.path


socket = require 'socket'
require 'Util'
require 'platform'

local doHelp = function()
   print(
      [[
Options:
     -h       Help message
     -p N     Port for connection
     -resp response   Root directory to use for sending and receiving files
       ]]
   )
end

function main()
    local port, message, response = 8080, 'test', 'response'

    local i = 1
    while i <= #arg do
       if arg[i] == '-p' then
          i = i+1
          port = arg[i]

       elseif arg[i] == '-m' then
          i = i+1
          message = arg[i]

       elseif arg[i] == '-resp' then
          i = i+1
          response = arg[i]

       end

       i = i+1
    end
    
    local sock = socket.connect('localhost', tonumber(port))
    if sock == nil then
        print('could not connect')
        os.exit(1)
    end
    sock:setoption('reuseaddr', true)
    sock:send(message .. '\n')

    repeat
        local msg = receiveLine(sock)
        print('response', msg)
        if msg == nil then break end
    until msg:match(response)

    sock:close()
    local exitTime = os.time() + 2
    while os.time() < exitTime do end
end

if debug.getinfo(3) == nil then
    main()
end
