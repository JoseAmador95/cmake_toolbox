#include "example.h"
#include "mock_dependency.h"
#include "unity.h"

void setUp(void)
{
    // Set up any necessary resources before each test
}

void tearDown(void)
{
    // Clean up any resources after each test
}

void test_foo(void)
{
    TEST_ASSERT_EQUAL(3, example_foo(1, 2));
}

void test_malloc(void)
{
    dependency_malloc_ExpectAndReturn(10, NULL);
    void* ptr = example_malloc(10);
    TEST_ASSERT_NULL(ptr);
}