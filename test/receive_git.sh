#!/bin/bash

finalize () {
    echo 'yo.'
    if [ -n "$netnode_pid" ]; then
        kill $netnode_pid >& /dev/null
        wait $netnode_pid >& /tmp/null
    fi

    if [ -n "$transfer_pid" ]; then
        kill $transfer_pid >& /dev/null
        wait $transfer_pid >& /tmp/null
    fi

    exit 1
}

trap finalize INT

# clear out and initialize the client-side and server-side directories
    rm -rf /tmp/client.d /tmp/server.d
    mkdir /tmp/client.d /tmp/server.d

    git init /tmp/server.d > /dev/null

# start up netnode so that we can capture tcp interactions between
# client and server.
    netnode -dok -P 8070 -p 8080 >& /tmp/netnode.log &
    netnode_pid=$!

# fire up the server
    ../git_bridge.lua -P 8080 -r /tmp/server.d >& /tmp/server.log &
    transfer_pid=$!

# create a new client-side file, and make a copy of the client-side file
# so that we can use that for tests below..
    mkdir /tmp/client.d/foo
    echo client test1 > /tmp/client.d/foo/test1
    echo client test1 > /tmp/client.d/foo/test1_client_copy

# create a new server-side file, and check it into git
    mkdir /tmp/server.d/foo
    echo server test1 > /tmp/server.d/foo/test1

    pushd /tmp/server.d/foo > /dev/null
    git add test1 > /dev/null
    git commit -m "server test commit" > /dev/null
    popd > /dev/null

# have the client request the server's current version of the file.
# this should cause the client's copy, which is about to be overwritten,
# to be saved in the codea_backup branch on the server.
    ../receiveFile.lua -p 8070 -r /tmp/client.d foo/test1 >> /tmp/client.log

# make sure the client side and server side versions now match
    if ! diff /tmp/server.d/foo/test1 /tmp/client.d/foo/test1 > /dev/null; then
        echo "$0:  test failed"
    else
        echo "$0:  test passed"
    fi

# make sure backed up version on the server matches the client's pre-updated version
# and that we have 1 line of crc_history and 1 crc_history git commit
    pushd /tmp/server.d/foo >& /dev/null
    git checkout codea_backup >& /dev/null

    if ! diff test1 /tmp/client.d/foo/test1_client_copy > /dev/null; then
        echo "$0:  test failed"
    else
        echo "$0:  test passed"
    fi

    if [ "`wc -l test1.crc_history | sed -e 's/ .*//'`" -eq 1 ]; then
        echo "$0:  crc_history test passed"
    else
        echo "$0:  crc_history test failed"
    fi

    if [ "`git log | fgrep crc_history | wc -l | sed -e 's/ .*//'`" -eq 1 ]; then
        echo "$0:  crc_history log test passed"
    else
        echo "$0:  crc_history log test failed"
    fi

    git checkout master >& /dev/null
    popd >& /dev/null

# do two receive operations.  the first should do something (server-side
# version of the file changed), but the second should do nothing.
    ../receiveFile.lua -p 8070 -r /tmp/client.d foo/test1 >> /tmp/client.log
    ../receiveFile.lua -p 8070 -r /tmp/client.d foo/test1 >> /tmp/client.log

# make sure server-side and client-side versions of the file match
    if ! diff /tmp/server.d/foo/test1 /tmp/client.d/foo/test1 > /dev/null; then
        echo "$0:  test failed"
    else
        echo "$0:  test passed"
    fi

# make sure we have 2 lines in the crc_history file and 2 commits
    pushd /tmp/server.d/foo >& /dev/null
    git checkout codea_backup >& /dev/null

    if [ "`wc -l test1.crc_history | sed -e 's/ .*//'`" -eq 2 ]; then
        echo "$0:  crc_history test passed"
    else
        echo "$0:  crc_history test failed"
    fi

    if [ "`git log | fgrep crc_history | wc -l | sed -e 's/ .*//'`" -eq 2 ]; then
        echo "$0:  crc_history log test passed"
    else
        echo "$0:  crc_history log test failed"
    fi

    git checkout master >& /dev/null
    popd >& /dev/null

# shut down and restart the server, so that crc history must be read from disk
    echo EXIT | netnode -k -p 8070
    wait $transfer_pid

    ../git_bridge.lua -P 8080 -r /tmp/server.d >> /tmp/server.log 2>&1 &
    transfer_pid=$!

# do a file receive from the client, which should be a no-op since it
# already has a crc-matching version of the file.
    ../receiveFile.lua -p 8070 -r /tmp/client.d foo/test1 >> /tmp/client.log

# see if the server and client versions of the transfered file match.
    if ! diff /tmp/server.d/foo/test1 /tmp/client.d/foo/test1 > /dev/null; then
        echo "$0:  test failed"
    else
        echo "$0:  test passed"
    fi

# see if there are exactly two crc_history entries and two commit messages
    pushd /tmp/server.d/foo >& /dev/null
    git checkout codea_backup >& /dev/null

    if [ "`wc -l test1.crc_history | sed -e 's/ .*//'`" -eq 2 ]; then
        echo "$0:  crc_history test passed"
    else
        echo "$0:  crc_history test failed"
    fi

    if [ "`git log | fgrep crc_history | wc -l | sed -e 's/ .*//'`" -eq 2 ]; then
        echo "$0:  crc_history log test passed"
    else
        echo "$0:  crc_history log test failed"
    fi

    git checkout master >& /dev/null
    popd >& /dev/null

# tell the server to exit, and wait for it to actually exit
    echo EXIT | netnode -k -p 8070
    wait $transfer_pid

# close down the network program used to observe tcp traffic
kill $netnode_pid >& /dev/null
wait $netnode_pid >& /tmp/null
