;;; init.el --- Emacs main config

;;; Commentary:

;;; Code:

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

(org-babel-load-file "~/.emacs.d/configuration.org")

;;; init.el ends here

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(markdown-preview-mode typescript-mode rjsx-mode web-mode solidity-mode ob-rust cargo rust-mode multiple-cursors smartparens lsp-treemacs company-lsp lsp-ui lsp-mode flycheck company git-gutter fringe-helper minions dracula-theme ws-butler ox-gfm htmlize docker-compose-mode dockerfile-mode which-key magit helm use-package)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(line-number-current-line ((t (:foreground "Royalblue" :background "DarkGray")))))
