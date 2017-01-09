-----------------------------------------------------------------------------
-- Copyright (c) Greg Johnson, Gnu Public Licence v. 2.0.
-----------------------------------------------------------------------------
local debug = false

function os_execute(cmd)
    if debug then print('execute', cmd) end

    return os.execute(cmd)
end

function ensureDirectoryExists(rootDir, xDir)
    local dir  = string.format('%s/%s', rootDir, xDir)

    os_execute('mkdir -p ' .. dir)
end

function writeLocalFile(rootDir, xDir, fileName, contents)
    local file = string.format('%s/%s/%s', rootDir, xDir, fileName)

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
