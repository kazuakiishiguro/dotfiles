(require 'use-package-ensure)
(setq use-package-always-ensure t)

(defun k/kill-current-buffer ()
  "Kill the current buffer without prompting."
  (interactive)
  (kill-buffer (current-buffer)))

(defun k/insert-line-before ()
      "Insert a newline(s) above the line containing the cursor."
  (interactive)
  (save-excursion
    (move-beginning-of-line 1)
    (newline)))

(tooltip-mode    -1)
(menu-bar-mode   -1)
(add-to-list 'default-frame-alist '(font . "monoki-12"))

(use-package dracula-theme
  :ensure t
  :config
  (load-theme 'dracula t))

(global-set-key (kbd "C-x w h") 'split-window-horizontally)
(global-set-key (kbd "C-x w v") 'split-window-vertically)

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

(use-package which-key
  :ensure t
  :init
  (setq which-key-separator " ")
  (setq which-key-prefix-prefix "+")
  :config
  (which-key-mode 1))

(setq rign-bell-function 'ignore)

(global-hl-line-mode)
(set-face-background hl-line-face "gray13")

(setq show-paren-delay 0)
(show-paren-mode 1)

(use-package diff-hl
  :config
  (add-hook 'prog-mode-hook 'turn-on-diff-hl-mode)
  (add-hook 'vc-dir-mode-hook 'turn-on-diff-hl-mode))

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

(use-package flycheck
  :ensure t
  :init (global-flycheck-mode))

(use-package magit
  :bind
  ("C-x g" . magit-status)
  :config
  (setq magit-push-always-verify nil))

(use-package rust-mode
  :ensure t
  :config
  (use-package flycheck-rust
    :ensure t
    :config
    (with-eval-after-load 'rust-mode
      (add-hook 'flycheck-mode-hook #'flycheck-rust-setup))
    (add-hook 'rust-mode-hook #'flycheck-rust-setup))
  :mode ("\\.rs\\'" . rust-mode))

(use-package racer
  :ensure t
  :after rust-mode
  :diminish racer-mode
  :init
  (add-hook 'rust-mode-hook #'racer-mode)
  (add-hook 'racer-mode-hook #'eldoc-mode)
  (add-hook 'racer-mode-hook #'company-mode))

(use-package lsp-rust
  :ensure t
  :disabled t
  :after lsp-mode
  :init
  (add-hook 'rust-mode-hook #'lsp-rust-enable))

(use-package cargo
  :init
  (add-hook 'rust-mode-hook 'cargo-minor-mode))

(use-package toml-mode
  :ensure t
  :mode ("\\.toml\\'" . toml-mode))

(add-hook 'sh-mode-hook
  (lambda ()
    (setq sh-basic-offset 2
      sh-indentation 2)))

(setq initial-major-mode 'org-mode)

(use-package org-bullets
  :init
  (add-hook 'org-mode-hook 'org-bullets-mode))

(setq org-src-fontify-natively t)

(setq org-src-tab-acts-natively t)

(setq org-src-window-setup 'current-window)

(add-to-list 'org-structure-template-alist
             '("el" . "src emacs-lisp"))

(setq org-directory "~/org")

(defun org-file-path (filename)
  "Return the absolute address of an org file, given its relative name"
  (concat (file-name-as-directory org-directory) filename))

(setq org-index-file (org-file-path "index.org"))
(setq org-archive-location
      (concat (org-file-path "archive.org") "::* From %s"))

(setq org-agenda-files (list org-index-file))

(defun k/mark-done-and-archive ()
  "Mark the state of an org-mode item as DONE and archive it."
  (interactive)
  (org-todo 'done)
  (org-archive-subtree))

(define-key org-mode-map (kbd "C-c C-x C-s") 'k/mark-done-and-archive)

(setq org-log-done 'time)

(setq org-capture-templates
    '(("b" "Blog idea"
       entry
       (file "~/org/notes/blog-ideas.org")
       "* %?\n")
      ("n" "Note taking"
       entry
       (file "~/org/notes/note.org")
       "* %?\n %U %f")
      ("t" "Todo"
       entry
       (file+headline org-index-file "Inbox")
       "* TODO %?\n")))

(define-key global-map "\C-ca" 'org-agenda)
(define-key global-map "\C-cc" 'org-capture)

(defun org-open-index ()
  "Open the master TODO list."
    (interactive)
    (find-file org-index-file)
    (flycheck-mode -1)
    (end-of-buffer))

(global-set-key (kbd "C-c i") 'org-open-index)

(defun org-capture-todo ()
  (interactive)
  (org-capture :keys "t"))

(global-set-key (kbd "M-n") 'org-capture-todo)

(use-package ob-rust)

(org-babel-do-load-languages
  'org-babel-load-languages
  '((emacs-lisp . t)
    (shell . t)
    (js . t)
    (latex . t)
    (rust . t)
    (python . t)))

(setq org-confirm-babel-evaluate nil)

(defun k/visit-emacs-config ()
  (interactive)
  (find-file "~/.emacs.d/configuration.org"))

(global-set-key (kbd "C-c f .") 'k/visit-emacs-config)

(defun k/reload-emacs-config ()
  (interactive)
  (load-file "~/.emacs.d/init.el"))

(global-set-key (kbd "C-c f r") 'k/reload-emacs-config)

(global-set-key (kbd "C-x k") 'k/kill-current-buffer)

(global-set-key (kbd "C-o") 'k/insert-line-before)

(setq make-backup-files nil)
(setq auto-save-default nil)

(global-set-key (kbd "C-x t") 'term)

(electric-pair-mode 1)

(setq vc-follow-symlinks t)
(setq auto-revert-check-vc-info t)
