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

;; Bootstrap `use-package`
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)

;; Load configuration file
(org-babel-load-file "~/.emacs.d/configuration.org")

;;; init.el ends here
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(find-file-in-project ws-butler web-mode use-package tide solidity-mode smartparens rust-mode rjsx-mode python-mode ox-gfm ob-rust multiple-cursors modus-vivendi-theme minions markdown-preview-mode magit lsp-treemacs htmlize google-c-style git-gutter fringe-helper dockerfile-mode docker-compose-mode company cmake-mode cargo)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(line-number-current-line ((t (:foreground "Royalblue" :background "DarkGray")))))
