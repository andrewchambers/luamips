set -e

if [ $# -ne 1 ] ; then
    echo "please specify number to save"
    exit 1
fi

n=$1

while [ $n -ne 0 ] ;
do
    bash search.sh
    creduce ./interesting.sh ./rand_prog.c
    bash save.sh
    n=$(($n - 1))
done
