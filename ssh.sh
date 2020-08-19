# Copyright (c) 2016 Uwe Werler <uwe.werler@retiolum.eu>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

_path=$0
_path=${_path%/*}
_sock=$0
_sock=${_sock##*/}
_sock=${_sock%%.*}
_ssh_config=${_path}/${_sock}.conf
_style_map=${_path}/${_sock}.map
_sess="SSH"
_tabw="15"  # width of the tabs created

# run tmux with some defaults like utf-8 support and at an separate socket
_tmux="tmux -2 -u -L ${_sock}"

usage(){

echo \
  "
usage: /bin/sh $0 -cr [args]
  -c : start server and connect xterm or attach term to detached session
  -c args: start server and run ssh with args or start ssh and attach xterm
  -r sets pane title of the active pane

 For usage from within shell create an alias like this:
  alias ssh=\"sh $0 -c\"

 For usage from within cwm put this in your ~/.cwmrc:
  command term \'ksh -c \". $0 -c \$1\"\'
  bind CM-Return xterm
  #...and if autogroup preferred
  autogroup 1 \"${_sess},XTerm\"

  If xdotool is installed it focusses automatically to the xterm running this
  tmux session or attaches a xterm if the session is detached.
"
exit 1
}

_checkname(){

  for _l; do

    case $_l in hostname)
 
      # make stupid check if hostname is an IP 
      [[ ${SHELL} == *bash ]] && shopt -s extglob
      _ip=${2##+([0-9]).+([0-9]).+([0-9]).+([0-9])}
      _ip=${_ip##+([0-9a-f]):+([0-9a-f]):+([0-9a-f]):*([0-9a-f:]):+([0-9a-f])}

      if [[ -z ${_ip} ]]; then

        _isip=1
        _host=$(dig +short -x ${2})

        [[ -n "${_host}" ]] || _host=${2}

      else

        _host=${2}
      fi
      break
      ;;
    esac

    shift
  done
}

_runxdotool(){
 
  # with xdotool installed, activate the window or reattach to a detached session
  if type xdotool >/dev/null; then

    _winid="xdotool search --classname ${_sess}"

    [[ -z $(${_winid}) ]] && { xterm -title ${_sess} -name ${_sess} -e \
    $_tmux attach -t ${_sess} & sleep 0.5; } 2>/dev/null

    xdotool search --classname ${_sess} windowactivate
  fi
}

_readstyle() {

  [[ -s $_style_map ]] || return 0

  while read _pattern _style; do

    _pattern=${_pattern%%#*} # delete comments
    _style=${_style%%#*}     # delete comments

    [[ -z ${_pattern} || -z ${_style} ]] && continue

    [[ ${_host} == ${_pattern} ]] && break

  done <$_style_map
}

_setpane(){

  local _paneid=${1} _title=${2}

  _readstyle

  [[ -z ${_isip} ]] && _title=${_title%%.*}

  [[ -z ${_title} ]] && _title=$(hostname -s)

#  $_tmux select-pane -T "$(printf %-${_tabw}.${_tabw}s ${_title})" -t ${_paneid}
  $_tmux select-pane -T "${_title}" -t ${_paneid}

  if [[ -n ${_oldstyle} ]]; then

    $_tmux select-pane -P ${_oldstyle} -t ${_paneid}
    #$_tmux setw window-status-style ${_oldstyle}
    #$_tmux setw window-status-current-style ${_oldstyle}

  elif [[ -n ${_style} ]]; then

    $_tmux select-pane -P $_style -t ${_paneid}
    #$_tmux setw window-status-style $_style
    #$_tmux setw window-status-style $_style
    #$_tmux setw window-status-current-style $_style
  fi

  _pstyle=$($_tmux select-pane -g)
  _fg=${_pstyle##*fg=}
  _fg=${_fg%%,*}

  #$_tmux setw window-status-style fg=${_fg},bg=colour235,reverse

  #$_tmux setw window-status-style "bg=${_fg},fg=colour255"
  #$_tmux setw window-status-current-style "reverse,bold"
  $_tmux setw window-status-style "fg=${_fg}"
  $_tmux setw window-status-current-style "fg=${_fg},bg=colour240"

}

_ssh() {

  # remove string when invoked via cwm
  [[ $1 == "[ssh]" ]] && shift
  
  if [[ -n $1 ]]; then
      
    # force a tty e.g. when running a command at the remote side like tmux ;)
    _cmd="ssh -t $@"

    # let ssh parse the command line so we are sane
    # avoid overriding the hostname via main config
    _checkname $(/usr/bin/ssh -F /dev/null -G $@)
  fi

  [[ $($_tmux list-session -F "#S" 2>/dev/null) == *${_sess}* ]] && _s=${_sess}

  # check if called from inside our tabbed tmux to avoid a new window
  if [[ $TMUX == *${_sock}* && ${_s} == ${_sess} ]]; then
      
    # trap to be able to name the pane back after ssh session endet from within the pane
    trap "_oldstyle=$($_tmux select-pane -g) _setpane ${TMUX_PANE}" INT EXIT

    _setpane ${TMUX_PANE} ${_host}
    $_cmd

  # run in already started session or reattach
  elif [[ ${_s} == ${_sess} ]]; then

    [[ -z ${_cmd} ]] && _runxdotool && exit
    
    _paneid=$($_tmux new-window -P -t ${_sess} -F '#D' ${_cmd})

    _setpane ${_paneid} ${_host}

    _runxdotool

  # create new session
  else

    _paneid=$($_tmux -f $_ssh_config new-session -d -P -F '#D' -s ${_sess} ${_cmd}) || exit
    # add some settings into the session environment
    #$_tmux set-environment -g -t ${_sess} CMD "${SHELL} $0 -r \#D \#h \#T"
    $_tmux set-environment -g -t ${_sess} CMD "${SHELL} $0 -r \#D \#T"
    $_tmux set-hook -g -t ${_sess} after-new-window "run \$CMD"
    $_tmux set-hook -g -t ${_sess} after-split-window "run \$CMD"
    $_tmux set-hook -g -t ${_sess} pane-focus-in "run \$CMD"
    $_tmux bind r source-file $_ssh_config \\\; display-message "source-file done"

    _setpane ${_paneid} ${_host}

    xterm -maximized -title ${_sess} -name ${_sess} -e \
    $_tmux attach -t ${_sess} 2>/dev/null &
    #"xdotool key ctrl+alt+m; $_tmux attach -t ${_sess} 2>/dev/null" &
    type xdotool && sleep 0.2 && xdotool key ctrl+alt+m
  fi
}

getopts ":cr" _opt
shift $((OPTIND-1))

case "$_opt" in

  c) 
    _ssh $OPTARG $@
    ;;

  r)
    _setpane $@
    ;;

  *) usage
    ;;
esac

#vim: set ai:ts=2:et:sw=2
