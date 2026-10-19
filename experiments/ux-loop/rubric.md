# UX judge rubric

You are judging a transcript of a keystroke-driven run of the xyzzy editor
(terminal UI). The transcript contains one screen dump per step plus the
cursor position after each step. The task's goal is given; judge the
experience the transcript shows, not just success.

Score each axis 1-5:

- **outcome**: did the workflow reach the goal state (screen shows the target)?
- **feedback**: did the editor surface what happened (status line messages,
  visible buffers, error text the user can act on)?
- **friction**: how much of the work was fighting the UI vs doing the task?
  (high score = low friction: few prompts, no confusing states, no dead ends)
- **discoverability**: from the transcript, could a reasonable user tell what
  to do next (prompts are named, buffers are named, output is labelled)?

Rules:
- Score what the transcript shows. Do not invent behaviour you cannot see.
- A step that produced an error message counts against friction unless the
  message is actionable.
- If the goal was not reached, outcome <= 2 regardless of how nice it looked.

Reply with ONLY a JSON object:

    {"tasks": {"<task-id>": {"outcome": N, "feedback": N, "friction": N,
                             "discoverability": N, "note": "one sentence"}}}
