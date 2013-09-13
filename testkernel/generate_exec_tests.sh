set -e

echo "#include \"test.h\"" > exec_tests.gen.c
echo "" >> exec_tests.gen.c

for f in `ls ./exec/*.c`
do
    TESTNAME=exec_test_`basename $f .c`
    echo "int $TESTNAME();" >> exec_tests.gen.c 
    cat $f | sed s/TESTENTRY/$TESTNAME/g > $TESTNAME.gen.c
done

echo "" >> exec_tests.gen.c
echo "void test_exec() {" >> exec_tests.gen.c
    echo "    outs(\"starting exec tests...\");" >> exec_tests.gen.c
    for f in `ls ./exec/*.c`
    do
        TESTNAME=exec_test_`basename $f .c`
        echo "    if($TESTNAME() != 0) {"  >> exec_tests.gen.c
        echo "        outs(\"\nFAIL:\");"  >> exec_tests.gen.c
        echo "        putb(' '); putb(' ');"  >> exec_tests.gen.c
        echo "        outs(\"$TESTNAME\");"  >> exec_tests.gen.c
        echo "    } else {"  >> exec_tests.gen.c
        echo "        putb('.');"  >> exec_tests.gen.c
        echo "    }"  >> exec_tests.gen.c
        echo "    "  >> exec_tests.gen.c
    done
    echo "    outs(\"\nfinished exec tests...\");" >> exec_tests.gen.c

echo "}"  >> exec_tests.gen.c
