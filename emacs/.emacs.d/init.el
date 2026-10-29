;;; init.el --- Emacs main config -*- lexical-binding: t; -*-
;;; Commentary:

;;; Code:

;; Keep this entry point usable in both ~/.emacs.d and ~/.config/emacs.
(load (expand-file-name "packages.el" user-emacs-directory) nil 'nomessage)
(package-initialize)
(require 'use-package)

(defvar my/omarchy-integration-p
  (file-readable-p (expand-file-name "omarchy.el" user-emacs-directory))
  "Non-nil when this machine uses Omarchy's managed theme/font integration.")

;; A batch package install/check must not start a server or desktop file watchers.
(when (and my/omarchy-integration-p (not noninteractive))
  (load (expand-file-name "omarchy.el" user-emacs-directory) nil 'nomessage))

;; Import shared preferences; save future Customize changes on this machine.
(let ((shared-custom (expand-file-name "custom.el" user-emacs-directory)))
  (when (file-exists-p shared-custom)
    (load shared-custom)))
(setq custom-file (expand-file-name "custom-local.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;; Retire stale selections from another machine; install exactly the active set.
(setq package-selected-packages my/dotfiles-elpa-packages
      package-vc-selected-packages my/dotfiles-vc-packages)

(defvar my/dotfiles-configuration-loaded nil
  "Non-nil after every shared configuration module has loaded successfully.")
(setq my/dotfiles-configuration-loaded nil)
(let ((missing (my/dotfiles-missing-packages)))
  (when missing
    (display-warning
     'dotfiles
     (format "Shared Emacs packages are not installed yet: %S\nRun ./init.sh from the dotfiles repository in a normal terminal, or M-x my/install-dotfiles-emacs-packages."
             missing)
     :warning)))

;; Let available features load even when an optional package is missing.
(require 'org)
(org-babel-load-file (expand-file-name "configuration.org" user-emacs-directory))
(setq my/dotfiles-configuration-loaded t)

;; Apply machine-specific choices after the shared configuration.
(let ((local-file (expand-file-name "local.el" user-emacs-directory)))
  (when (file-readable-p local-file)
    (load local-file nil 'nomessage)))

;;; init.el ends here
