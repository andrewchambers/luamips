set -e

if [ $# -ne 1 ] ; then
    echo "usage: $0 TESTNAME"
    exit 0
fi

rm -rf ./cur_test/
rm -f ./kern ./kern.srec ./qemu.out ./luamips.out
mkdir ./cur_test/ 

cp -r ./template/* ./cur_test/

if test -d ./tests/$1 ; then
    cp ./tests/$1/* ./cur_test/
else
    cp ./tests/$1 ./cur_test/
fi

echo \"$1\" > ./cur_test/CURTEST

bash build.sh
