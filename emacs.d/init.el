;; default theme
(load-theme 'wombat t)

;; display settings
;; turn off toolbar for gui
(if window-system
    (tool-bar-mode 0))
;; turn off menubar for terminal
(menu-bar-mode -1)

;; maximize screen on startup
(set-frame-parameter nil 'fullscreen 'maximized)

;; do not create backup/autosave file
(setq make-backup-files nil)
(setq auto-save-default nil)

;; do not show startup page
(setq inhibit-startup-screen t)

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
                          :foreground "DarkOliveGreen")
      (set-face-attribute 'line-number-current-line nil
                          :foreground "gold")))

;; Blink instead of beeping
(setq visible-bell t)

;; keymaps
;; F8 eshell
(global-set-key (kbd "<f8>") 'eshell)
;; F9 shell
(global-set-key (kbd "<f9>") 'shell)
;; y - n for yes - no
(defalias 'yes-or-no-p 'y-or-n-p)
;; backslash with M-¥
(define-key global-map [?\M-¥] "\\")
;; C-k to remove all of the line
(setq kill-whole-line t)

;; packages
;; package and initialization
(require 'package)
(add-to-list 'package-archives '("melpa" . "http://melpa.milkbox.net/packages/"))
(add-to-list 'package-archives '("marmalade" . "http://marmalade-repo.org/packages/"))
(package-initialize)

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

;; python mode
(require 'python-mode)
(setq auto-mode-alist (cons '("\\.py\\'" . python-mode) auto-mode-alist))

;; rust mode
(require 'rust-mode)
(setq rust-format-on-save t)
(add-to-list 'exec-path (expand-file-name "~/.cargo/bin"))
(require 'company-racer)
(with-eval-after-load 'company
  (add-to-list 'company-backends 'company-racer))
(add-hook 'rust-mode-hook #'racer-mode)
(add-hook 'rust-mode-hook #'flycheck-rust-setup)
(add-hook 'racer-mode-hook #'eldoc-mode)
(add-hook 'racer-mode-hook #'company-mode)
(add-hook 'after-init-hook #'global-flycheck-mode)
;; cargo package
;; check the documentation at https://github.com/kwrooijen/cargo.el
(add-hook 'rust-mode-hook 'cargo-minor-mode)


;; custom set variables
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   (quote
    (cargo company-racer flycheck-rust racer rust-mode jedi python-mode smartparens restart-emacs exec-path-from-shell company))))
