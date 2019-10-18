;;; init.el --- Emacs main config

;;; Commentary:

;;; Code:

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

;; Keymaps
(global-set-key (kbd "C-x w h") 'split-window-horizontally)
(global-set-key (kbd "C-x w v") 'split-window-vertically)
(global-set-key (kbd "C-x g")   'magit-status)
(global-set-key (kbd "C-x t")   'term)
(global-set-key (kbd "M-/")     'comment-or-uncomment-region)
(global-set-key (kbd "C-c f .") (lambda () "open emacs config" (interactive) (find-file "~/.emacs.d/init.el")))
(global-set-key (kbd "C-c f r") (lambda () "reload emacs config" (interactive) (load-file "~/.emacs.d/init.el")))

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
  :mode ("\\.rs\\'" . rust-mode)
  :ensure t
  :config
  (require 'racer)
  (require 'cargo)
  (require 'flycheck-rust)
  (setq racer-cmd "~/.cargo/bin/racer")
  (add-hook 'rust-mode-hook #'racer-mode)
  (add-hook 'rust-mode-hook #'eldoc-mode)
  (add-hook 'rust-mode-hook #'company-mode)
  (add-hook 'rust-mode-hook #'flycheck-rust-setup)
  (add-hook 'rust-mode-hook 'cargo-minor-mode))

;; Go mode
(use-package go-mode
  :ensure t
  :config
  (require 'go-guru)
  (require 'flymake-go)
  (require 'go-autocomplete)
  (add-to-list 'exec-path (expand-file-name "/usr/local/go/bin/")))

;; Solidity mode
(use-package solidity-mode
  :ensure t)

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

;;; init.el ends here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   (quote
    (solidity-mode flycheck-rust racer go-autocomplete flymake-go go-guru which-key use-package projectile multi-term magit helm go-mode general flycheck evil-escape evil dracula-theme company cargo))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
