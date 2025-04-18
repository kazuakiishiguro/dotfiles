#!/bin/sh

prefix="/usr"
exec_prefix="${prefix}"
xrdb="xrdb"
xinitdir="/etc/X11/xinit"
xclock="xclock"
xterm="xterm"
twm="twm"
xmodmap="xmodmap"

userresources="$HOME/.Xresources"
usermodmap="$HOME/.Xmodmap"
sysresources="$xinitdir/.Xresources"
sysmodmap="$xinitdir/.Xmodmap"
userprofile="$HOME/.xprofile"

# merge in defaults and keymaps

# [ -f "$userprofile" ] && . "$userprofile"

if [ -f "$sysresources" ]; then
    if [ -x /usr/bin/cpp ] ; then
        "$xrdb" -merge "$sysresources"
    else
        "$xrdb" -nocpp -merge "$sysresources"
    fi
fi

if [ -f "$sysmodmap" ]; then
    "$xmodmap" "$sysmodmap"
fi

if [ -f "$userresources" ]; then
    if [ -x /usr/bin/cpp ] ; then
        "$xrdb" -merge "$userresources"
    else
        "$xrdb" -nocpp -merge "$userresources"
    fi
fi

if [ -f "$usermodmap" ]; then
    "$xmodmap" "$usermodmap"
fi

# start some nice programs

if [ -d "$xinitdir"/xinitrc.d ] ; then
    for f in "$xinitdir/xinitrc.d"/?*.sh ; do
	[ -x "$f" ] && . "$f"
    done
    unset f
fi

# trackpoing sensivity
xinput set-prop "TPPS/2 IBM TrackPoint" "Device Accel Constant Deceleration" 1

case $2 in
    "" | "i3" ) exec i3 ;;
    "exec" ) exec $3 ;;
    * ) ;;
esac
