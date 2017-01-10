#! /usr/bin/env lua
-----------------------------------------------------------------------------
-- Copyright (c) Greg Johnson, Gnu Public Licence v. 2.0.
-----------------------------------------------------------------------------

-- some kung fu to find the directory containing this file
-- and add it to the package search path..

local stream = io.popen('readlink -f ' .. debug.getinfo(1).source:match('@(.*)'))
local thisFile = stream:read('*l')
stream:close()
local scriptDir = thisFile:match('.*/')
package.path = scriptDir .. '?.lua;' .. package.path

socket = require 'socket'
require 'util'
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
    sock:keepalive('setoption', true)
    sock:send(message .. '\n')
    sock:close()

    repeat
        local msg = receiveLine(sock)
        if sock == nil then
            print('could not open socket.')
            os.exit(1)
        end
    until msg:match(response)
end

if debug.getinfo(3) == nil then
    main()
end