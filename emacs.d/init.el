;; init.el --- Load the full configuration -*- lexical-binding: t -*-
;;; Code: 

;; setting up and install straight.el 
(let ((bootstrap-file (concat user-emacs-directory "straight/repos/straight.el/bootstrap.el"))
      (bootstrap-version 3))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; install use-package
(straight-use-package 'use-package)

;; fallback without options
(setq straight-use-package-by-default t)

;; load init-loader
(use-package init-loader)

;; load files under ~/.emacs.d/lisp/ 
(init-loader-load "~/.emacs.d/lisp")

(use-package company
    :init
    (setq company-selection-wrap-around t)
    :bind
    (:map company-active-map
        ("M-n" . nil)
        ("M-p" . nil)
        ("C-n" . company-select-next)
        ("C-p" . company-select-previous)
        ("C-h" . nil))
    :config
    (global-company-mode))

;;; init.el ends here