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

;; indent when entering
(electric-indent-mode t)

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

;; packages
;; package and initialization
(package-initialize)
(require 'package)
(add-to-list 'package-archives '("melpa" . "http://melpa.milkbox.net/packages/") t)
(add-to-list 'package-archives '("marmalade" . "http://marmalade-repo.org/packages/"))

;; auto bracket complete
(require 'smartparens)
(smartparens-global-mode t)
(setq-default sp-highlight-pair-overlay nil)

;; company
(require 'company)
(global-company-mode)
(global-set-key (kbd "C-M-i") 'company-complete)
;; C-n, C-p for select
(define-key company-active-map (kbd "C-n") 'company-select-next)
(define-key company-active-map (kbd "C-p") 'company-select-previous)
(define-key company-search-map (kbd "C-n") 'company-select-next)
(define-key company-search-map (kbd "C-p") 'company-select-previous)
;; C-s for filterling
(define-key company-active-map (kbd "C-s") 'company-filter-candidates)
;; TAB
(define-key company-active-map (kbd "C-i") 'company-complete-selection)
;; use company-mode with C-M-i
(define-key emacs-lisp-mode-map (kbd "C-M-i") 'company-complete)
;; display settings
(set-face-attribute 'company-tooltip nil
                    :foreground "black" :background "lightgrey")
(set-face-attribute 'company-tooltip-common nil
                    :foreground "black" :background "lightgrey")
(set-face-attribute 'company-tooltip-common-selection nil
                    :foreground "white" :background "steelblue")
(set-face-attribute 'company-tooltip-selection nil
                    :foreground "black" :background "steelblue")
(set-face-attribute 'company-preview-common nil
                    :background nil :foreground "lightgrey" :underline t)
(set-face-attribute 'company-scrollbar-fg nil
                    :background "orange")
(set-face-attribute 'company-scrollbar-bg nil
                    :background "gray40")

;; shell setting
(exec-path-from-shell-initialize)
