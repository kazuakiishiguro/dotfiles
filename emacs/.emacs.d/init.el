;;; init.el --- Emacs main config

;;; Commentary:

;;; Code:

;; Package configs
(require 'package)
(setq package-enable-at-startup nil)
(setq package-archives '(("org"   . "http://orgmode.org/elpa/")
			 ("gnu"   . "http://elpa.gnu.org/packages/")
			 ("melpa" . "https://melpa.org/packages/")
			 ( "jcs-elpa" . "https://jcs-emacs.github.io/jcs-elpa/packages/")))

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
 '(custom-safe-themes
   '("8d11daa5f67b21b377f159f12b47074e3dc706d03aa42dce90203f4516041448" "75e027e3ab2892c5c1f152e3d9fae03718f75bee50d259040e56e7e7672a4872" "e27c391095dcee30face81de5c8354afb2fbe69143e1129109a16d17871fc055" default))
 '(package-selected-packages
   '(chatgpt ws-butler web-mode tide solidity-mode smartparens rustic rjsx-mode quelpa-use-package python-mode py-autopep8 ox-gfm ob-rust multiple-cursors modus-themes minions markdown-preview-mode magit lsp-ui lsp-treemacs htmlize google-c-style git-gutter fringe-helper find-file-in-project exec-path-from-shell elpy eglot dockerfile-mode docker-compose-mode counsel copilot cmake-mode cargo)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(line-number-current-line ((t (:foreground "Royalblue" :background "DarkGray")))))
