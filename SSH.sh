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

_sock="SSH"
_sess="SSH"
_tabw="15"  # width of the tabs created

# run tmux with some defaults like utf-8 support and at an separate socket
_tmux="tmux -2 -u -L ${_sock}"

# set the variable "%#{pane_id}" in tmux environment to the hostname
_setenv="${_tmux} setenv -t ${_sess}"

usage(){

echo \
  "
usage: /bin/sh $0 -cgsu [args]
  -c : start server and connect xterm or attach term to detached session
  -c args: start server and run ssh with args or start ssh and attach xterm
  -r refresh all \"tabs\" with vals from active panes
  -s %num value: set value to var %num
  -u %num: unset var %num

 where %num is the pane ID.

 For usage from within shell create an alias like this:
  alias ssh=\"sh ~/.tmux/SSH.sh -c\"

 For usage from within cwm put this in Your ~/.cwmrc:
  command term \'ksh -c \". ~/.tmux/SSH.sh -c \$1\"\'
  bind CM-Return xterm
  #...and if autogroup preferred
  autogroup 1 \"${_sess},XTerm\"

  If xdotool is installed it focusses automatically to the xterm running this
  tmux session or reattaches a xterm if the session is detached.
"
exit 1
}

_checkname(){

  # parse the output from ssh -G
  for _l; do

    case $_l in hostname)

      # make stupid check if hostname is an IP 
      _ip=${2##+([0-9]).+([0-9]).+([0-9]).+([0-9])}
      _ip=${_ip##+([0-9a-f]):+([0-9a-f]):+([0-9a-f]):*([0-9a-f:]):+([0-9a-f])}

      if [[ -z ${_ip} ]]; then

        _host=$(dig +short -x $2)
        [[ -n "${_host}" ]] && _host=${_host%%.*} || _host=$2
      else

        _host=${2%%.*}
      fi
      break
      ;;
    esac

    shift
  done
}

_runxdotool(){

  # with xdotool installed, activate the window or reattach to a detached
  # session
  if type xdotool >/dev/null; then

    _winid="xdotool search --classname ${_sess}"

    [[ -z $(${_winid}) ]] && { xterm -title ${_sess} -name ${_sess} -e \
    $_tmux attach -t ${_sess} & sleep 0.5; } 2>/dev/null

    xdotool search --classname ${_sess} windowactivate
  fi
}

_setwin(){
  # get all environment variables and store them 
  for _var in $($_tmux show-env -t ${_sess}); do
  
    case $_var in
  
      %+([0-9a-f])*)
  
        _index=${_var%%=*}
        # make a list of existing variables
        INDEX="${INDEX} ${_index}"
        _index=${_index##%}
        _value=${_var##*=}
        # make an array with values
        VALS[$_index]=${_value}
      ;;
    esac
  done
  
  $_tmux list-windows -F "#{window_id} #{pane_id} #{@HOST}" -t ${_sess} | {

    _localhost=$(hostname -s)
  
    while read _winid _paneid _val; do
  
      _host=${VALS[${_paneid##%}]}
  
      [[ -z ${_host} ]] && _host=${_localhost}
  
      [[ ${_val} == ${_host} ]] || \
      $_tmux setw -q -t ${_winid} "@HOST" "$(printf %-${_tabw}.${_tabw}s ${_host})"
    done
  }
  
  for _pane in $($_tmux list-panes -s -t ${_sess} -F '#D'); do
  
    # make a list of all panes in session
    CURPANES="${CURPANES} X${_pane}X"
  done
  
  # compare environment with current panes and delete unused variables
  for _pane in ${INDEX}; do
  
    [[ ${CURPANES} == *X${_pane}X* ]] || \
    $_setenv -ur ${_pane}
  done
  
  # workaround as long as tmux crashes by setting "renumber-windows on" and hook
  # "after-join-pane" or "after-move-pane" at the same time
  $_tmux move-window -r -t ${_sess}
  $_tmux refresh-client -S 2>/dev/null
}

_ssh() {

  # remove string when invoked via cwm
  [[ $1 == "[ssh]" ]] && shift
  
  if [[ -n $1 ]]; then
      
    # force a tty e.g. when running a command at the remote side like tmux ;)
    _cmd="ssh -t $@"

    # let ssh parse the command line so we are sane
    # avoid override the hostname via main config
    _checkname $(unalias ssh; ssh -F /dev/null -G $@)
  fi

  [[ $($_tmux list-session -F "#S" 2>/dev/null) == *${_sess}* ]] && _s=${_sess}

  # check if called from inside our tabbed tmux to avoid a new window
  if [[ $TMUX == *${_sock}* && ${_s} == ${_sess} ]]; then
      
    trap "$_setenv -ur $TMUX_PANE; sh $0 -r" INT EXIT

    [[ -n ${_host} ]] && $_setenv $TMUX_PANE ${_host}
    _setwin
    $_cmd
    exit

  elif [[ ${_s} == ${_sess} ]]; then

    [[ -z ${_cmd} ]] && _runxdotool && exit
    
    _paneid=$($_tmux new-window -P -t ${_sess} -F '#D' ${_cmd})

    [[ -n ${_host} ]] && $_setenv ${_paneid} ${_host}
    _setwin
    _runxdotool
  else

    _paneid=$($_tmux -f ~/.tmux/SSH.conf new-session -P -d -F '#D' -s ${_sess} ${_cmd})

    [[ -n ${_paneid} ]] || exit 1

    [[ -n ${_host} ]] && $_setenv ${_paneid} ${_host}
    _setwin

    xterm -title ${_sess} -name ${_sess} -e \
    $_tmux attach -t ${_sess} 2>/dev/null &
  fi
}

getopts ":s:u:cr" _opt
shift $((OPTIND-1))

case "$_opt" in

  c) 
    _ssh $OPTARG $@
    ;;

  r)
    _setwin
    exit 0
    ;;

  s)
    [[ $OPTARG != %+([0-9]) ]] && usage
    $_setenv $OPTARG $@
    ;;

  u)
    [[ $OPTARG != %+([0-9]) ]] && usage
    $_setenv -ur $OPTARG
    ;;

  *) usage
    ;;
esac

#vim: set ai:ts=2:et:sw=2
