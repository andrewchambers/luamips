
emu.lua:  ./src/*.lua ./src/gen/doop.lua
	bash combine.sh

./src/gen/doop.lua: ./disgen/*.py ./disgen/mips.json
	mkdir -p ./src/gen
	python ./disgen/disgen.py ./disgen/luadisgen.py ./disgen/mips.json > ./src/gen/doop.lua
