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

local socket = require('socket')
require 'platform'
require 'Util'

local writeLocalFileWithCommit

local rootDir       = '.'
local writeFiles    = true
local gitOperations = true
local sep           = package.config:sub(1,1)
local csep          = sep == '/' and ';' or '&'

local countLines = function(s)
   local _, n = s:gsub(".-\n[^\n]*", "")
   return n
end

local crcHistory = {}

-- crcHistory[crcFile] is nil.
-- read the history file to populate it.
--
function readOrCreateCrcHistory(dir, crcFile, backupBranch)
    changeToGitBranch(dir, backupBranch)

    local file = string.format('%s'..sep..'%s', rootDir, crcFile)
    crcHistory[crcFile] = {}

    local fh = io.open(file, 'r')

    if fh == nil then
        fh = io.open(file, 'w')
        if fh == nil then return false end
        fh:close()

    else
        for l in fh:lines() do
            local crc, date = l:match('([%S]+) (.*)')
            printf('read crcFile %s %s, crc %s %s', crcFile, type(crcFile),
                                                    crc, type(crc))
            crcHistory[crcFile][tonumber(crc)] = date
        end
    end

    changeToGitBranch(dir, 'master')
end

function updateCrcHistory(crcFile, clientHash, gitHash)
    local message = date_Y_M_D_h_m_s()

    if gitHash then
        message = gitHash .. ' ' .. message
    end

    crcHistory[crcFile][clientHash] = message

    local historyContents = ''
    for crc, date in pairs(crcHistory[crcFile]) do
        historyContents = historyContents .. string.format('%s %s\n', crc, date)
    end

    local dir, file = crcFile:match('([^/\\]*)[/\\](.*)')

    if not writeLocalFileWithCommit(rootDir, dir, file, historyContents,
                                    'save crc history of Codea file', 'codea_backup')
    then
        crcHistory[crcFile][clientHash] = nil
        printf('update error 2:  %s', file)
        return false
    end

    return true
end

--[[
protocol with git backup of codea file:
codea client     ||      PC server
         -->> SAVE_GET -->> (caller receives this message before this function is called.)
         -->> directory name -->>
         -->> file name -->>
         >>-- file CRC -->>

         <<-- SAVE_SEND/SAVE_NOT_NEEDED/ERROR <<--

         -->> file line count -->>
         -->> line 1 -->>
              ...
         -->> line N -->>

         <<-- SAVE_OKAY/ERROR <<--

         <<-- SERVER_CRC <<--
         <<-- file CRC <<--

         >>-- SEND/NOT_NEEDED -->>

         -->> file line count -->>
         -->> line 1 -->>
              ...
         -->> line N -->>

         <<-- OKAY <<--
--]]
function sendFileBackupLocalVersion(sock)
    -->> directory name -->>
    local project = receiveLine(sock)
    if project == nil then return false end

    -->> file name -->>
    local tab = receiveLine(sock)
    if tab == nil then return false end

    -->> file CRC -->>
    hash = tonumber(receiveLine(sock))
    if hash == nil then return false end

    local file = string.format('%s'..sep..'%s'..sep..'%s', rootDir, project, tab)
    local dir  = string.format('%s'..sep..'%s',    rootDir, project)

    local fh = io.open(file, 'r')
    if fh == nil then
        -- <<-- ERROR <<--
        sock:send(string.format('ERROR 5:  could not open %s\n', file))
        return false
    end

    local serverFileContents = fh:read('*all')
    fh:close()

    if hash == -1 or not gitOperations then
        sock:send('SAVE_NOT_NEEDED\n')

    else
        print('checking hashes of client-side versions..')

        local crcFile = string.format('%s'..sep..'%s.crc_history', project, tab)

        if crcHistory[crcFile] == nil then
            readOrCreateCrcHistory(project, crcFile, 'codea_backup')
        end

        if crcHistory[crcFile][hash] ~= nil then
            sock:send('SAVE_NOT_NEEDED\n')

        else
            sock:send('SAVE_SEND\n')

            nClientContentlines = receiveLine(sock)
            if nClientContentlines == nil then return false end

            local clientContents = {}
            for k=1, tonumber(nClientContentlines) do
                local lne = receiveLine(sock)
                if lne == nil then return false end

                table.insert(clientContents, lne)
            end

            clientContents = table.concat(clientContents, '\n') .. '\n'

            printf("received --|%s|--", clientContents)

            if not writeLocalFileWithCommit(rootDir, project, tab, clientContents,
                                            'backup from Codea before overwriting',
                                            'codea_backup')
            then
                sock:send("ERROR 1\n")
                return false
            end

            local clientHash = messageCrc(clientContents)

            local gitHash = nil

            if gitOperations then
                changeToGitBranch(project, 'codea_backup')

                -- read latest, most recent git hash from codea_backup branch
                local fh = io.popen('cd '..dir..csep..' git log')
                if fh ~= nil then
                    local hash = fh:read('*l')

                    if type(hash) == 'string' then
                        gitHash = hash:match('commit (.*)')
                    end

                    fh:close()
                end

                changeToGitBranch(project, 'master')
            end

            if not updateCrcHistory(crcFile, clientHash, gitHash) then
                sock:send("ERROR 2\n")
                return false
            end

            sock:send("SAVE_OKAY\n")
        end
    end

    hash = messageCrc(serverFileContents)

    -- <<-- SERVER_CRC <<--
    sock:send("SERVER_CRC\n")

    -- <<-- file CRC <<--
    sock:send(hash .. '\n')

    -->> SEND or NOT_NEEDED -->>
    local response = receiveLine(sock)
    if response == nil then return false end

    if response == "NOT_NEEDED" then
        print("Don't send file; iPad response:  ", response)
        return true
    end

    if response ~= "SEND" and response ~= "NOT_NEEDED" then
        print("invalid iPad response:  ", response)
        return false
    end

    printf('Sending %s'..sep..'%s to Codea...', project, tab)

    -->> file line count -->>
    -->> line 1 -->>
    --   ...
    -->> line N -->>
    local nlines = linefeedCount(serverFileContents)
    sock:send(nlines .. "\n")
    sock:send(serverFileContents)

    -- <<-- OKAY <<--
    response = receiveLine(sock)
    if response == nil then return false end

    if response ~= "OKAY" then
        print("iPad error response:  ", response)
        return false
    end

    return true
end

--[[
protocol:
codea client     ||      PC server
         -->> GET -->>  (caller receives this message before this function is called.)
         -->> directory name -->>
         -->> file name -->>

         <<-- SERVER_CRC/ERROR <<--
         <<-- file CRC <<--
         >>-- SEND/NOT_NEEDED -->>

         -->> file line count -->>
         -->> line 1 -->>
              ...
         -->> line N -->>

         <<-- OKAY <<--
--]]
function sendFile(sock)
    -->> directory name -->>
    local project = receiveLine(sock)
    if project == nil then return false end

    -->> file name -->>
    local tab = receiveLine(sock)
    if tab == nil then return false end

    printf('Sending %s'..sep..'%s to Codea...', project, tab)

    local file = string.format('%s'..sep..'%s'..sep..'%s', rootDir, project, tab)

    local fh = io.open(file, 'r')
    if fh == nil then
        -- <<-- ERROR <<--
        sock:send('ERROR 6\n')
        return false
    end

    local contents = fh:read('*all')
    fh:close()

    hash = messageCrc(contents)

    -- <<-- SERVER_CRC <<--
    sock:send("SERVER_CRC\n")

    -- <<-- file CRC <<--
    sock:send(hash .. '\n')

    -->> SEND or NOT_NEEDED -->>
    local response = receiveLine(sock)
    if response == nil then return false end

    if response == "NOT_NEEDED" then
        print("Don't send file; iPad response:  ", response)
        return true
    end

    if response ~= "SEND" and response ~= "NOT_NEEDED" then
        print("invalid iPad response:  ", response)
        return false
    end

    -->> file line count -->>
    -->> line 1 -->>
    --   ...
    -->> line N -->>
    local nlines = linefeedCount(contents)
    sock:send(nlines .. "\n")
    sock:send(contents)

    -- <<-- OKAY <<--
    response = receiveLine(sock)
    if response == nil then return false end

    if response ~= "OKAY" then
        print("iPad error response:  ", response)
        return false
    end

    return true
end

--[[
protocol:
codea client     ||      PC server
         -->> SEND -->>  (caller receives this message before this function is called.)
         -->> directory name -->>
         -->> file name -->>
         -->> client crc -->>

         <<-- SEND/NOT_NEEDED --<<

         -->> file line count -->>
         -->> line 1 -->>
              ...
         -->> line N -->>

         <<-- OKAY <<--
--]]
function receiveFile(sock)
    sock:send('SEND\n')

    local project = receiveLine(sock)
    if project == nil then return false end

    local tab = receiveLine(sock)
    if tab == nil then return false end

    printf('Receiving %s'..sep..'%s ...', project, tab)

    hash = receiveLine(sock)
    if hash == nil then return false end

    local needed = false
    local serverFileContents, serverHash

    local fh = io.open(rootDir..sep..project..sep..tab, 'r')
    if fh == nil then
        needed = true
    else
        serverFileContents = fh:read('*all')
        serverHash = messageCrc(serverFileContents)
        needed = tostring(serverHash) ~= tostring(hash)

        fh:close()
    end

    print('needed', needed, project, tab, hash, serverHash)

    if not needed then
        sock:send("NOT_NEEDED\n")
        return true, false, project, tab, serverFileContents
    end

    sock:send("SEND\n")

    nlines = receiveLine(sock)
    if nlines == nil then return false end

    local contents = {}
    for k=1, tonumber(nlines) do
        lne, err = sock:receive()
        if lne == nil then return false end

        table.insert(contents, lne)
    end

    contents = table.concat(contents, '\n') .. '\n'

    sock:send("OKAY\n")

    return true, true, project, tab, contents
end

function date_Y_M_D_h_m_s()
    local d = os.date('*t')
    return string.format('%04d-%02d-%02d:%02d:%02d:%02d',
                         d.year, d.month, d.day,
                         d.hour, d.min, d.sec)
end

function ensureMasterHasAtLeastOneCommit(xDir)
    if not gitOperations then return end

    ensureDirectoryExists(rootDir, xDir)

    local dir  = string.format('%s'..sep..'%s', rootDir, xDir)

    local foundMaster = false

    local fh = io.popen(string.format('cd %s'..csep..' git branch -a', dir))
    for l in fh:lines() do
        if l:match('master') then foundMaster = true end
    end
    fh:close()

    if not foundMaster then
        local cmd =  string.format('cd %s'..csep..' ', dir)
        cmd = cmd .. string.format('git commit --allow-empty -m "initial master"')

        os_execute(cmd)
    end
end

function changeToGitBranch(xDir, branch)
    if not gitOperations then return end

    assert(branch ~= nil, 'changeToGitBranch nil branch')

    local dir  = string.format('%s'..sep..'%s', rootDir, xDir)

    local foundMaster, foundBranch = false, false

    local fh = io.popen(string.format('cd %s'..csep..' git branch -a', dir))
    for l in fh:lines() do
        if l:match('master') then foundMaster = true end
        if l:match(branch)   then foundBranch = true end
    end
    fh:close()

    if not foundMaster then
        os_execute(string.format('cd %s'..csep..' git commit --allow-empty -m "initial master2"', dir))
    end

    if not foundBranch then
        local cmd =  string.format('cd %s'..csep..' ', dir)
        cmd = cmd .. string.format('git branch %s'..csep..' ', branch)
        cmd = cmd .. string.format('git checkout %s'..csep..' ', branch)
        cmd = cmd .. string.format('git commit --allow-empty -m "initial %s"'..csep..' ', branch)
        cmd = cmd .. string.format('git checkout master')

        os_execute(cmd)
    end

    os_execute(string.format('cd %s'..csep..' git checkout %s', dir, branch))
end

function doGitCommit(xDir, fileName, xCommitMsg)
    if not gitOperations then return end

    local dir  = string.format('%s'..sep..'%s', rootDir, xDir)

    local commitMsg = 'automatic commit from Codea; '

    commitMsg = commitMsg .. xDir..sep..fileName

    if xCommitMsg ~= nil then
        commitMsg = commitMsg .. ':  ' .. xCommitMsg
    end

    local cmd = string.format('cd %s'..csep..' git add %s'..csep..' git status'..csep..' git commit -m "%s"',
                              dir, fileName, commitMsg)
    os_execute(cmd)
end

function commitGitCopyIfNeeded(rootDir, xDir, file, commitMsg)
    if not gitOperations then return end

    local dir  = string.format('%s'..sep..'%s', rootDir, xDir)

    ensureMasterHasAtLeastOneCommit(xDir)

    local cmd =  string.format('cd %s'..csep..' ', dir)
    cmd = cmd .. string.format('git status %s', file)

    local okMsg = 'working directory clean'
    local ok = io.popen(cmd):read('*a'):match(okMsg)

    if ok then return end

    cmd =        string.format('cd %s'..csep..' ', dir)
    cmd = cmd .. string.format('git add %s'..csep..' ', file)
    cmd = cmd .. string.format('git commit -m "%s"', commitMsg)

    os_execute(cmd)
end

function writeLocalFileWithCommit(rootDir, xDir, fileName, contents, commitMsg, branch)
    branch = branch or 'master'
    local result = true

    if gitOperations then
        if branch ~= 'master' then
            changeToGitBranch(xDir, branch)
        else
            ensureMasterHasAtLeastOneCommit(xDir)
        end
    end

    local result2 = writeLocalFile(rootDir, xDir, fileName, contents)
    result = result and result2

    if gitOperations then
        doGitCommit(xDir, fileName, commitMsg)
    end

    if gitOperations and branch ~= 'master' then
        changeToGitBranch(xDir, 'master')
    end

    return result
end

function doServer(client)
    printf("Connection made from %s", client:getpeername())

    while true do
        print('wait for next client command..')
        local rs = client:receive()

        if rs == "GET" then
            print("send a file..")
            print('result:  ', sendFile(client))

        elseif rs == "SAVE_GET" then
            print("send a file but save client-side version to be overwritten..")
            local result = sendFileBackupLocalVersion(client)
            print('result:', result)

        elseif rs == "SEND" then
            print("receive file..")
            local status, needed, dir, file, content = receiveFile(client)
            if not status then
                print('receiveFile error')
            end

            if status and needed and writeFiles then
                commitGitCopyIfNeeded(rootDir, dir, file,
                                      'save locally modified version before overwriting')

                writeLocalFileWithCommit(rootDir, dir, file, content,
                                         'file from Codea')
            end

        elseif rs == "EXIT" then
            print('exit..')
            os.exit(0)

        elseif rs == nil then
            client:close()
            print("client closed; all done.")
            break

        else
            printf('unrecognized command "%s"', rs)
        end
    end
end

local doHelp = function()
   print(
      [[
Options:
     -h         Help message
     --test     Test mode; do not write files
     --no-git   Disable git operations; just copy files
     -P N       Port for connection
     -r dir     Root directory to use for sending and receiving files
       ]]
   )
end

local port = nil

local i = 1
while i <= #arg do
   if arg[i] == '-h' then
      doHelp()
      return

   elseif arg[i] == '--test' then
      writeFiles = false

   elseif arg[i] == '--no-git' then
      gitOperations = false

   elseif arg[i] == '-P' then
      i = i+1
      port = arg[i]

   elseif arg[i] == '-r' then
      i = i+1
      rootDir = arg[i]

   else
      printf('invalid command-line argument "%s"', arg[i])
      os.exit(1)
   end

   i = i+1
end

if port == nil then
   print('You must specify a port: -P NNNN')
   os.exit(1)
end

local connectReceiver = socket.tcp()
connectReceiver:setoption('reuseaddr', true)
connectReceiver = socket.bind('*', tonumber(port))
if connectReceiver == nil then
   return print('Could not open port ' .. port)
end

while true do
    local client = connectReceiver:accept()
    print('got a client..')

    doServer(client)
end
