#!/bin/bash
# this is something that is too much work and code ugliness to
# be worth the benefit.

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
    rm -rf /tmp/client.d /tmp/server.d /tmp/client.log /tmp/server.log
    mkdir /tmp/client.d /tmp/server.d

    git init /tmp/server.d > /dev/null

# fire up the server
    ../git_bridge.lua -P 8080 -r /tmp/server.d >& /tmp/server.log &
    transfer_pid=$!
    sleep 1

# start up netnode so that we can capture tcp interactions between
# client and server.
    netnode -dok -P 8070 -p 8080 >& /tmp/netnode.log &
    netnode_pid=$!

# create new client-side files to send
    mkdir /tmp/client.d/foo
    echo client test1 > /tmp/client.d/foo/test1
    echo client test2 > /tmp/client.d/foo/test2
    echo client test3 > /tmp/client.d/foo/test3

# start a group of transactions that should be part of the same git commit
    ../sendMessage.lua -p 8070 -m "TRANSACTION_START" -resp "TRANSACTION_START"

# do multiple sends
    ../sendFile.lua -p 8070 -r /tmp/client.d foo/test1 >> /tmp/client.log
    ../sendFile.lua -p 8070 -r /tmp/client.d foo/test2 >> /tmp/client.log
    ../sendFile.lua -p 8070 -r /tmp/client.d foo/test3 >> /tmp/client.log

# complete the group of transactions
    ../sendMessage.lua -p 8070 -m "TRANSACTION_COMPLETE" -resp "TRANSACTION_COMPLETE"

# make sure the client side and server side versions now match
    for n in test1 test2 test3; do
        if ! diff /tmp/server.d/foo/$n /tmp/client.d/foo/$n > /dev/null; then
            echo "$0:  test failed"
        else
            echo "$0:  test passed"
        fi
    done

# make sure we have 2 commits (initial, and then a commit that combines the transation)
    pushd /tmp/server.d/foo >& /dev/null

    if [ "`git log | fgrep commit | wc -l | sed -e 's/ .*//'`" -eq 2 ]; then
        echo "$0:  commit count log passed"
    else
        echo "$0:  commit count failed"
    fi

    popd >& /dev/null

# tell the server to exit, and wait for it to actually exit
    echo EXIT | netnode -k -p 8070
    wait $transfer_pid

# close down the network program used to observe tcp traffic
kill $netnode_pid >& /dev/null
wait $netnode_pid >& /tmp/null
