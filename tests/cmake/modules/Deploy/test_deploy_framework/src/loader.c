#include <dlfcn.h>
#include <stdio.h>

// Loads the library named by the first argument from outside the install tree.
// The loader has no rpaths of its own, so only the rpaths of that library
// resolve its dependencies.
int main(int argc, char **argv) {
    if (argc < 2) {
        return 2;
    }

    void *handle = dlopen(argv[1], RTLD_NOW);
    if (!handle) {
        fprintf(stderr, "%s\n", dlerror());
        return 1;
    }
    return 0;
}
