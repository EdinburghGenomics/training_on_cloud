# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# Edited by Tim B to tweak the prompt and set umask and auto-cleanup.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Our exercises assume this
umask 0002

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# auto-reset the shell history if the machine is re-imaged, so people on the course
# don't see our own commend history
function reset_shell(){
    rm -f ~/.bash_history
    history -c
    rm -f ~/.viminfo ~/.Rhistory ~/.wget-hsts
}

# if we detect that the machine ID has changed, clear the history.
if [ ! -e ~/.instance-id ] || [ `stat -c %Y ~/.instance-id` -lt `awk '/btime/{print $2}' /proc/stat`  ] ; then
    # ie. there is no .instance-id or it was written prior to the last boot,
    # so we should only do one wget per boot.
    current_instance_id=`wget -q -O- http://169.254.169.254/latest/meta-data/instance-id`

    if [ -e ~/.instance-id ] ; then
        previous_instance_id=`cat ~/.instance-id`
        if [ "$previous_instance_id" != "$current_instance_id" ] ; then
            reset_shell
        fi
    fi

    # always write the file
    echo "$current_instance_id" > ~/.instance-id
fi

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

# Get the pretty hostname as hopefully set by tag_myself.py
pretty_host="`hostnamectl --pretty`"
pretty_host="${pretty_host:-$HOSTNAME}"

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@$pretty_host\[\033[00m\]:\[\033[01;34m\]\W\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@$pretty_host:\W\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@pretty_host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@$pretty_host: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# The training user has no password but some sudo access, so this is appropriate:
alias sudo='sudo -n'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# for some reason ~/bin gets prepended to the PATH on SSH login but not in a
# xfce terminal window?? Just make it so!
if [ -d "$HOME/bin" ] && ! grep -wq "$HOME/bin" <<<"$PATH" ; then
    PATH="$HOME/bin:$PATH"
fi

# And ensure any software in /mnt/s3fs/autosquash is immediately available
if [ -d "$HOME/bin" ] && [ -e /mnt/s3fs/autosquash/links.list ] ; then
    while read l t ; do
        ln -snf "$t" "$HOME/bin/$l"
    done < /mnt/s3fs/autosquash/links.list
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
