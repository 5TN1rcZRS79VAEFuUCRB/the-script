# todo: after every answered card, count today's due cards here (instant: Anki already has
# them in memory), write the number where the todo daemon reads it, and wake the daemon, so
# the top bar's "Anki: N cards" drops the moment you answer.
import os
import signal
from datetime import date

from aqt import gui_hooks, mw

RUN = os.environ.get("XDG_RUNTIME_DIR", os.path.expanduser("~/.cache"))
COUNT = os.path.join(RUN, "todo-anki")
PIDFILE = os.path.join(RUN, "todo.pid")


def answered(*_):
    try:
        due = sum(n.new_count + n.learn_count + n.review_count for n in mw.col.sched.deck_due_tree().children)
        with open(COUNT + ".tmp", "w") as f:
            f.write(f"{date.today().isoformat()} {due}\n")
        os.replace(COUNT + ".tmp", COUNT)
        with open(PIDFILE) as f:
            os.kill(int(f.read()), signal.SIGUSR1)
    except (OSError, ValueError, AttributeError):
        pass  # no daemon running, or no collection open: nothing to tell


gui_hooks.reviewer_did_answer_card.append(answered)
