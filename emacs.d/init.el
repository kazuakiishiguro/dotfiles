;; default theme
(load-theme 'manoj-dark t)

;; display settings
;; turn off toolbar for gui
(if window-system
    (tool-bar-mode 0))

;; maximize screen on startup
(set-frame-parameter nil 'fullscreen 'maximized)

;; Ricty font
(create-fontset-from-ascii-font "Ricty-14:weight=normal:slant=normal" nil "ricty")
(set-fontset-font "fontset-ricty"
                  'unicode
                  (font-spec :family "Ricty" :size 14)
                  nil
                  'append)
(add-to-list 'default-frame-alist '(font . "fontset-ricty"))

;; do not create backup/autosave file
(setq make-backup-files nil)
(setq auto-save-default nil)

;; mode-line display
(display-time)
(line-number-mode 1)
(column-number-mode 1)

;; mode-line function name display
(which-function-mode 1)

;; 4 spaces for tab
(setq-default tab-width 4 indent-tabs-mode nil)

;; display line numbers
(if (version<= "26.0.50" emacs-version)
    (progn
      (global-display-line-numbers-mode)
      ;; line numbers color settings
      (set-face-attribute 'line-number nil
                          :foreground "DarkOliveGreen"
                          :background "black")
      (set-face-attribute 'line-number-current-line nil
                          :foreground "gold")))

;; keymaps
;; F8  eshell
(global-set-key (kbd "<f8>") 'eshell)
;; y - n for yes - no
(defalias 'yes-or-no-p 'y-or-n-p)                  