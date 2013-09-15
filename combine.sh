set -e

echo -n "" > emu.lua

for FNAME in ./src/luamips.lua ./src/gen/doop.lua ./src/memoryinfo.lua ./src/power.lua ./src/serial.lua ./src/main.lua
do
    echo "--!!FILE $FNAME" >> emu.lua
    cat $FNAME >> emu.lua
done

echo "build success"
