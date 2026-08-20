# ---------------------------------------------------------------------------
# tt_database shell helpers — run the project's make targets from anywhere.
#
# Install (oh-my-zsh picks up every *.zsh in its custom dir automatically):
#
#     ln -s "$PWD/tt_aliases.zsh" "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/tt_database.zsh"
#
# or, without oh-my-zsh, add to ~/.zshrc:
#
#     source /path/to/tt_database/tt_aliases.zsh
#
# make -C chdir's into the project before running any recipe, so docker
# compose, ./haproxy/... and restore.log resolve against the project rather
# than whatever directory you happen to be standing in.
# ---------------------------------------------------------------------------

# Location of the project. Defaults to wherever this file lives, following
# symlinks, so a symlink from the oh-my-zsh custom dir still finds it. Set
# TT_DB_DIR yourself before sourcing to override.
export TT_DB_DIR="${TT_DB_DIR:-${0:A:h}}"

if [[ ! -f "$TT_DB_DIR/Makefile" ]]; then
  print -u2 "tt_aliases.zsh: no Makefile in $TT_DB_DIR — set TT_DB_DIR to the project root"
  return 1
fi

# tt <target> [...]   any make target; bare `tt` shows the active environment
tt() {
  if (( $# == 0 )); then
    set -- show_active_env
  fi
  make --no-print-directory -C "$TT_DB_DIR" "$@"
}

# status
alias ttlog='tt show_restore_log'     # last backup / restore per environment
alias ttenv='tt show_active_env'      # which env answers on localhost:5432

# point the proxy at one environment — this is what `localhost:5432` answers
# as from then on. Restarts db-proxy, so open connections drop.
alias ttdev='tt activate_dev'
alias ttqa='tt activate_qa'
alias ttsnap='tt activate_snap'
alias ttprod='tt activate_prod'

# ttactivate <env> — the same switch, for when the env name is in a variable
ttactivate() { tt "activate_${1:?usage: ttactivate dev|qa|snap|prod}"; }

# ttrefresh <env> — dump the remote env, then restore it over the local copy
ttrefresh() { tt "${1:?usage: ttrefresh dev|qa|snap|prod}_refresh"; }

# ttbk <env> / ttrs <env> — run just one half of a refresh
ttbk() { tt "${1:?usage: ttbk dev|qa|snap|prod}_backup"; }
ttrs() { tt "${1:?usage: ttrs dev|qa|snap|prod}_restore"; }

# containers + jumping to the project
alias ttup='tt up'
alias ttcd='cd "$TT_DB_DIR"'
# No alias for `down`: it runs `docker compose down -v`, which deletes the
# named volumes and wipes every restored database. Type `tt down` when you
# actually mean it.

# tab-complete real make targets after `tt`
_tt() { compadd ${(f)"$(grep -oE '^[a-zA-Z0-9_-]+:' "$TT_DB_DIR/Makefile" | tr -d ':')"} }
(( $+functions[compdef] )) && compdef _tt tt
