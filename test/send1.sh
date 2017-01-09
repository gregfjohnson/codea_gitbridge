#!/bin/bash

rm -rf /tmp/client.d /tmp/server.d
mkdir /tmp/client.d /tmp/server.d

../git_bridge.lua --no-git -P 8080 -r /tmp/server.d >& /tmp/server.log &

mkdir /tmp/client.d/foo
echo test1 > /tmp/client.d/foo/test1

../sendFile.lua -p 8080 -r /tmp/client.d foo/test1 > /tmp/client.log

echo EXIT | netnode -k -p 8080
wait

if ! diff /tmp/server.d/foo/test1 /tmp/client.d/foo/test1 > /dev/null; then
    echo "$0:  test failed"
else
    echo "$0:  test passed"
fi
