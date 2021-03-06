#!/bin/bash

finalize () {
    echo 'yo.'
    kill $netnode_pid >& /dev/null
    wait $netnode_pid >& /tmp/null
    exit 1
}

trap finalize INT

rm -rf /tmp/client.d /tmp/server.d
mkdir /tmp/client.d /tmp/server.d

netnode -dok -P 8070 -p 8080 >& /tmp/netnode.log &
netnode_pid=$!

../git_bridge.lua --no-git -P 8080 -r /tmp/server.d >& /tmp/server.log &
transfer_pid=$!
sleep 1

mkdir /tmp/server.d/foo
echo server test1 > /tmp/server.d/foo/test1

mkdir /tmp/client.d/foo
echo client test1 > /tmp/client.d/foo/test1

../receiveFile.lua -p 8070 -r /tmp/client.d foo/test1 > /tmp/client.log

echo client test2 > /tmp/client.d/foo/test1

../receiveFile.lua -p 8070 -r /tmp/client.d foo/test1 > /tmp/client.log

echo EXIT | netnode -k -p 8070
wait $transfer_pid

if ! diff /tmp/server.d/foo/test1 /tmp/client.d/foo/test1 > /dev/null; then
    echo "$0:  diff test failed"
else
    echo "$0:  diff test passed"
fi

kill $netnode_pid >& /dev/null
wait $netnode_pid >& /tmp/null
