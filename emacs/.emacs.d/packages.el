;;; packages.el --- Shared package installation -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'package)
(require 'package-vc)
(require 'url-vars)
(require 'subr-x)

(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")
                         ("melpa" . "https://melpa.org/packages/")))

(defconst my/dotfiles-elpa-packages
  (append '(magit dockerfile-mode ws-butler diminish
    modus-themes minions git-gutter company flycheck lsp-mode lsp-ui
    lsp-treemacs yasnippet smartparens multiple-cursors counsel
    rustic cargo ob-rust google-c-style cmake-mode elpy
    markdown-mode markdown-preview-mode deft htmlize ox-gfm
    org-bullets org-cliplink eat dap-mode)
          (when (eq system-type 'darwin) '(exec-path-from-shell)))
  "Packages used by the shared Org configuration.")

(defconst my/dotfiles-vc-packages
  '((docker-compose-mode
     :url "https://github.com/meqif/docker-compose-mode" :lisp-dir ".")
    (claude-code-ide
     :url "https://github.com/manzaltu/claude-code-ide.el")
    (codex-ide
     :url "https://github.com/dgillis/emacs-codex-ide" :lisp-dir "."))
  "Packages installed from their upstream source repositories.")

;; Override archive recipes before package activation or VC installation.
;; NonGNU also has an unrelated codex-ide with Lisp sources under lisp/.
(setq package-vc-selected-packages my/dotfiles-vc-packages)

(defun my/dotfiles-missing-packages ()
  "Return shared packages that are not installed yet."
  (cl-remove-if #'package-installed-p
                (append my/dotfiles-elpa-packages
                        (mapcar #'car my/dotfiles-vc-packages))))

(defun my/dotfiles--git-output (directory &rest args)
  "Run Git ARGS in DIRECTORY, returning its output without changing files."
  (unless (executable-find "git")
    (error "Git is required to install source packages"))
  (let ((default-directory (file-name-as-directory directory)))
    (with-temp-buffer
      (let ((status (apply #'process-file "git" nil t nil args)))
        (unless (eq status 0)
          (error "Cannot inspect existing checkout %s: %s"
                 directory (string-trim (buffer-string))))
        (buffer-string)))))

(defun my/dotfiles--check-vc-checkout (spec directory &optional require-clean)
  "Verify DIRECTORY belongs to SPEC before reusing its checkout.
When REQUIRE-CLEAN is non-nil, refuse source edits and unknown untracked
files.  Generated package descriptors, autoloads and bytecode are allowed."
  (let* ((name (symbol-name (car spec)))
         (expected (string-remove-suffix
                    ".git" (string-remove-suffix
                            "/" (plist-get (cdr spec) :url))))
         (generated (list (concat name "-autoloads.el")
                          (concat name "-pkg.el"))))
    (unless (and (file-directory-p directory) (not (file-symlink-p directory)))
      (error "Package checkout is not a plain directory: %s; inspect it before retrying"
             directory))
    (unless (file-equal-p
             directory
             (string-trim (my/dotfiles--git-output directory "rev-parse" "--show-toplevel")))
      (error "Package directory is not its own Git checkout: %s" directory))
    (let ((origin (string-remove-suffix
                   ".git" (string-remove-suffix
                           "/" (string-trim
                                 (my/dotfiles--git-output
                                  directory "remote" "get-url" "origin"))))))
      (unless (equal origin expected)
        (error "Source mismatch for %s: expected %s, found %s. Existing checkout is preserved"
               name expected origin)))
    (when require-clean
      (let* ((changed (split-string
                       (my/dotfiles--git-output
                        directory "diff" "--name-only" "-z" "HEAD" "--") "\0" t))
             (untracked (split-string
                         (my/dotfiles--git-output
                          directory "ls-files" "--others" "--exclude-standard" "-z") "\0" t))
             (source-changes
              (cl-remove-if
               (lambda (file)
                 (or (member file generated)
                     (string-match-p "\\.el[cn]\\'" file)))
               (append changed untracked))))
        (when source-changes
          (error "Checkout %s contains local source changes: %S. Commit or move them aside before retrying; nothing was deleted"
                 directory source-changes))))))

(defun my/dotfiles--installed-vc-package (name)
  "Return NAME's installed VC descriptor, if present."
  (cl-find-if #'package-vc-p (cdr (assq name package-alist))))

(defun my/dotfiles--backup-archive-packages (name)
  "Move NAME's superseded archive packages to recoverable local backups.
Run only after its VC checkout has been installed and verified.  Archive
date versions can sort ahead of VC semantic versions on later startups."
  (let* ((entry (assq name package-alist))
         (archives (cl-remove-if #'package-vc-p (cdr entry)))
         (root (expand-file-name "package-archive-backups" user-emacs-directory)))
    ;; Refuse system packages and links before moving any archive directory.
    (dolist (descriptor archives)
      (let ((directory (package-desc-dir descriptor)))
        (unless (and (stringp directory) (file-directory-p directory)
                     (not (file-symlink-p directory))
                     (file-equal-p (file-name-directory (directory-file-name directory))
                                   package-user-dir))
          (error "Archive package %s is outside the managed package directory; preserved at %s"
                 name directory))))
    (when archives
      (when (file-symlink-p root)
        (error "Archive backup directory must not be a symlink: %s" root))
      (make-directory root t)
      (dolist (descriptor archives)
        (let* ((directory (directory-file-name (package-desc-dir descriptor)))
               (basename (file-name-nondirectory directory))
               (backup (make-temp-file (expand-file-name (concat basename "-") root) t))
               (destination (expand-file-name basename backup)))
          (rename-file directory destination)
          (setcdr entry (delq descriptor (cdr entry)))
          (message "%s: retained previous archive package at %s" name destination))))))

(defun my/dotfiles-install-vc-package (spec)
  "Install SPEC, or safely resume its previously downloaded checkout.
Return `installed', `rebuilt' or `already-installed'.  Never delete an
existing checkout and never answer an interactive overwrite prompt."
  (let* ((name (car spec))
         (installed (my/dotfiles--installed-vc-package name))
         (directory (expand-file-name (symbol-name name) package-user-dir))
         ;; A descriptor appears before compilation finishes.  Its presence
         ;; alone must not make an interrupted build look complete next time.
         (pending (expand-file-name (format ".dotfiles-%s-installing" name)
                                    package-user-dir)))
    (cl-letf (((symbol-function 'yes-or-no-p)
               (lambda (&rest _args)
                 (error "Source package installation unexpectedly requested confirmation; existing files are preserved")))
              ((symbol-function 'y-or-n-p)
               (lambda (&rest _args)
                 (error "Source package installation unexpectedly requested confirmation; existing files are preserved"))))
      (cond
       ((and installed (not (file-exists-p pending)))
        ;; Only a VC descriptor represents an installed source checkout.
        ;; Archive packages live in versioned directories and are backed up
        ;; only after the authoritative source checkout is ready.
        (my/dotfiles--check-vc-checkout spec (package-desc-dir installed))
        (my/dotfiles--backup-archive-packages name)
        'already-installed)
       ((or (file-exists-p directory) (file-symlink-p directory))
        (my/dotfiles--check-vc-checkout spec directory t)
        (message "%s: rebuilding the existing checkout without fetching..." name)
        (with-temp-file pending (insert "Rebuild in progress; rerun ./init.sh to resume.\n"))
        (package-vc-rebuild
         (package-desc-create :name name :kind 'vc :dir directory))
        (unless (my/dotfiles--installed-vc-package name)
          (error "Rebuild of %s did not finish registering the package" name))
        (my/dotfiles--check-vc-checkout spec directory)
        (my/dotfiles--backup-archive-packages name)
        (delete-file pending)
        'rebuilt)
       (t
        (make-directory package-user-dir t)
        (with-temp-file pending (insert "Install in progress; rerun ./init.sh to resume.\n"))
        (package-vc-install spec)
        (unless (my/dotfiles--installed-vc-package name)
          (error "Installation of %s did not finish registering the package" name))
        (my/dotfiles--check-vc-checkout spec directory)
        (my/dotfiles--backup-archive-packages name)
        (delete-file pending)
        'installed)))))

(defun my/install-dotfiles-emacs-packages ()
  "Install all shared packages, then reload Emacs to activate them.
Run this explicitly with working network access; startup never downloads."
  (interactive)
  ;; Package installation saves selections. Never let -Q create ~/.emacs or
  ;; overwrite the shared custom.el through its symlink.
  (setq custom-file (expand-file-name "custom-local.el" user-emacs-directory))
  (package-initialize)
  (setq package-vc-selected-packages my/dotfiles-vc-packages)
  (let ((url-request-timeout 30)
        (process-environment (cons "GIT_TERMINAL_PROMPT=0" process-environment))
        (step 0)
        (total (+ (length my/dotfiles-elpa-packages)
                  (length my/dotfiles-vc-packages))))
    (when (cl-some (lambda (name) (not (package-installed-p name)))
                   my/dotfiles-elpa-packages)
      (message "Refreshing package archives (30-second request timeout)...")
      (package-refresh-contents)
      (unless package-archive-contents
        (error "Package archives could not be downloaded; check network access")))
    ;; Detect removed packages before starting a partially successful install.
    (let ((unavailable
           (cl-remove-if (lambda (name)
                           (or (package-installed-p name)
                               (assq name package-archive-contents)))
                         my/dotfiles-elpa-packages)))
      (when unavailable
        (error "Packages absent from configured archives: %S. Update their source in packages.el"
               unavailable)))
    (package-compute-transaction
     nil (mapcar #'list
                 (cl-remove-if #'package-installed-p my/dotfiles-elpa-packages)))
    (dolist (name my/dotfiles-elpa-packages)
      (cl-incf step)
      (if (package-installed-p name)
          (message "[%d/%d] %s: already installed" step total name)
        (message "[%d/%d] %s: installing from package archive..." step total name)
        (condition-case err
            (package-install name)
          (error
           (error "Installation stopped at %s: %s. Installed packages are retained; rerun ./init.sh from the dotfiles repository to resume"
                  name (error-message-string err))))))
    ;; Codex's transient menus need this macro while generating autoloads.
    (require 'transient)
    (require 'package-vc)
    (dolist (spec my/dotfiles-vc-packages)
      (cl-incf step)
      (message "[%d/%d] %s: checking source %s..."
               step total (car spec) (plist-get (cdr spec) :url))
      (condition-case err
          (message "%s: %s" (car spec) (my/dotfiles-install-vc-package spec))
        (error
         (error "Installation stopped at %s: %s. Installed packages are retained; rerun ./init.sh from the dotfiles repository to resume"
                (car spec) (error-message-string err))))))
  (setq package-selected-packages my/dotfiles-elpa-packages
        package-vc-selected-packages my/dotfiles-vc-packages)
  (let ((missing (my/dotfiles-missing-packages)))
    (when missing
      (error "Packages still missing: %S" missing)))
  (message "All dotfiles packages installed. Reload init.el to activate them."))

(provide 'my-dotfiles-packages)
;;; packages.el ends here
