
emu.lua:  ./src/*.lua ./src/gen/doop.lua
	bash combine.sh

./src/gen/doop.lua: ./disgen/*.py ./disgen/mips.json
	mkdir -p ./src/gen
	python ./disgen/disgen.py ./disgen/luadisgen.py ./disgen/mips.json > ./src/gen/doop.lua

clean:
	rm -vrf ./src/gen/
	rm -fv ./emu.lua
	rm -fv ./disgen/*.pyc
	rm -vrf ./disgen/__pycache__/
