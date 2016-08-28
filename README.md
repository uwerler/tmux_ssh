SSH.sh is a small wrapper script around ssh to open a ssh connection in tmux.

The main purpose of this script is to configure the tmux windows titles with
the hostnames provided by the ssh command line itself. I have often to connect
to cloud hosts with crude hostnames I can't remember and therefore I prefer to
use cnames or hostnames set via .ssh/config - and exactly these names should
be used for window names in tmux and not set via escape sequences (pane
titles) from within the target hosts to their crude names.

Simply place SSH.sh and SSH.conf in ~/.tmux directory. It should not interfere
with existing configs because it starts an own server at an own socket with an
own session. For simple testing simply run "sh ~/.tmux/SSH.sh -c targethost".
Without arguments it starts a session without ssh and attaches a xterm to it.

It can be configured via a shell alias like this:

   alias ssh="sh ~/.tmux/SSH.sh -c"

I wrote and tested this under OpenBSD's ksh. I guess bash should work too but
not tested yet.

As a lucky OpenBSD user I also use cwm as my preferred window manager.  This
script can be used with cwm's wonderful "ssh to" dialog too by placing the
following to You .cwmrc:

  command term 'ksh -c ". ~/.tmux/SSH.sh -c $1"'
  bind CM-Return xterm
  #...and if autogroup preferred
  autogroup 1 "SSH,XTerm"

If You have xdotool installed it also focusses the xterm which is attached to
the session or spawns a new term and reattaches to an existing session.

Special thanks go to the OpenBSD developers for providing such a high quality
and stable operating system and to Nicholas Marriot for tmux - a tool I can't
work without it and his patience to answer my questions.

Enjoy.
