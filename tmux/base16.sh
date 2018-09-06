base00=default  
base01=colour238
base02=colour255 
base03=colour8  
base04=colour20 
base05=colour7  
base06=colour21 
base07=colour15 
base08=colour01 
base09=colour16 
base0A=colour3  
base0B=colour2  
base0C=colour6  
base0D=colour4  
base0E=colour241
base0F=colour17 

set -g status-left-length 32
set -g status-right-length 150
set -g status-interval 1

# -- default statusbar colors -------------------------------------------------
set-option -g status-fg $base02
set-option -g status-bg $base01
set-option -g status-attr default

set-window-option -g window-status-format "#[fg=$base02] #I: #W"


# -- active window title colors -----------------------------------------------
set-window-option -g window-status-current-format "#[fg=$base02,bg=$base0C] #I: #W #[default]"

# -- pane border colors -------------------------------------------------------
set-window-option -g pane-border-fg $base03
set-window-option -g pane-active-border-fg $base0C

# -- message text -------------------------------------------------------------
set-option -g message-bg $base00
set-option -g message-fg $base0C

# -- pane number display ------------------------------------------------------
set-option -g display-panes-active-colour $base0C
set-option -g display-panes-colour $base01

# -- clock --------------------------------------------------------------------
set-window-option -g clock-mode-colour $base0C


# -- status bar ---------------------------------------------------------------
set-option -g status-left "#[fg=$base02,bg=$base0E]Session: #S #[default]"
set-option -g status-right "#[fg=$base02,bg=$base0E] #h | ♥ #(battery) | %m/%d %H:%M:%S#[default]"