tests here must be self contained into a single c file. They must have a single function with the following
signature. 

int TESTENTRY() {

}

try to make things static to avoid polluting the namespaces of other tests and causing linker errors.