;; Minimal UI
(tooltip-mode    -1)
(menu-bar-mode   -1)
(add-to-list 'default-frame-alist '(font . "monoki-12"))

;; Line numbers
(if (version<= "26.0.50" emacs-version)
    (progn
      (global-display-line-numbers-mode)))

;; Startup page setting
(setq inhibit-startup-screen t)

;; Mode-line display
(display-time)
(line-number-mode 1)
(column-number-mode 1)
(which-function-mode 1)

;; Package configs
(require 'package)
(setq package-enable-at-startup nil)
(setq package-archives '(("org"   . "http://orgmode.org/elpa/")
			 ("gnu"   . "http://elpa.gnu.org/packages/")
			 ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

;; Bootstrap 'use-package'
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))
(require 'use-package)

(use-package multi-term
  :ensure t
  :config
  (setq multi-term-program "/usr/local/bin/bash"))

;; Vim mode
(use-package evil
  :ensure t
  :config
  (evil-mode 1))

(use-package evil-escape
  :ensure t
  :init
  (setq-default evil-escape-key-sequence "jk")
  :config
  (evil-escape-mode 1))

;; Theme
(use-package dracula-theme
  :ensure t
  :config
  (load-theme 'dracula t))

;; Helm
(use-package helm
  :ensure t
  :init
  (setq helm-M-x-fuzzy-match t
	helm-mode-fuzzy-match t
	helm-buffers-fuzzy-matching t
	helm-recentf-fuzzy-match t
	helm-locate-fuzzy-match t
	helm-semantic-fuzzy-match t
	helm-imenu-fuzzy-match t
	helm-completion-in-region-fuzzy-match t
	helm-candidate-number-list 80
	helm-split-window-in-side-p t
	helm-move-to-line-cycle-in-source t
	helm-echo-input-in-header-line t
	helm-autoresize-max-height 0
	helm-autoresize-min-height 20)
  :config
  (helm-mode 1)
  (define-key helm-map (kbd "<tab>") 'helm-execute-persistent-action)
  (define-key helm-map (kbd "C-z") 'helm-select-action))

;; Which Key
(use-package which-key
  :ensure t
  :init
  (setq which-key-separator " ")
  (setq which-key-prefix-prefix "+")
  :config
  (which-key-mode 1))

;; Custom keybinding
(use-package general
  :ensure t
  :config (general-define-key
    :states '(normal visual insert emacs)
    :prefix "SPC"
    :non-normal-prefix "M-SPC"
    ;; "/"   '(counsel-rg :which-key "ripgrep") ; You'll need counsel package for this
    "TAB" '(switch-to-prev-buffer :which-key "previous buffer")
    ":"   '(helm-M-x :which-key "M-x")
    "."   '(helm-find-files :which-key "find files")
    ;; Buffers
    "bb"  '(helm-buffers-list :which-key "buffers list")
    ;; Window
    "wl"  '(windmove-right :which-key "move right")
    "wh"  '(windmove-left :which-key "move left")
    "wk"  '(windmove-up :which-key "move up")
    "wj"  '(windmove-down :which-key "move bottom")
    "ws"  '(split-window-right :which-key "split right")
    "wv"  '(split-window-below :which-key "split bottom")
    "wx"  '(delete-window :which-key "delete window")
    "qz"  '(delete-frame :whichkey "delete frame")
    "qq"  '(kill-emacs :which-key "quit")
    ;; Others
    "t"  '(multi-term :which-key "open multi terminal")))

;; Fancy titlebar for MacOS
(add-to-list 'default-frame-alist '(ns-transparent-titlebar . t))
(add-to-list 'default-frame-alist '(ns-appearance . dark))
(setq ns-use-proxy-icon  nil)
(setq frame-title-format nil)

;; Flycheck
(use-package flycheck
  :ensure t
  :init (global-flycheck-mode))

;; Company mode
(use-package company
  :ensure t
  :init
  (setq company-auto-complete nil)
  (setq company-idle-delay 0.1)
  (setq company-require-match 'never)
  :config
  (global-company-mode 1)
  (define-key company-active-map (kbd "C-n") 'company-select-next)
  (define-key company-active-map (kbd "C-p") 'company-select-previous)
  (define-key company-search-map (kbd "C-n") 'company-select-next)
  (define-key company-search-map (kbd "C-p") 'company-select-previous))

;; Rust mode
(use-package rust-mode
  :ensure t
  :init
  (add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-mode)))

(use-package cargo
  :ensure t
  :init
  (add-hook 'rust-mode-hook 'cargo-minor-mode))

;; Go mode
(use-package go-mode
  :ensure t
  :init
  (add-to-list 'exec-path (expand-file-name "/usr/local/go/bin/")))

;; Magit
(use-package magit :ensure t)

;; Projectile
(use-package projectile
  :ensure t
  :init
  (setq projectile-require-project-root nil)
  :config
  (projectile-mode 1))

;; Show matching parens
(setq show-paren-delay 0)
(show-paren-mode 1)

;; Disable backup files
(setq make-backup-files nil) ; stop creating backup~ files
(setq auto-save-default nil) ; stop creating #autosave# files

;; PATH
(let ((path (shell-command-to-string ". ~/.bashrc; echo -n $PATH")))
  (setenv "PATH" path)
  (setq exec-path
    (append
      (split-string-and-unquote path ":")
      exec-path)))

;; Automatically generated
