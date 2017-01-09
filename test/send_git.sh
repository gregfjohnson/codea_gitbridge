#!/bin/bash

rm -rf /tmp/client.d /tmp/server.d
mkdir /tmp/client.d /tmp/server.d

git init /tmp/server.d > /dev/null
../git_bridge.lua -P 8080 -r /tmp/server.d >& /tmp/server.log &

mkdir /tmp/client.d/foo
echo test1 > /tmp/client.d/foo/test1

../sendFile.lua -p 8080 -r /tmp/client.d foo/test1 >& /tmp/client.log

echo EXIT | netnode -k -p 8080
wait

pushd /tmp/server.d > /dev/null
if ! git log 2> /dev/null | fgrep commit > /dev/null; then
    echo "$0:  git commit test failed"
else
    echo "$0:  git commit test passed"
fi
popd > /dev/null

if ! diff /tmp/server.d/foo/test1 /tmp/client.d/foo/test1 > /dev/null; then
    echo "$0:  diff test failed"
else
    echo "$0:  diff test passed"
fi
