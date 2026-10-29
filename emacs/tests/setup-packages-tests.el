;;; setup-packages-tests.el --- Offline package resume checks -*- lexical-binding: t; -*-

;; Fixtures only: no existing user packages or network access are used.
;; emacs --batch -Q -l emacs/tests/setup-packages-tests.el \
;;   -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'project)

(load (expand-file-name "../.emacs.d/packages.el"
                        (file-name-directory (or load-file-name buffer-file-name)))
      nil 'nomessage)

(defconst dotfiles-packages-test--spec
  '(example :url "https://example.invalid/fixture" :lisp-dir "."))

(defmacro dotfiles-packages-test--with-checkout (&rest body)
  "Run BODY with an isolated Git checkout under `package-user-dir'."
  (declare (indent 0) (debug t))
  `(let* ((test-root (make-temp-file "dotfiles-emacs-packages-" t))
          (user-emacs-directory (file-name-as-directory test-root))
          (default-directory user-emacs-directory)
          (package-user-dir (expand-file-name "elpa/" test-root))
          (checkout (expand-file-name "example" package-user-dir))
          (custom-file (expand-file-name "custom-local.el" test-root))
          (package-quickstart-file (expand-file-name "package-quickstart.el" test-root))
          (package-quickstart nil)
          (package-native-compile nil)
          (package-alist nil)
          (package-activated-list nil)
          (package-vc-register-as-project nil)
          (project-list-file (expand-file-name "projects" test-root))
          (load-path (copy-sequence load-path))
          (native-comp-enable-subr-trampolines nil)
          (process-environment
           (append (list (concat "HOME=" test-root)
                         (concat "XDG_CACHE_HOME=" test-root "/cache")
                         "GIT_CONFIG_GLOBAL=/dev/null" "GIT_CONFIG_NOSYSTEM=1")
                   process-environment)))
     (unwind-protect
         (progn
           (make-directory checkout t)
           (my/dotfiles--git-output checkout "init" "-q")
           (with-temp-file (expand-file-name "example.el" checkout)
             (insert ";;; example.el --- Fixture -*- lexical-binding: t; -*-\n;; Version: 0.1\n"
                     ";;;###autoload\n(defun example-test-command () 'vc)\n(provide 'example)\n"))
           (with-temp-file (expand-file-name "example-autoloads.el" checkout)
             (insert ";;; Generated fixture autoloads -*- lexical-binding: t; -*-\n"
                     "(add-to-list 'load-path (file-name-directory load-file-name))\n"))
           (my/dotfiles--git-output checkout "add" ".")
           (my/dotfiles--git-output checkout "-c" "user.name=Fixture"
                                     "-c" "user.email=fixture@example.invalid"
                                     "commit" "-qm" "Fixture")
           (my/dotfiles--git-output checkout "remote" "add" "origin"
                                     "https://example.invalid/fixture.git")
           ,@body)
       (delete-directory test-root t))))

(defun dotfiles-packages-test--register-vc (directory)
  "Register the fixture's VC package descriptor in DIRECTORY."
  (setf (alist-get 'example package-alist)
        (list (package-desc-create :name 'example :kind 'vc :dir directory))))

(defun dotfiles-packages-test--install-archive ()
  "Create and activate a genuine archive descriptor in the fixture."
  (let ((archive (expand-file-name "example-1.0" package-user-dir)))
    (make-directory archive)
    (with-temp-file (expand-file-name "example-pkg.el" archive)
      (insert "(define-package \"example\" \"1.0\" \"Archive fixture\" nil)\n"))
    (with-temp-file (expand-file-name "example-autoloads.el" archive)
      (insert ";;; Archive fixture autoloads -*- lexical-binding: t -*-\n"
              "(add-to-list 'load-path (file-name-directory load-file-name))\n"))
    (with-temp-file (expand-file-name "example.el" archive)
      (insert ";;; Existing archive source, retained when adding the VC package.\n"))
    (let ((package-directory-list nil)
          (package--initialized nil))
      (package-initialize))
    (should (package-installed-p 'example))
    (should-not (my/dotfiles--installed-vc-package 'example))
    archive))

(ert-deftest dotfiles-packages-authoritative-codex-recipe ()
  (should (equal package-vc-selected-packages my/dotfiles-vc-packages))
  (let ((spec (assq 'codex-ide my/dotfiles-vc-packages)))
    (should (equal (plist-get (cdr spec) :url)
                   "https://github.com/dgillis/emacs-codex-ide"))
    (should (equal (plist-get (cdr spec) :lisp-dir) ".")))
  (should (assq 'docker-compose-mode my/dotfiles-vc-packages))
  (should-not (memq 'docker-compose-mode my/dotfiles-elpa-packages)))

(ert-deftest dotfiles-packages-reuses-clean-checkout-without-fetching ()
  (dotfiles-packages-test--with-checkout
    (let ((rebuilt nil))
      (cl-letf (((symbol-function 'package-vc-install)
                 (lambda (&rest _) (ert-fail "Existing checkout must not be cloned or overwritten")))
                ((symbol-function 'package-vc-rebuild)
                 (lambda (desc)
                   (setq rebuilt t)
                   (dotfiles-packages-test--register-vc checkout)
                   (should (eq (package-desc-name desc) 'example))
                   (should (equal (package-desc-dir desc) checkout)))))
        (should (eq (my/dotfiles-install-vc-package dotfiles-packages-test--spec)
                    'rebuilt))
        (should rebuilt)))))

(ert-deftest dotfiles-packages-descriptor-present-but-interrupted-build-resumes ()
  (dotfiles-packages-test--with-checkout
    (let ((pending (expand-file-name ".dotfiles-example-installing" package-user-dir))
          (rebuilt nil))
      (with-temp-file pending (insert "Build was interrupted\n"))
      (dotfiles-packages-test--register-vc checkout)
      (cl-letf (((symbol-function 'package-vc-install)
                 (lambda (&rest _) (ert-fail "Interrupted checkout must not be cloned")))
                ((symbol-function 'package-vc-rebuild)
                 (lambda (&rest _) (setq rebuilt t))))
        (should (eq (my/dotfiles-install-vc-package dotfiles-packages-test--spec)
                    'rebuilt))
        (should rebuilt)
        (should-not (file-exists-p pending))))))

(ert-deftest dotfiles-packages-rebuilds-a-real-fixture-offline ()
  (dotfiles-packages-test--with-checkout
    (let ((user-emacs-directory package-user-dir)
          (custom-file (expand-file-name "custom-local.el" package-user-dir))
          (package-vc-selected-packages (list dotfiles-packages-test--spec))
          (package-selected-packages '(example))
          (package-alist nil)
          (package-activated-list nil)
          (package-archive-contents nil)
          (package-native-compile nil)
          (package--initialized t)
          ;; A fixture must never become a remembered personal project.
          (project-list-file (expand-file-name "projects" package-user-dir)))
      (cl-letf (((symbol-function 'package-vc-install)
                 (lambda (&rest _) (ert-fail "Fixture rebuild must not clone")))
                ((symbol-function 'package-install-from-archive)
                 (lambda (&rest _) (ert-fail "Fixture has no external dependencies"))))
        (should (eq (my/dotfiles-install-vc-package dotfiles-packages-test--spec)
                    'rebuilt))
        (should (package-installed-p 'example))
        (should (file-exists-p (expand-file-name "example.elc" checkout)))
        (should-not (file-exists-p
                     (expand-file-name ".dotfiles-example-installing" package-user-dir)))))))

(ert-deftest dotfiles-packages-migrates-archive-to-vc-without-deleting-archive ()
  (dotfiles-packages-test--with-checkout
    (let* ((upstream (expand-file-name "upstream" test-root))
           (spec `(example :url ,upstream :lisp-dir "." :vc-backend Git))
           (package-vc-selected-packages (list spec))
           ;; A real local clone must never ask the network for archive metadata.
           (package-archive-contents '((fixture)))
           (package-vc--archive-data-alist '(("fixture")))
           (package--initialized t))
      (rename-file checkout upstream)
      (let* ((archive (dotfiles-packages-test--install-archive))
             (archive-file (expand-file-name "example.el" archive))
             (archive-content (with-temp-buffer
                                (insert-file-contents archive-file)
                                (buffer-string))))
        ;; package-initialize reads archive caches, which this fixture lacks.
        (setq package-archive-contents '((fixture)))
        (cl-letf (((symbol-function 'package-refresh-contents)
                   (lambda (&rest _) (ert-fail "Fixture must not refresh archives")))
                  ((symbol-function 'url-retrieve-synchronously)
                   (lambda (&rest _) (ert-fail "Fixture must not access the network")))
                  ((symbol-function 'package-install-from-archive)
                   (lambda (&rest _) (ert-fail "Fixture has no external dependencies"))))
          (should (eq (my/dotfiles-install-vc-package spec) 'installed))
          (should (my/dotfiles--installed-vc-package 'example))
          (should (file-equal-p
                   (package-desc-dir (my/dotfiles--installed-vc-package 'example))
                   checkout))
          (should (file-exists-p (expand-file-name "example.elc" checkout)))
          (should-not (file-exists-p archive))
          (let ((backups (directory-files-recursively
                          (expand-file-name "package-archive-backups" test-root)
                          "example\\.el\\'")))
            (should (= (length backups) 1))
            (should (equal (with-temp-buffer
                             (insert-file-contents (car backups))
                             (buffer-string))
                           archive-content)))
          (should (eq (my/dotfiles-install-vc-package spec) 'already-installed))
          ;; The VC descriptor must retain precedence after package discovery.
          (let ((package-alist nil)
                (package-activated-list nil)
                (package-directory-list nil)
                (package--initialized nil))
            (package-initialize)
            (should (my/dotfiles--installed-vc-package 'example))
            (should (package-vc-p (cadr (assq 'example package-alist))))
            (should (file-in-directory-p (locate-library "example") checkout))
            (should (= (length (cdr (assq 'example package-alist))) 1))))))))

(ert-deftest dotfiles-packages-resumes-vc-build-while-archive-remains-installed ()
  (dotfiles-packages-test--with-checkout
    (let ((archive (dotfiles-packages-test--install-archive))
          (package-vc-selected-packages (list dotfiles-packages-test--spec))
          (pending (expand-file-name ".dotfiles-example-installing" package-user-dir)))
      (with-temp-file pending (insert "Interrupted migration\n"))
      (cl-letf (((symbol-function 'package-vc-install)
                 (lambda (&rest _) (ert-fail "Existing checkout must be reused")))
                ((symbol-function 'package-install-from-archive)
                 (lambda (&rest _) (ert-fail "Fixture has no external dependencies"))))
        (should (eq (my/dotfiles-install-vc-package dotfiles-packages-test--spec)
                    'rebuilt)))
      (should (my/dotfiles--installed-vc-package 'example))
      (should-not (file-directory-p archive))
      (should (directory-files-recursively
               (expand-file-name "package-archive-backups" test-root) "example-pkg\\.el\\'"))
      (should-not (file-exists-p pending)))))

(ert-deftest dotfiles-packages-archive-does-not-mask-incomplete-vc-registration ()
  (dotfiles-packages-test--with-checkout
    (rename-file checkout (expand-file-name "upstream" test-root))
    (let ((archive (dotfiles-packages-test--install-archive)))
      (cl-letf (((symbol-function 'package-vc-install) #'ignore))
        (should-error (my/dotfiles-install-vc-package dotfiles-packages-test--spec)))
      (should (file-directory-p archive))
      (should (file-exists-p (expand-file-name ".dotfiles-example-installing" package-user-dir))))))

(ert-deftest dotfiles-packages-rebuild-keeps-inherited-quickstart-cache-untouched ()
  (let* ((outside (make-temp-file "dotfiles-other-emacs-" t))
         (package-quickstart-file (expand-file-name "package-quickstart.el" outside)))
    (unwind-protect
        (progn
          (dolist (file (list package-quickstart-file (concat package-quickstart-file "c")))
            (with-temp-file file (insert "Do not touch another Emacs configuration.\n")))
          (dotfiles-packages-test--with-checkout
            (let ((package-vc-selected-packages (list dotfiles-packages-test--spec)))
              (should (eq (my/dotfiles-install-vc-package dotfiles-packages-test--spec)
                          'rebuilt))))
          (dolist (file (list package-quickstart-file (concat package-quickstart-file "c")))
            (should (equal (with-temp-buffer
                             (insert-file-contents file)
                             (buffer-string))
                           "Do not touch another Emacs configuration.\n"))))
      (delete-directory outside t))))

(ert-deftest dotfiles-packages-reuses-checkout-after-generated-autoload-write ()
  (dotfiles-packages-test--with-checkout
    (with-temp-file (expand-file-name "example-autoloads.el" checkout)
      (insert ";;; Regenerated during the interrupted build\n"))
    (with-temp-file (expand-file-name "example-pkg.el" checkout)
      (insert ";;; Generated descriptor\n"))
    (with-temp-file (expand-file-name "example.elc" checkout)
      (insert "generated bytecode"))
    (should-not (my/dotfiles--check-vc-checkout
                 dotfiles-packages-test--spec checkout t))))

(ert-deftest dotfiles-packages-refuses-tracked-source-edits-without-deleting ()
  (dotfiles-packages-test--with-checkout
    (with-temp-file (expand-file-name "example.el" checkout)
      (insert ";;; User's source edit\n"))
    (cl-letf (((symbol-function 'package-installed-p) (lambda (&rest _) nil))
              ((symbol-function 'package-vc-install)
               (lambda (&rest _) (ert-fail "Must preserve the edited checkout")))
              ((symbol-function 'package-vc-rebuild)
               (lambda (&rest _) (ert-fail "Must not build a modified checkout"))))
      (should-error (my/dotfiles-install-vc-package dotfiles-packages-test--spec)))
    (should (file-exists-p (expand-file-name "example.el" checkout)))
    (should (string-match-p "example.el"
                            (my/dotfiles--git-output checkout "diff" "--name-only")))))

(ert-deftest dotfiles-packages-refuses-untracked-source-edits ()
  (dotfiles-packages-test--with-checkout
    (with-temp-file (expand-file-name "local-extension.el" checkout)
      (insert ";;; User's additional source\n"))
    (should-error (my/dotfiles--check-vc-checkout
                   dotfiles-packages-test--spec checkout t))
    (should (file-exists-p (expand-file-name "local-extension.el" checkout)))))

(ert-deftest dotfiles-packages-refuses-wrong-project-with-same-package-name ()
  (dotfiles-packages-test--with-checkout
    (my/dotfiles--git-output checkout "remote" "set-url" "origin"
                              "https://example.invalid/unrelated-project")
    (dotfiles-packages-test--register-vc checkout)
    (should-error (my/dotfiles-install-vc-package dotfiles-packages-test--spec))
    (should (file-directory-p checkout))))

(ert-deftest dotfiles-packages-existing-correct-package-never-rebuilds ()
  (dotfiles-packages-test--with-checkout
    (dotfiles-packages-test--register-vc checkout)
    (cl-letf (((symbol-function 'package-vc-install)
               (lambda (&rest _) (ert-fail "Installed package must not be cloned")))
              ((symbol-function 'package-vc-rebuild)
               (lambda (&rest _) (ert-fail "Installed package must not be rebuilt"))))
      (should (eq (my/dotfiles-install-vc-package dotfiles-packages-test--spec)
                  'already-installed)))))

(ert-deftest dotfiles-packages-new-install-refuses-an-unexpected-prompt ()
  (let* ((test-root (make-temp-file "dotfiles-emacs-new-" t))
         (package-user-dir (file-name-as-directory test-root))
         (native-comp-enable-subr-trampolines nil))
    (unwind-protect
        (cl-letf (((symbol-function 'package-installed-p) (lambda (&rest _) nil))
                  ((symbol-function 'package-vc-install)
                   (lambda (&rest _) (yes-or-no-p "Delete user files? "))))
          (should-error (my/dotfiles-install-vc-package dotfiles-packages-test--spec))
          (should (file-exists-p
                   (expand-file-name ".dotfiles-example-installing" package-user-dir))))
      (delete-directory test-root t))))

;;; setup-packages-tests.el ends here
