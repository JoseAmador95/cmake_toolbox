// SPDX-License-Identifier: MIT
#include "example_cexception.h"

void example_divide(int a, int b, int *result)
{
    if (b == 0)
    {
        Throw(ERROR_DIVISION_BY_ZERO);
    }
    *result = a / b;
}
