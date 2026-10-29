;;; portability-tests.el --- Isolated shared-config checks -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'org)
(require 'package)
(require 'use-package)
(require 'use-package-ensure)

(defconst portability-test-config-dir
  (expand-file-name "../.emacs.d/" (file-name-directory load-file-name)))

(defun portability-test-forms (name)
  "Read Lisp source blocks from NAME without tangling or loading user init."
  (with-temp-buffer
    (insert-file-contents (expand-file-name name portability-test-config-dir))
    (org-mode)
    (apply #'append
           (org-element-map (org-element-parse-buffer) 'src-block
             (lambda (block)
               (when (equal (org-element-property :language block) "emacs-lisp")
                 (read (concat "(" (org-element-property :value block) "\n)"))))))))

(defvar elpy-rpc-virtualenv-path)
(defvar elpy-rpc-python-command)
(defvar elpy-modules)
(defvar python-ts-mode-hook)
(defvar my/cliplink-last-link)
(defvar portability-test-events)
(defvar my/dotfiles-elpa-packages)
(defvar my/dotfiles-vc-packages)
(defvar my/dotfiles-configuration-loaded)

(defun portability-test-load-python ()
  "Load actual Python forms without Elpy, subprocesses or package acquisition."
  (let ((original-require (symbol-function 'require))
        (native-comp-enable-subr-trampolines nil)
        (use-package-always-ensure nil)
        (use-package-expand-minimally t))
    (cl-letf (((symbol-function 'elpy-enable) #'ignore)
              ((symbol-function 'require)
               (lambda (feature &rest args)
                 (if (eq feature 'elpy) t
                   (apply original-require feature args))))
              ((symbol-function 'use-package-ensure-elpa)
               (lambda (_name ensure _state)
                 (when (cl-some #'identity ensure)
                   (error "Startup must not install packages"))
                 t))
              ((symbol-function 'call-process)
               (lambda (&rest _) (error "Python startup must not run a process")))
              ((symbol-function 'start-process)
               (lambda (&rest _) (error "Python startup must not run a process"))))
      (dolist (form (portability-test-forms "python.org")) (eval form t)))))

(ert-deftest portability-python-preserves-existing-rpc-choices ()
  (dolist (environment '(default "/Users/example/venvs/elpy"))
    (let ((system-type 'gnu/linux)
          (elpy-rpc-virtualenv-path environment)
          (elpy-rpc-python-command "/custom/python3")
          (elpy-modules '(elpy-module-flymake))
          (python-ts-mode-hook nil))
      (portability-test-load-python)
      (should (equal elpy-rpc-virtualenv-path environment))
      (should (equal elpy-rpc-python-command "/custom/python3"))
      (should (memq #'elpy-mode python-ts-mode-hook)))))

(defmacro portability-test-with-python-home (&rest body)
  "Run BODY with isolated environment paths and Elpy settings."
  (declare (indent 0))
  `(let* ((root (make-temp-file "python-portability-" t))
          (process-environment (copy-sequence process-environment))
          (system-type 'darwin)
          (exec-path (list (expand-file-name "project/bin" root)))
          (elpy-rpc-virtualenv-path 'default)
          (elpy-rpc-python-command "/existing/python3")
          (elpy-modules '(elpy-module-flymake))
          (python-ts-mode-hook nil))
     (unwind-protect
         (progn
           (setenv "HOME" root)
           (setenv "XDG_DATA_HOME" (expand-file-name "data with spaces" root))
           (setenv "PATH" (car exec-path))
           ,@body)
       (delete-directory root t))))

(defun portability-test-python-executable (path)
  "Create a fake executable at PATH; no test should invoke it."
  (make-directory (file-name-directory path) t)
  (with-temp-file path (insert "#!/bin/sh\nexit 99\n"))
  (set-file-modes path #o755)
  path)

(ert-deftest portability-macos-python-backend-keeps-project-interpreter-first ()
  (portability-test-with-python-home
    (let* ((backend (expand-file-name "dotfiles/python" (getenv "XDG_DATA_HOME")))
           (bin (expand-file-name "bin" backend))
           (project-python (portability-test-python-executable
                            (expand-file-name "python3" (car exec-path)))))
      (dolist (name '("python" "python3" "black" "flake8"))
        (portability-test-python-executable (expand-file-name name bin)))
      (dotimes (_ 2) (portability-test-load-python))
      (should (equal elpy-rpc-virtualenv-path backend))
      (should (equal elpy-rpc-python-command (expand-file-name "python" bin)))
      (should (equal (executable-find "python3") project-python))
      (should (equal (car (split-string (getenv "PATH") path-separator))
                     (directory-file-name (file-name-directory project-python))))
      (dolist (tool '("black" "flake8"))
        (should (equal (executable-find tool) (expand-file-name tool bin))))
      (should (= (cl-count bin exec-path :test #'equal) 1))
      (should (= (cl-count bin (split-string (getenv "PATH") path-separator)
                           :test #'equal) 1)))))

(ert-deftest portability-macos-python-backend-uses-default-xdg-data-home ()
  (dolist (xdg-value '(nil ""))
    (portability-test-with-python-home
      (setenv "XDG_DATA_HOME" xdg-value)
      (let ((backend (expand-file-name ".local/share/dotfiles/python" root)))
        (portability-test-python-executable (expand-file-name "bin/python" backend))
        (portability-test-load-python)
        (should (equal elpy-rpc-virtualenv-path backend))))))

(ert-deftest portability-macos-missing-python-backend-keeps-existing-settings ()
  (dolist (exists '(nil t))
    (portability-test-with-python-home
      (let ((python (expand-file-name "dotfiles/python/bin/python" (getenv "XDG_DATA_HOME")))
            (old-path (getenv "PATH"))
            (old-exec-path (copy-sequence exec-path)))
        (when exists
          (portability-test-python-executable python)
          (set-file-modes python #o644))
        (portability-test-load-python)
        (should (eq elpy-rpc-virtualenv-path 'default))
        (should (equal elpy-rpc-python-command "/existing/python3"))
        (should (equal exec-path old-exec-path))
        (should (equal (getenv "PATH") old-path))
        (unless exists
          (should-not (file-exists-p (getenv "XDG_DATA_HOME"))))))))

(ert-deftest portability-linux-ignores-macos-python-backend ()
  (portability-test-with-python-home
    (let ((system-type 'gnu/linux)
          (old-exec-path (copy-sequence exec-path)))
      (portability-test-python-executable
       (expand-file-name "dotfiles/python/bin/python" (getenv "XDG_DATA_HOME")))
      (portability-test-load-python)
      (should (eq elpy-rpc-virtualenv-path 'default))
      (should (equal elpy-rpc-python-command "/existing/python3"))
      (should (equal exec-path old-exec-path)))))

(defun portability-test-clip (clipboard ring)
  "Run the actual clipping function with fake clipboard and network services."
  (let ((definition
         (cl-find-if (lambda (form)
                       (and (eq (car-safe form) 'defun)
                            (eq (cadr form) 'my/cliplink-capture-file)))
                     (portability-test-forms "org.org")))
        (kill-ring ring)
        (kill-ring-yank-pointer ring)
        (interprogram-paste-function (lambda () clipboard))
        (interprogram-cut-function nil)
        (org-directory "/tmp/portability-vault/")
        (my/cliplink-last-link nil))
    (eval definition t)
    (cl-letf (((symbol-function 'shell-command-to-string)
               (lambda (&rest _) (error "Clipboard must not invoke a shell")))
              ((symbol-function 'org-cliplink-retrieve-title-synchronously)
               (lambda (url)
                 (should (equal url "https://example.com/note"))
                 "Example"))
              ((symbol-function 'org-cliplink-org-mode-link-transformer)
               (lambda (_url _title) "expected-link"))
              ((symbol-function 'org-cliplink-escape-html4) #'identity)
              ((symbol-function 'my/org-title-to-path)
               (lambda (directory title)
                 (should (equal title "Example"))
                 (expand-file-name "Example.org" directory))))
      (let ((result (my/cliplink-capture-file)))
        (should (equal my/cliplink-last-link "expected-link"))
        result))))

(ert-deftest portability-clipping-prefers-native-clipboard-on-macos-and-linux ()
  (dolist (system-type '(darwin gnu/linux))
    (should (equal (portability-test-clip " https://example.com/note\n" '("stale text"))
                   "/tmp/portability-vault/Example.org"))))

(ert-deftest portability-clipping-supports-terminal-kill-ring ()
  (should (equal (portability-test-clip nil '("https://example.com/note"))
                 "/tmp/portability-vault/Example.org")))

(ert-deftest portability-clipping-empty-input-is-a-user-error ()
  (should-error (portability-test-clip nil nil) :type 'user-error))

(ert-deftest portability-imports-shell-path-only-on-macos-gui-or-daemon ()
  (let ((form (car (portability-test-forms "general.org"))))
    (dolist (case '((darwin t nil 1) (darwin nil t 1) (darwin nil nil 0)
                   (gnu/linux t nil 0) (gnu/linux nil t 0)))
      (let ((system-type (nth 0 case))
            (gui (nth 1 case))
            (daemon (nth 2 case))
            (expected (nth 3 case))
            (original-require (symbol-function 'require))
            (use-package-always-ensure nil)
            (use-package-expand-minimally t)
            (installs 0)
            (imports 0))
        (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) gui))
                  ((symbol-function 'daemonp) (lambda () daemon))
                  ((symbol-function 'require)
                   (lambda (feature &rest args)
                     (if (eq feature 'exec-path-from-shell) t
                       (apply original-require feature args))))
                  ((symbol-function 'use-package-ensure-elpa)
                   (lambda (&rest _) (cl-incf installs) t))
                  ((symbol-function 'exec-path-from-shell-initialize)
                   (lambda () (cl-incf imports))))
          (eval form t))
        (should (= imports expected))
        (should (= installs 0))))))

(defun portability-test-init (with-local &optional check-missing)
  "Load init with fake packages and a temporary configuration directory.
When CHECK-MISSING is non-nil, run the real strict configuration checker."
  (let* ((root (make-temp-file "emacs-portability-" t))
         (user-emacs-directory (file-name-as-directory root))
         (custom-file nil)
         (package-archives nil)
         (package-selected-packages nil)
         (package-vc-selected-packages nil)
         (my/dotfiles-elpa-packages nil)
         (my/dotfiles-vc-packages nil)
         (my/dotfiles-configuration-loaded nil)
         (elpy-rpc-virtualenv-path 'default)
         (portability-test-events nil)
         (original-load (symbol-function 'load)))
    (unwind-protect
        (progn
          (when with-local
            (with-temp-file (expand-file-name "local.el" root)
              (insert "(setq portability-test-events (append portability-test-events '(local))\n"
                      "      elpy-rpc-virtualenv-path 'current)\n")))
          (cl-letf (((symbol-function 'package-initialize) #'ignore)
                    ((symbol-function 'package-installed-p) (lambda (&rest _) t))
                    ((symbol-function 'my/dotfiles-missing-packages)
                     (lambda () '(optional-unavailable-package)))
                    ((symbol-function 'display-warning) #'ignore)
                    ((symbol-function 'load)
                     (lambda (file &rest args)
                       (if (equal (file-name-nondirectory file) "packages.el")
                           t
                         (apply original-load file args))))
                    ((symbol-function 'org-babel-load-file)
                     (lambda (file &rest _)
                       (should (equal file (expand-file-name "configuration.org" root)))
                       (setq portability-test-events '(shared)))))
            (load (or (getenv "EMACS_PORTABILITY_INIT")
                      (expand-file-name "init.el" portability-test-config-dir))
                  nil t)
            (should my/dotfiles-configuration-loaded)
            (when check-missing
              (let ((failure
                     (should-error
                      (load (expand-file-name "check-config.el" portability-test-config-dir)
                            nil t))))
                (should (string-match-p
                         "Shared Emacs packages are missing:.*optional-unavailable-package"
                         (error-message-string failure))))))
          (should (equal portability-test-events
                         (if with-local '(shared local) '(shared))))
          (should (eq elpy-rpc-virtualenv-path (if with-local 'current 'default))))
      (delete-directory root t))))

(ert-deftest portability-init-keeps-loading-with-an-optional-package-missing ()
  (portability-test-init nil))

(ert-deftest portability-init-loads-machine-overrides-after-shared-settings ()
  (portability-test-init t))

(ert-deftest portability-strict-check-rejects-packages-tolerated-at-startup ()
  (portability-test-init nil t))

;;; portability-tests.el ends here
