#include <stdio.h>

static void alpha_init(void)
{
    puts("alpha");
}

static int beta_compute(int x)
{
    return x + 40;
}

int main(void)
{
    alpha_init();
    printf("%d\n", beta_compute(2));
    return 0;
}
