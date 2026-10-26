#
# ~/.bash_profile
#

# Put ~/.local/bin (claude, the-script's tools) on PATH for every login, including SSH.
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

[[ -f ~/.bashrc ]] && . ~/.bashrc
