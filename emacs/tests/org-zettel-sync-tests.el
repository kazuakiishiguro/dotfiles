;;; org-zettel-sync-tests.el --- Isolated Org vault regression tests -*- lexical-binding: t; -*-

;; Run without the user's init:
;; ORG_ZETTEL_CONFIG=/path/to/.emacs.d/org.org emacs --batch -Q \
;;   -l tests/org-zettel-sync-tests.el -f ert-run-tests-batch-and-exit
;; Only selected configuration forms are loaded.  Every note is a temporary
;; fixture; filesystem writes and visits are rejected outside its directory.

(require 'ert)
(require 'cl-lib)
(require 'org)
(require 'org-capture)
(require 'org-element)
(require 'subr-x)

(defvar org-zettel-test-config-file
  (or (getenv "ORG_ZETTEL_CONFIG")
      (expand-file-name "../.emacs.d/org.org"
                        (file-name-directory (or load-file-name buffer-file-name))))
  "Literate configuration whose note-sync definitions are under test.")

(defun org-zettel-test--sync-symbol-p (symbol)
  (and (symbolp symbol)
       (or (string-prefix-p "my/org-" (symbol-name symbol))
           (string-prefix-p "my/capture-" (symbol-name symbol))
           (eq symbol 'my/deft-new-note))))

(defun org-zettel-test--load-config ()
  "Read relevant definitions and hook registrations, without running init."
  (with-temp-buffer
    (insert-file-contents org-zettel-test-config-file)
    (goto-char (point-min))
    (let ((case-fold-search t))
      (while (re-search-forward "^#\\+begin_src[ \t]+emacs-lisp\\b[^\n]*\n" nil t)
        (let ((start (point)))
          (unless (re-search-forward "^#\\+end_src[ \t]*$" nil t)
            (error "Unterminated Emacs Lisp source block"))
          (let ((source (buffer-substring-no-properties start (match-beginning 0))))
            (with-temp-buffer
              (insert source)
              (goto-char (point-min))
              (condition-case nil
                  (while t
                    (let ((form (read (current-buffer))))
                      (when
                          (or
                           (and (memq (car-safe form) '(defun defvar defvar-local))
                                (or (org-zettel-test--sync-symbol-p (cadr form))
                                    (memq (cadr form)
                                          '(my/capture-last-title my/capture-title
                                            my/cliplink-last-link))))
                           (and (eq (car-safe form) 'setq)
                                (eq (cadr form) 'org-capture-templates))
                           (and (eq (car-safe form) 'advice-add)
                                (eq (cadr (nth 1 form)) 'org-capture-target-buffer)
                                (org-zettel-test--sync-symbol-p (cadr (nth 3 form))))
                           (and (memq (car-safe form) '(add-hook remove-hook))
                                (memq (cadr (nth 1 form))
                                      '(find-file-hook before-save-hook after-save-hook))
                                (org-zettel-test--sync-symbol-p (cadr (nth 2 form)))))
                        (eval form t))))
                (end-of-file nil)))))))))

;; Clear only these test-process hooks before evaluating the actual hook forms.
(setq find-file-hook nil before-save-hook nil after-save-hook nil)
(org-zettel-test--load-config)
(defvar org-zettel-test--find-hooks (copy-sequence find-file-hook))
(defvar org-zettel-test--before-hooks (copy-sequence before-save-hook))
(defvar org-zettel-test--after-hooks (copy-sequence after-save-hook))

(defun org-zettel-test--assert-fixture-path (path root)
  (unless (and (stringp path) (file-in-directory-p path root))
    (error "Test refused access outside fixture directory: %S" path)))

(defmacro org-zettel-test--with-vault (&rest body)
  "Run BODY in a disposable vault, with the configuration's real hooks."
  (declare (indent 0) (debug t))
  `(let* ((test-root (make-temp-file "org-zettel-regression-" t))
          (org-directory (file-name-as-directory test-root))
          (default-directory org-directory)
          (find-file-hook (copy-sequence org-zettel-test--find-hooks))
          (before-save-hook (copy-sequence org-zettel-test--before-hooks))
          (after-save-hook (copy-sequence org-zettel-test--after-hooks))
          (org-mode-hook nil)
          (org-element-cache-persistent nil)
          ;; Mocking a native subr must not write compiler cache fixtures.
          (native-comp-enable-subr-trampolines nil)
          (my/org-sync-in-progress nil)
          (create-lockfiles nil)
          (make-backup-files nil)
          (backup-inhibited t)
          (auto-save-default nil)
          (original-write (symbol-function 'write-region))
          (original-rename (symbol-function 'rename-file))
          (original-visit (symbol-function 'find-file-noselect)))
     (unwind-protect
         (cl-letf (((symbol-function 'write-region)
                    (lambda (start end filename &rest args)
                      (org-zettel-test--assert-fixture-path filename test-root)
                      (apply original-write start end filename args)))
                   ((symbol-function 'rename-file)
                    (lambda (old new &rest args)
                      (org-zettel-test--assert-fixture-path old test-root)
                      (org-zettel-test--assert-fixture-path new test-root)
                      (apply original-rename old new args)))
                   ((symbol-function 'find-file-noselect)
                    (lambda (filename &rest args)
                      (org-zettel-test--assert-fixture-path filename test-root)
                      (apply original-visit filename args))))
           ,@body)
       (dolist (buffer (buffer-list))
         (when (and (buffer-live-p buffer)
                    (buffer-local-value 'buffer-file-name buffer)
                    (file-in-directory-p
                     (buffer-local-value 'buffer-file-name buffer) test-root))
           (with-current-buffer buffer
             (set-buffer-modified-p nil)
             (let ((kill-buffer-query-functions nil) (kill-buffer-hook nil))
               (kill-buffer buffer)))))
       (delete-directory test-root t))))

(defun org-zettel-test--file (name)
  (expand-file-name name org-directory))

(defun org-zettel-test--write (name text)
  (let ((file (org-zettel-test--file name)))
    (make-directory (file-name-directory file) t)
    (write-region text nil file nil 'silent)
    file))

(defun org-zettel-test--read (name)
  (with-temp-buffer
    (insert-file-contents (org-zettel-test--file name))
    (buffer-string)))

(defun org-zettel-test--visit (name)
  (find-file-noselect (org-zettel-test--file name)))

(defun org-zettel-test--replace (old new)
  (goto-char (point-min))
  (unless (search-forward old nil t)
    (error "Fixture string not found: %S" old))
  (replace-match new t t))

(defun org-zettel-test--occurrences (needle text)
  (let ((start 0) (count 0))
    (while (string-match (regexp-quote needle) text start)
      (setq count (1+ count) start (match-end 0)))
    count))

(ert-deftest org-zettel-capture-starts-writing-under-summary-heading ()
  (org-zettel-test--with-vault
    (let ((org-capture-templates (copy-tree org-capture-templates))
          (my/capture-last-title "Synthetic note")
          (my/cliplink-last-link "[[https://example.invalid/][Synthetic source]]"))
      (dolist (key '("n" "c"))
        (with-temp-buffer
          (org-mode)
          (let ((target (current-buffer))
                (entry (assoc key org-capture-templates))
                capture-buffer)
            (setf (nth 3 entry) (list 'function (lambda () (set-buffer target))))
            (setcdr (nthcdr 4 entry) '(:no-save t))
            (unwind-protect
                (progn
                  (org-capture nil key)
                  (setq capture-buffer (current-buffer))
                  (should (bolp))
                  (should (equal "* 概要"
                                 (save-excursion
                                   (forward-line -1)
                                   (buffer-substring-no-properties
                                    (line-beginning-position) (line-end-position)))))
                  (should (= 1 (org-zettel-test--occurrences "* 概要" (buffer-string))))
                  (should (string-match-p "^#\\+TITLE: Synthetic note$" (buffer-string)))
                  (should (string-match-p "^#\\+DATE: \\[" (buffer-string)))
                  (when (equal key "c")
                    (should (string-match-p (regexp-quote my/cliplink-last-link)
                                            (buffer-string)))))
              (when (buffer-live-p capture-buffer)
                (with-current-buffer capture-buffer
                  (org-capture-kill))))))))))

(ert-deftest org-zettel-link-insertion-accepts-new-title-without-creating-file ()
  (org-zettel-test--with-vault
    (let* ((text "#+TITLE: Source\n\n* 概要\n")
           (source (org-zettel-test--write "nested/Source.org" text))
           (before (file-attributes source)))
      (with-current-buffer (org-zettel-test--visit "nested/Source.org")
        (goto-char (point-max))
        (cl-letf (((symbol-function 'completing-read)
                   (lambda (_prompt _collection &optional _predicate require-match
                                    &rest _rest)
                     (should-not require-match)
                     "  new concept.org  ")))
          (my/org-insert-link))
        (should (string-suffix-p "[[file:../New_concept.org][New concept]]"
                                 (buffer-string))))
      (should-not (file-exists-p (org-zettel-test--file "New_concept.org")))
      (should-not (find-buffer-visiting (org-zettel-test--file "New_concept.org")))
      (should (equal (org-zettel-test--read "nested/Source.org") text))
      (should (equal (file-attribute-modification-time before)
                     (file-attribute-modification-time (file-attributes source)))))))

(ert-deftest org-zettel-link-insertion-preserves-existing-path-and-escapes-brackets ()
  (org-zettel-test--with-vault
    (let ((existing (org-zettel-test--write "nested/[lower_case].org" "Saved.\n")))
      (with-temp-buffer
        (setq buffer-file-name (org-zettel-test--file "Source.org"))
        (org-mode)
        (cl-letf (((symbol-function 'completing-read)
                   (lambda (&rest _args) "nested/[lower_case].org")))
          (my/org-insert-link))
        (let ((link (org-element-map (org-element-parse-buffer) 'link #'identity nil t)))
          (should (equal (org-element-property :type link) "file"))
          (should (equal (org-element-property :path link) "nested/[lower_case].org"))
          (should (equal (my/org-outgoing-files) (list existing)))))
      (should (equal (org-zettel-test--read "nested/[lower_case].org") "Saved.\n")))))

(ert-deftest org-zettel-new-link-normalizes-title-and-keeps-vault-relative-directory ()
  (org-zettel-test--with-vault
    (should (equal (my/org-new-link-file "nested/new concept")
                   (org-zettel-test--file "nested/New_concept.org")))
    (should (equal (my/org-new-link-file "new_concept.org")
                   (org-zettel-test--file "New_concept.org")))
    (should (equal (my/org-new-link-file "日本語 のノート")
                   (org-zettel-test--file "日本語_のノート.org")))
    (should-not (file-exists-p (org-zettel-test--file "nested")))
    (dolist (bad '("" ".org" "nested/" "../escape" "nested/../../escape"
                   "/tmp/Outside.org" "Note.org::heading"))
      (should-error (my/org-new-link-file bad) :type 'user-error))))

(ert-deftest org-zettel-opening-missing-note-prepares-unsaved-summary ()
  (org-zettel-test--with-vault
    (with-current-buffer (org-zettel-test--visit "Future_note.org")
      (should (equal (my/org-get-title) "Future note"))
      (should (string-match-p "^#\\+DATE: \\[" (buffer-string)))
      (should (string-suffix-p "\n\n* 概要\n" (buffer-string)))
      (should (= (point) (point-max)))
      (should (buffer-modified-p))
      (should-not (file-exists-p buffer-file-name))
      (let ((text (buffer-string)))
        (my/org-initialize-new-note)
        (should (equal text (buffer-string))))
      (insert "Written now.\n")
      (save-buffer)
      (should (file-exists-p buffer-file-name))
      (should (string-suffix-p "* 概要\nWritten now.\n"
                               (org-zettel-test--read "Future_note.org"))))))

(ert-deftest org-zettel-following-missing-org-link-opens-unsaved-note-in-emacs ()
  (org-zettel-test--with-vault
    (let ((text "#+TITLE: Source\n\n[[file:Future_note.org][Future note]]\n"))
      (org-zettel-test--write "Source.org" text)
      (save-window-excursion
        (switch-to-buffer (org-zettel-test--visit "Source.org"))
        (goto-char (point-min))
        (search-forward "[[file:")
        (let ((org-open-non-existing-files nil))
          (org-open-at-point))
        (let ((target (find-buffer-visiting (org-zettel-test--file "Future_note.org"))))
          (should target)
          (with-current-buffer target
            (should (equal (my/org-get-title) "Future note"))
            (should (string-suffix-p "* 概要\n" (buffer-string)))
            (should (buffer-modified-p))
            (should-not (file-exists-p buffer-file-name)))))
      (should (equal text (org-zettel-test--read "Source.org"))))))

(ert-deftest org-zettel-new-note-template-leaves-existing-empty-file-unchanged ()
  (org-zettel-test--with-vault
    (let* ((file (org-zettel-test--write "Empty.org" ""))
           (before (file-attributes file)))
      (with-current-buffer (org-zettel-test--visit "Empty.org")
        (should (= 0 (buffer-size)))
        (should-not (buffer-modified-p)))
      (should (equal (org-zettel-test--read "Empty.org") ""))
      (should (equal (file-attribute-modification-time before)
                     (file-attribute-modification-time (file-attributes file)))))))

(ert-deftest org-zettel-new-note-template-preserves-unsaved-content-and-scope ()
  (org-zettel-test--with-vault
    (with-temp-buffer
      (org-mode)
      (setq buffer-file-name (org-zettel-test--file "Unsaved.org"))
      (insert "User text.\n")
      (my/org-initialize-new-note)
      (should (equal (buffer-string) "User text.\n"))
      (should-not (file-exists-p buffer-file-name)))
    (dolist (name '("../Outside.org" "Plain.txt"))
      (with-temp-buffer
        (org-mode)
        (setq buffer-file-name (org-zettel-test--file name))
        (my/org-initialize-new-note)
        (should (= 0 (buffer-size)))))))

(ert-deftest org-zettel-file-capture-uses-only-its-own-template ()
  (org-zettel-test--with-vault
    (let ((org-capture-templates (copy-tree org-capture-templates))
          (org-capture-plist nil)
          (my/capture-last-title "Capture title")
          (my/cliplink-last-link "[[https://example.invalid/][Source]]"))
      (dolist (key '("n" "c"))
        (let* ((entry (assoc key org-capture-templates))
               (path (org-zettel-test--file (concat "Capture_" key ".org")))
               capture-buffer)
          (setf (nth 3 entry) (list 'file path))
          (setcdr (nthcdr 4 entry) '(:no-save t))
          (unwind-protect
              (progn
                (org-capture nil key)
                (setq capture-buffer (current-buffer))
                (should (= 1 (org-zettel-test--occurrences "#+TITLE:" (buffer-string))))
                (should (= 1 (org-zettel-test--occurrences "* 概要" (buffer-string))))
                (should (equal (my/org-get-title) "Capture title"))
                (should (bolp))
                (should-not (file-exists-p path)))
            (when (buffer-live-p capture-buffer)
              (with-current-buffer capture-buffer (org-capture-kill))))))
      ;; Capture retains its global plist; it must not suppress later links.
      (with-current-buffer (org-zettel-test--visit "After_capture.org")
        (should (equal (my/org-get-title) "After capture"))
        (should (string-suffix-p "* 概要\n" (buffer-string)))))))

(ert-deftest org-zettel-rename-matches-resolved-path-and-preserves-link-details ()
  (org-zettel-test--with-vault
    (org-zettel-test--write "Foo.org" "#+TITLE: Foo\n\n* 概要\nOriginal.\n")
    (org-zettel-test--write "MyFoo.org" "#+TITLE: MyFoo\n")
    (org-zettel-test--write "other/Foo.org" "#+TITLE: Foo\n")
    (let ((unrelated
           "[[file:MyFoo.org][Foo]]\n[[file:other/Foo.org][Foo]]\n[[https://example.invalid/][Foo]]\n")
          (relevant
           "[[file:Foo.org][Foo]]\n[[file:./Foo.org::heading][Custom description]]\n[[file:Foo.org::* 概要][Foo]]\n"))
      (org-zettel-test--write "Links.org" (concat "#+TITLE: Links\n\n" relevant unrelated))
      (with-current-buffer (org-zettel-test--visit "Foo.org")
        (org-zettel-test--replace "#+TITLE: Foo" "#+TITLE: Bar")
        (save-buffer)
        (should (equal buffer-file-name (org-zettel-test--file "Bar.org"))))
      (should-not (file-exists-p (org-zettel-test--file "Foo.org")))
      (should (file-exists-p (org-zettel-test--file "Bar.org")))
      (should (equal (org-zettel-test--read "MyFoo.org") "#+TITLE: MyFoo\n"))
      (should (equal (org-zettel-test--read "other/Foo.org") "#+TITLE: Foo\n"))
      (let ((links (org-zettel-test--read "Links.org")))
        (should (string-match-p (regexp-quote "[[file:Bar.org][Bar]]") links))
        (should (string-match-p "\\[\\[file:\\(?:\\./\\)?Bar\\.org::heading\\]\\[Custom description\\]\\]" links))
        (should (string-match-p (regexp-quote "[[file:Bar.org::* 概要][Bar]]") links))
        (should (string-match-p (regexp-quote unrelated) links))))))

(ert-deftest org-zettel-opening-mismatched-title-never-writes ()
  (org-zettel-test--with-vault
    (let* ((text "#+TITLE: A different title\n\n* 概要\nBody.\n")
           (path (org-zettel-test--write "Filename.org" text))
           (before (file-attributes path))
           (writes 0)
           (original-write (symbol-function 'write-region)))
      (cl-letf (((symbol-function 'write-region)
                 (lambda (&rest args)
                   (cl-incf writes)
                   (apply original-write args))))
        (with-current-buffer (org-zettel-test--visit "Filename.org")
          (should (equal (buffer-string) text))
          (should-not (buffer-modified-p))))
      (should (= writes 0))
      (should (equal (org-zettel-test--read "Filename.org") text))
      (should (equal (file-attribute-modification-time before)
                     (file-attribute-modification-time (file-attributes path)))))))

(ert-deftest org-zettel-reloading-removes-old-open-time-rewrite-hook ()
  (let ((find-file-hook (cons #'my/org-sync-filename-to-title
                              (copy-sequence org-zettel-test--find-hooks)))
        (before-save-hook (copy-sequence org-zettel-test--before-hooks))
        (after-save-hook (copy-sequence org-zettel-test--after-hooks)))
    (org-zettel-test--load-config)
    (should-not (memq #'my/org-sync-filename-to-title find-file-hook))
    (should (memq #'my/org-record-title find-file-hook))))

(ert-deftest org-zettel-rename-preserves-escaped-paths-and-search-options ()
  (org-zettel-test--with-vault
    (org-zettel-test--write "[Foo].org" "#+TITLE: [Foo]\n\n* 概要\n")
    (org-zettel-test--write
     "Links.org"
     (concat "#+TITLE: Links\n\n[[file:"
             (org-link-escape "[Foo].org")
             "::heading][A custom label]]\n"))
    (with-current-buffer (org-zettel-test--visit "[Foo].org")
      (org-zettel-test--replace "#+TITLE: [Foo]" "#+TITLE: [Bar]")
      (save-buffer))
    (should (string-match-p
             (regexp-quote (concat "[[file:" (org-link-escape "[Bar].org")
                                   "::heading][A custom label]]"))
             (org-zettel-test--read "Links.org")))))

(ert-deftest org-zettel-backlinks-follow-addition-removal-without-reciprocation ()
  (org-zettel-test--with-vault
    (org-zettel-test--write "A.org" "#+TITLE: A\n\n* 概要\n")
    (org-zettel-test--write "B.org" "#+TITLE: B\n\n* 概要\nBody.\n")
    (org-zettel-test--write "C.org" "#+TITLE: C\n\n* 概要\nBody.\n")
    (with-current-buffer (org-zettel-test--visit "A.org")
      (goto-char (point-max))
      (insert "[[file:B.org::heading][B]]\n")
      (save-buffer)
      (set-buffer-modified-p t)
      (save-buffer))
    (let ((target (org-zettel-test--read "B.org")))
      (should (= 1 (org-zettel-test--occurrences "[[file:A.org][A]]" target)))
      (should (string-match-p "^\\* Backlinks (1)$" target)))
    (with-current-buffer (org-zettel-test--visit "B.org")
      (goto-char (point-max))
      (insert "\n")
      (save-buffer))
    (should-not (string-match-p "^\\* Backlinks" (org-zettel-test--read "A.org")))
    (with-current-buffer (org-zettel-test--visit "A.org")
      (org-zettel-test--replace "[[file:B.org::heading][B]]\n" "[[file:C.org][C]]\n")
      (save-buffer))
    (should-not (string-match-p (regexp-quote "[[file:A.org]")
                               (org-zettel-test--read "B.org")))
    (should (= 1 (org-zettel-test--occurrences "[[file:A.org][A]]"
                                              (org-zettel-test--read "C.org"))))))

(ert-deftest org-zettel-dirty-backlink-target-is-not-auto-saved ()
  (org-zettel-test--with-vault
    (org-zettel-test--write "A.org" "#+TITLE: A\n\n* 概要\n")
    (let* ((original "#+TITLE: B\n\n* 概要\nSaved text.\n")
           (_ (org-zettel-test--write "B.org" original))
           (target (org-zettel-test--visit "B.org")))
      (with-current-buffer target
        (goto-char (point-max))
        (insert "Unsaved user edit.\n"))
      (with-current-buffer (org-zettel-test--visit "A.org")
        (goto-char (point-max))
        (insert "[[file:B.org][B]]\n")
        (save-buffer))
      (should (equal original (org-zettel-test--read "B.org")))
      (with-current-buffer target
        (should (buffer-modified-p))
        (should (string-match-p "Unsaved user edit" (buffer-string)))))))

(ert-deftest org-zettel-backlinks-ignore-generated-sections-and-source-blocks ()
  (org-zettel-test--with-vault
    (org-zettel-test--write
     "A.org"
     (concat "#+TITLE: A\n\n* 概要\n[[file:B.org][B]]\n"
             "#+begin_src org\n[[file:Example.org][Example]]\n#+end_src\n"
             "* Backlinks (1)\n\n- [[file:Incoming.org][Incoming]]\n"))
    (dolist (name '("B" "Example" "Incoming"))
      (org-zettel-test--write (concat name ".org") (format "#+TITLE: %s\n" name)))
    (with-current-buffer (org-zettel-test--visit "A.org")
      (set-buffer-modified-p t)
      (save-buffer))
    (should (string-match-p (regexp-quote "[[file:A.org][A]]")
                            (org-zettel-test--read "B.org")))
    (should (equal (org-zettel-test--read "Example.org") "#+TITLE: Example\n"))
    (should (equal (org-zettel-test--read "Incoming.org") "#+TITLE: Incoming\n"))))

(ert-deftest org-zettel-dirty-rename-link-target-is-not-auto-saved ()
  (org-zettel-test--with-vault
    (org-zettel-test--write "Foo.org" "#+TITLE: Foo\n\n* 概要\n")
    (let* ((original "#+TITLE: Links\n\n[[file:Foo.org][Foo]]\n")
           (_ (org-zettel-test--write "Links.org" original))
           (target (org-zettel-test--visit "Links.org")))
      (with-current-buffer target
        (goto-char (point-max))
        (insert "Unsaved user edit.\n"))
      (with-current-buffer (org-zettel-test--visit "Foo.org")
        (org-zettel-test--replace "#+TITLE: Foo" "#+TITLE: Bar")
        (save-buffer))
      (should (equal original (org-zettel-test--read "Links.org")))
      (with-current-buffer target
        (should (buffer-modified-p))
        (should (string-match-p "Unsaved user edit" (buffer-string)))))))

(ert-deftest org-zettel-stale-clean-link-buffer-does-not-overwrite-disk ()
  (org-zettel-test--with-vault
    (org-zettel-test--write "Foo.org" "#+TITLE: Foo\n")
    (org-zettel-test--write "Bar.org" "#+TITLE: Bar\n")
    (let* ((original "#+TITLE: Links\n\n[[file:Foo.org][Foo]]\n")
           (external (concat original "External edit.\n"))
           (path (org-zettel-test--write "Links.org" original))
           (target (org-zettel-test--visit "Links.org")))
      (org-zettel-test--write "Links.org" external)
      (set-file-times path (time-add (current-time) 5))
      (should-not (verify-visited-file-modtime target))
      (should-error
       (my/org-update-backlinks (org-zettel-test--file "Foo.org")
                                (org-zettel-test--file "Bar.org") "Foo" "Bar")
       :type 'user-error)
      (should (equal external (org-zettel-test--read "Links.org")))
      (with-current-buffer target
        (should-not (buffer-modified-p))
        (should (equal original (buffer-string)))))))

(ert-deftest org-zettel-explicit-filename-sync-refuses-existing-old-note ()
  (org-zettel-test--with-vault
    (org-zettel-test--write "Foo.org" "#+TITLE: Foo\n")
    (org-zettel-test--write "Bar.org" "#+TITLE: Foo\n\nSeparate note.\n")
    (let ((links "#+TITLE: Links\n\n[[file:Foo.org][Foo]]\n"))
      (org-zettel-test--write "Links.org" links)
      (with-current-buffer (org-zettel-test--visit "Bar.org")
        (should-error (my/org-sync-filename-to-title) :type 'user-error)
        (should-not (buffer-modified-p)))
      (should (equal (org-zettel-test--read "Foo.org") "#+TITLE: Foo\n"))
      (should (equal (org-zettel-test--read "Bar.org") "#+TITLE: Foo\n\nSeparate note.\n"))
      (should (equal (org-zettel-test--read "Links.org") links)))))

(ert-deftest org-zettel-rename-stale-unrelated-buffer-does-not-strand-inbound-links ()
  (org-zettel-test--with-vault
    (org-zettel-test--write "Foo.org" "#+TITLE: Foo\n\n* 概要\n")
    (org-zettel-test--write "Zlinks.org" "#+TITLE: Zlinks\n[[file:Foo.org][Foo]]\n")
    (org-zettel-test--write "A-unrelated.org" "#+TITLE: A-unrelated\nOriginal.\n")
    (let* ((path (org-zettel-test--file "A-unrelated.org"))
           (stale (org-zettel-test--visit "A-unrelated.org")))
      (org-zettel-test--write "A-unrelated.org" "#+TITLE: A-unrelated\nExternal edit.\n")
      (set-file-times path (time-add (current-time) 5))
      (should-not (verify-visited-file-modtime stale))
      (with-current-buffer (org-zettel-test--visit "Foo.org")
        (org-zettel-test--replace "#+TITLE: Foo" "#+TITLE: Bar")
        (condition-case error (save-buffer) (error (message "First save error: %S" error)))
        (message "After failed save: old exists=%S new exists=%S links=%S" (file-exists-p (org-zettel-test--file "Foo.org")) (file-exists-p (org-zettel-test--file "Bar.org")) (org-zettel-test--read "Zlinks.org"))
        (with-current-buffer stale (revert-buffer t t))
        (set-buffer-modified-p t)
        (save-buffer))
      (should (string-match-p (regexp-quote "[[file:Bar.org][Bar]]") (org-zettel-test--read "Zlinks.org"))))))

(ert-deftest org-zettel-renaming-then-removing-outgoing-link-cleans-backlink ()
  (org-zettel-test--with-vault
    (org-zettel-test--write "Foo.org" "#+TITLE: Foo\n\n[[file:Target.org][Target]]\n")
    (org-zettel-test--write "Target.org" "#+TITLE: Target\n\n* Backlinks (1)\n\n- [[file:Foo.org][Foo]]\n")
    (with-current-buffer (org-zettel-test--visit "Foo.org")
      (org-zettel-test--replace "#+TITLE: Foo" "#+TITLE: Bar")
      (org-zettel-test--replace "[[file:Target.org][Target]]\n" "")
      (save-buffer))
    (should-not (string-match-p "file:\\(?:Foo\\|Bar\\)\\.org" (org-zettel-test--read "Target.org")))))

(ert-deftest org-zettel-backlink-user-child-section-is-preserved ()
  (org-zettel-test--with-vault
    (org-zettel-test--write "Foo.org" "#+TITLE: Foo\n")
    (org-zettel-test--write "Target.org" "#+TITLE: Target\n* Backlinks (1)\n\n- [[file:Foo.org][Foo]]\n** User notes\n- [[file:Foo.org][User reference]]\n")
    (my/org-remove-backlink (org-zettel-test--file "Target.org") (org-zettel-test--file "Foo.org"))
    (should (string-match-p (regexp-quote "- [[file:Foo.org][User reference]]") (org-zettel-test--read "Target.org")))))

(ert-deftest org-zettel-backlink-removal-retries-after-stale-target-reverted ()
  (org-zettel-test--with-vault
    (org-zettel-test--write "Foo.org" "#+TITLE: Foo\n[[file:Target.org][Target]]\n")
    (org-zettel-test--write "Target.org" "#+TITLE: Target\n* Backlinks (1)\n\n- [[file:Foo.org][Foo]]\n")
    (let ((target (org-zettel-test--visit "Target.org")))
      (org-zettel-test--write "Target.org" "#+TITLE: Target\nExternal edit.\n* Backlinks (1)\n\n- [[file:Foo.org][Foo]]\n")
      (set-file-times (org-zettel-test--file "Target.org") (time-add (current-time) 5))
      (with-current-buffer (org-zettel-test--visit "Foo.org")
        (org-zettel-test--replace "[[file:Target.org][Target]]\n" "")
        (condition-case error (save-buffer) (error (message "Removal save error: %S" error)))
        (with-current-buffer target (revert-buffer t t))
        (set-buffer-modified-p t)
        (save-buffer))
      (should-not (string-match-p (regexp-quote "[[file:Foo.org][Foo]]") (org-zettel-test--read "Target.org"))))))

;;; org-zettel-sync-tests.el ends here
