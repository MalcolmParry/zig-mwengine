#!/bin/bash

cd "$(dirname $0)"
cd ..
rm -rfv .zig-cache 2> /dev/null
rm -rfv zig-out 2> /dev/null
rm -rfv Test/res/Shaders 2> /dev/null
rm -rfv Test/mwengine-profile-start.json 2> /dev/null
