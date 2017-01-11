#! /usr/bin/env lua
-----------------------------------------------------------------------------
-- Copyright (c) Greg Johnson, Gnu Public Licence v. 2.0.
-----------------------------------------------------------------------------

local thisFile = debug.getinfo(1).source:match('@(.*)')
if thisFile then
    local scriptDir = thisFile:match('.*/')
    package.path = scriptDir .. '?.lua;' .. package.path
    package.path = scriptDir .. '/GitBridge/?;' .. package.path
end

socket = require 'socket'
require 'util'
require 'platform'
require 'Sendfile'

local rootDir = '.'

local doHelp = function()
   print(
      [[
Options:
     -h       Help message
     -p N     Port for connection
     -r dir   Root directory to use for sending and receiving files
     dir/file File to get from the server
       ]]
   )
end

function main()
    local port 
    local dir
    local fname
    local fileArg

    local i = 1
    while i <= #arg do
       if arg[i] == '-h' then
          doHelp()
          return

       elseif arg[i] == '-p' then
          i = i+1
          port = arg[i]

       elseif arg[i] == '-r' then
          i = i+1
          rootDir = arg[i]

       else
          fileArg = arg[i]
       end

       i = i+1
    end
    
    if port == nil then
        printf("need a port..")
        os.exit(1)
    end

    if fileArg == nil then
        printf("need a file..")
        os.exit(1)

    else
        dir, fname = fileArg:match('(.*)/(.*)')
        if dir == nil or fname == nil then
            dir, fname = '.', fileArg
        end
    end

    local sock = socket.connect('localhost', tonumber(port))

    if sock == nil then
        print('could not open socket.')
        os.exit(1)
    end

    sock:setoption('keepalive', true)
    sock:settimeout(5.0)

    local fileName = rootDir..'/'..dir..'/'..fname
    print(fileName)
    local f = io.open(fileName, 'r')
    local contents = f:read('*a')
    f:close()

    sendFile(sock, dir, fname, contents)

    sock:close()
end

if debug.getinfo(3) == nil then
    main()
end
