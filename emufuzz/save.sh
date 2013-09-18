mkdir -p interesting
STAMP=`date +%s`
#possible race if two saves are done VERY rapidly, doesnt matter really..
cp ./rand_prog.c ./interesting/rand_prog_$STAMP.c
