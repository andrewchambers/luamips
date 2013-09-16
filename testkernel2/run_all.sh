set -e

echo "--- Test Start ---"

TOTAL=0
FAILS=0
PASSES=0

for TEST in `ls ./tests/`
do
    TOTAL=$(($TOTAL + 1))
    echo "TEST: "`tput bold`"$TEST"`tput sgr0`
    bash select.sh $TEST
    if bash run.sh 2> /dev/null ; then
        PASSES=$(($PASSES + 1))
        echo `tput setaf 2`"  PASS"`tput sgr0`
    else
        FAILS=$(($FAILS + 1))
        echo `tput setaf 1`"  FAIL"`tput sgr0`
    fi
done

echo ""
echo "Passed $PASSES/$TOTAL ($FAILS failed)"
