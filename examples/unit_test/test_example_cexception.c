// SPDX-License-Identifier: MIT
#include "unity.h"
#include "CException.h"
#include "example_cexception.h"

void setUp(void)
{
}

void tearDown(void)
{
}

void test_divide_success(void)
{
    int result = 0;
    example_divide(10, 2, &result);
    TEST_ASSERT_EQUAL_INT(5, result);
}

void test_divide_by_zero_throws(void)
{
    CEXCEPTION_T e = CEXCEPTION_NONE;
    int result     = 0;
    Try
    {
        example_divide(10, 0, &result);
        TEST_FAIL_MESSAGE("Expected exception was not thrown");
    }
    Catch(e)
    {
        TEST_ASSERT_EQUAL_INT((int)ERROR_DIVISION_BY_ZERO, (int)e);
    }
}
