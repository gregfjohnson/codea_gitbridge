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
    mkdir /tmp/client.d/foo
    mkdir /tmp/server.d/foo

    git init /tmp/server.d > /dev/null

    #pushd /tmp/server.d/foo > /dev/null
    #git commit --allow-empty -m 'initial empty commit'
    #git branch codea_backup
    #git checkout codea_backup
    #git commit --allow-empty -m 'initial empty commit'
    #git checkout master
    #popd > /dev/null

# start up netnode so that we can capture tcp interactions between
# client and server.
    netnode -dok -P 8070 -p 8080 >& /tmp/netnode.log &
    netnode_pid=$!

# fire up the server
    ../git_bridge.lua -P 8080 -r /tmp/server.d >& /tmp/server.log &
    transfer_pid=$!

for n in 1 2 3 4 5 6 7 8; do
    # create a new client-side file (will be backed up on server side)
        echo client test $n > /tmp/client.d/foo/test$n

    # create a new server-side file, and check it into git
        echo server test $n > /tmp/server.d/foo/test$n

        pushd /tmp/server.d/foo > /dev/null
        git add test$n > /dev/null
        git commit -m "server test $n commit" > /dev/null
        popd > /dev/null

    # have the client request the server's current version of the file.
        ../receiveFile.lua -p 8070 -r /tmp/client.d foo/test$n >> /tmp/client.log

    # make sure the client side and server side versions now match
        if ! diff /tmp/server.d/foo/test$n /tmp/client.d/foo/test$n > /dev/null; then
            echo "$0:  test failed"
        else
            echo "$0:  test passed"
        fi
done

# tell the server to exit, and wait for it to actually exit
    echo EXIT | netnode -k -p 8070
    wait $transfer_pid

# close down the network program used to observe tcp traffic
kill $netnode_pid >& /dev/null
wait $netnode_pid >& /tmp/null
