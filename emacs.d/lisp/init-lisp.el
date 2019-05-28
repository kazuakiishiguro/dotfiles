;;; init-lisp.el --- Emacs lisp settings, and common config for other lisps -*- lexical-binding: t -*-
;;; Code: 

;; utf-8
(prefer-coding-system 'utf-8)
(set-language-environment "UTF-8")
(setq locale-coding-system 'utf-8)
(set-selection-coding-system 'utf-8)
(setq-default buffer-file-coding-system 'utf-8-unix)

;; delete menu-bar
(menu-bar-mode -1)
;; disable *.~
(setq make-backup-files nil)
;; disable .#*
(setq auto-save-default nil)
;; delete auto save files
(setq delete-auto-save-files t)
;; show full path in the titlebar
(setq frame-title-fomat "%f")
;; tab
(setq-default tab-width 4)

(provide 'init-lisp)

;;; init-lisp.el ends here