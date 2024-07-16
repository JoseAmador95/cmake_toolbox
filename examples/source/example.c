#include "example.h"

#include "dependency.h"

int example_foo(int a, int b)
{
    return a + b;
}

void* example_malloc(int size)
{
    return dependency_malloc(size);
}