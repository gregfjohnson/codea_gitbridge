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
require 'Receivefile'

local sep = package.config:sub(1,1)

function needFile(dir, name, fileCrcValue)
    local fh = io.open(dir..sep..name, 'r')
    if fh == nil then
        printf('needFile 1')
        return true
    end

    local contents = fh:read('*a')
    fh:close()
    if contents == nil then
        printf('needFile 2')
        return true
    end

    local hash = messageCrc(contents)

    printf('needFile:  %s %s %s %s; returns %s',
           hash, fileCrcValue,
           type(hash), type(fileCrcValue),
           tostring(tostring(hash) ~= fileCrcValue))

    return tostring(hash) ~= fileCrcValue
end

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
        dir, fname = fileArg:match('(.*)[/\\](.*)')
        if dir == nil or fname == nil then
            dir, fname = '.', fileArg
        end
    end

    local sock = socket.connect('localhost', tonumber(port))

    if sock == nil then
        print('could not open socket.')
        os.exit(1)
    end

    sock:settimeout(5.0)
    sock:setoption('keepalive', true)

    local localContents

    local file = rootDir..sep..dir..sep..fname
    local f = io.open(file, 'r')
    if f ~= nil then
        localContents = f:read('*a')
        f:close()
    end

    local fileContents = receiveFileBackupLocalVersion(sock,
                             dir, fname, localContents,
                             needFile)
    sock:close()

    print(string.format('received --|%s|--', fileContents))

    if type(fileContents) == 'string' then
        writeLocalFile(rootDir, dir, fname, fileContents)
    end
end

if debug.getinfo(3) == nil then
    main()
end
