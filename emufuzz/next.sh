set -e
rm -f kern
rm -rf ./cur_fuzz/
mkdir ./cur_fuzz/
cp ./template/* ./cur_fuzz/
cp -r ./csmith_headers ./cur_fuzz/
csmith --concise --no-argc --quiet --no-hash-value-printf > rand_prog.c
rm  ./platform.info #created by csmith, wrong since we are cross compiling
