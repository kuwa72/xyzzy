#include <stdio.h>
#include "util.h"

int main(void)
{
    int v = util_clamp(15, 0, 10)
    printf("%d\n", v);
    return 0;
}
