#!/bin/sh

xinitdir="/etc/X11/xinit"
xterm="xterm"
xmodmap="xmodmap"

userresources="$HOME/.Xresources"
usermodmap="$HOME/.Xmodmap"
sysresources="$xinitdir/.Xresources"
sysmodmap="$xinitdir/.Xmodmap"
userprofile="$HOME/.xprofile"

# merge in defaults and keymaps

if [ -f "$sysmodmap" ]; then
    "$xmodmap" "$sysmodmap"
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
# xinput set-prop "TPPS/2 IBM TrackPoint" "Device Accel Constant Deceleration" 1

# for wallpaper
# ~/.fehbg &

# for JA lang
fcitx5 &

# for statusbar
slstatus &

# for display size (only for framework 2.8k)
xrandr --dpi 221 &

case $2 in
    "" | "dwm" ) exec dwm ;;
    "exec" ) exec $3 ;;
    * ) ;;
esac
