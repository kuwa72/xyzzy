#include "gen-stdafx.h"

typedef void (*GENACTION) (int argc, char **argv);

typedef struct
{
  const char *command;
  GENACTION action;
} gensrc_action;

#if defined(GEN_SRC1)
#include "gen-action1.h"
#elif defined(GEN_SRC2)
#include "gen-action2.h"
#endif

int
main (int argc, char **argv)
{
  if (argc < 2)
    {
      fprintf (stderr, "too few argments\n");
      exit (2);
    }

  const char *cmd = argv[1];
  for (int i = 0; i < numberof (actions); i++)
    {
      if (!strcmp (cmd, actions[i].command))
        {
          actions[i].action (argc - 1, &argv[1]);
          return 0;
        }
    }

  fprintf (stderr, "unknown command: %s\n", cmd);
  exit (2);
}
