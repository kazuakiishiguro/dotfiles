;;; check-config.el --- Verify activated shared features -*- lexical-binding: t; -*-

(unless (bound-and-true-p my/dotfiles-configuration-loaded)
  (error "The shared Emacs configuration has not loaded: install its packages first"))

(let ((missing (my/dotfiles-missing-packages)))
  (when missing
    (error "Shared Emacs packages are missing: %S; run scripts/setup-emacs.sh" missing)))

(dolist (command '(magit-status org-capture my/org-insert-link
                  my/org-capture-note-dwim deft lsp company-mode
                  rustic-mode elpy-enable markdown-mode
                  claude-code-ide codex-ide-menu))
  (unless (fboundp command)
    (error "Shared command is unavailable: %S" command)))

(unless (equal (key-binding (kbd "C-x g")) #'magit-status)
  (error "Magit binding C-x g was not installed"))
(unless (equal (key-binding (kbd "C-c c")) #'org-capture)
  (error "Org capture binding C-c c was not installed"))
(unless (equal (key-binding (kbd "C-x k")) #'kill-current-buffer)
  (error "C-x k must retain modified-buffer confirmation"))
(unless (and make-backup-files auto-save-default)
  (error "Backup or auto-save is disabled"))
(when (and (bound-and-true-p my/omarchy-integration-p)
           (memq 'modus-vivendi custom-enabled-themes))
  (error "The shared Modus theme overrides Omarchy"))
(princ "All shared Emacs feature groups loaded and passed configuration checks.\n")
;;; check-config.el ends here
