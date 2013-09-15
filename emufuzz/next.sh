rm -f kern
cp ./template/* ./
csmith --concise --no-argc --quiet --no-hash-value-printf --no-math64 > rand_prog.c
rm  ./platform.info #created by csmith, wrong since we are cross compiling
