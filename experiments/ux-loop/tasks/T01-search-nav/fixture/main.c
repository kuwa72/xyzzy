#include <stdio.h>
#include "util.h"

static int helper(int x)
{
    return x * 2 + 1;
}

int main(void)
{
    int total = 0;
    for (int i = 0; i < 10; i++)
        total += helper(i);
    printf("total=%d\n", total);
    return 0;
}
