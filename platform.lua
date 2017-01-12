-----------------------------------------------------------------------------
-- Copyright (c) Greg Johnson, Gnu Public Licence v. 2.0.
-----------------------------------------------------------------------------
local debug = true

local sep = package.config:sub(1,1)

function os_execute(cmd)
    if debug then print('execute', cmd) end

    return os.execute(cmd)
end

function ensureDirectoryExists(rootDir, xDir)
    local dir  = string.format('%s'..sep..'%s', rootDir, xDir)

    os_execute('mkdir -p ' .. dir)
end

function writeLocalFile(rootDir, xDir, fileName, contents)
    local file = string.format('%s'..sep..'%s'..sep..'%s', rootDir, xDir, fileName)
    if debug then print('write local file', file) end

    ensureDirectoryExists(rootDir, xDir)

    fh, err, errno = io.open(file, "w")
    if fh == nil then
        printf("Error in saving file %s:  error %d (%s)", file, errno, err)
        return false
    end

    fh:write(contents)
    fh:close()

    return true
end
