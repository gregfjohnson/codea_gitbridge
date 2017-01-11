#! /usr/bin/env lua
-----------------------------------------------------------------------------
-- Copyright (c) Greg Johnson, Gnu Public Licence v. 2.0.
-----------------------------------------------------------------------------

local scriptDir = debug.getinfo(1).source:match('@(.*)')
                                         :gsub('[/\\][^/\\]*$', '')
if #scriptDir > 0 then
    package.path = scriptDir .. '/?.lua;' .. package.path
end

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
    local host, port, message, response = 'localhost', 8080, 'test', 'response'

    local i = 1
    while i <= #arg do
       if arg[i] == '-p' then
          i = i+1
          port = arg[i]

       elseif arg[i] == '-host' then
          i = i+1
          host = arg[i]

       elseif arg[i] == '-m' then
          i = i+1
          message = arg[i]

       elseif arg[i] == '-resp' then
          i = i+1
          response = arg[i]

       end

       i = i+1
    end
    
    local sock = socket.connect(host, tonumber(port))
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
