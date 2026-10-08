;;; org-zettel-link-completion-tests.el --- Real Ivy keyboard tests -*- lexical-binding: t; -*-

;; Run in a disposable terminal Emacs, not the user's daemon:
;; TERM=xterm-256color script -qec \
;;   'emacs -Q -nw -L /path/to/ivy-package \
;;      -l emacs/tests/org-zettel-link-completion-tests.el \
;;      -f org-zettel-link-completion-test-run' /dev/null
;; In batch mode, or without Ivy on load-path, UI tests are skipped.
;; The ordinary org-zettel-sync-tests.el suite remains batch-compatible.

(load (expand-file-name "org-zettel-sync-tests.el"
                        (file-name-directory (or load-file-name buffer-file-name)))
      nil t)
(require 'ivy nil t)

(defun org-zettel-link-ui--type (keys expected)
  "Invoke the real C-c l command with KEYS and expect link EXPECTED.
Use actual minibuffer keyboard events, with fixture-only file access."
  (unless (and (featurep 'ivy) (not noninteractive))
    (ert-skip "Requires Ivy and an interactive terminal Emacs"))
  (org-zettel-test--with-vault
    (let* ((source "#+TITLE: Source\n\n* 概要\n")
           (target "#+TITLE: Alpha existing\n\nExisting content.\n")
           (source-path (org-zettel-test--write "Source.org" source))
           (target-path (org-zettel-test--write "Alpha_existing.org" target))
           (source-before (file-attributes source-path))
           (target-before (file-attributes target-path))
           (completing-read-function #'ivy-completing-read)
           (enable-recursive-minibuffers t)
           (ivy-use-selectable-prompt nil)
           (ivy-index-functions-alist
            (cons '(unrelated-command . ignore) ivy-index-functions-alist))
           (index-functions-before ivy-index-functions-alist))
      (save-window-excursion
        (switch-to-buffer (org-zettel-test--visit "Source.org"))
        (use-local-map (copy-keymap org-mode-map))
        (local-set-key (kbd "C-c l") #'my/org-insert-link)
        (goto-char (point-max))
        (execute-kbd-macro (vconcat (kbd "C-c l") keys))
        (should (equal (buffer-string) (concat source expected)))
        ;; The helper changes completion preferences only during its prompt.
        (should-not ivy-use-selectable-prompt)
        (should (eq ivy-index-functions-alist index-functions-before)))
      (should (equal (org-zettel-test--read "Source.org") source))
      (should (equal (org-zettel-test--read "Alpha_existing.org") target))
      (should (equal (file-attribute-modification-time source-before)
                     (file-attribute-modification-time (file-attributes source-path))))
      (should (equal (file-attribute-modification-time target-before)
                     (file-attribute-modification-time (file-attributes target-path))))
      (should (equal (sort (directory-files org-directory nil "\\.org$") #'string<)
                     '("Alpha_existing.org" "Source.org"))))))

(ert-deftest org-zettel-link-ui-raw-title-wins-over-matching-candidate ()
  (org-zettel-link-ui--type (vconcat "Alpha" (kbd "RET"))
                           "[[file:Alpha.org][Alpha]]"))

(ert-deftest org-zettel-link-ui-exact-existing-filename ()
  (org-zettel-link-ui--type (vconcat "Alpha_existing.org" (kbd "RET"))
                           "[[file:Alpha_existing.org][Alpha existing]]"))

(ert-deftest org-zettel-link-ui-control-n-explicitly-selects-existing-note ()
  (org-zettel-link-ui--type (vconcat "Alpha" (kbd "C-n RET"))
                           "[[file:Alpha_existing.org][Alpha existing]]"))

(ert-deftest org-zettel-link-ui-down-explicitly-selects-existing-note ()
  (org-zettel-link-ui--type (vconcat "Alpha" (kbd "<down> RET"))
                           "[[file:Alpha_existing.org][Alpha existing]]"))

(ert-deftest org-zettel-link-ui-tab-completes-existing-note ()
  (org-zettel-link-ui--type (vconcat "Alpha" (kbd "TAB RET"))
                           "[[file:Alpha_existing.org][Alpha existing]]"))

(ert-deftest org-zettel-link-ui-unmatched-title-with-spaces ()
  (org-zettel-link-ui--type (vconcat "missing topic" (kbd "RET"))
                           "[[file:Missing_topic.org][Missing topic]]"))

(ert-deftest org-zettel-link-ui-new-title-with-org-suffix ()
  (org-zettel-link-ui--type (vconcat "future.org" (kbd "RET"))
                           "[[file:Future.org][Future]]"))

(defun org-zettel-link-completion-test-run ()
  "Run UI tests in a terminal Emacs and exit with the test status."
  (let* ((inhibit-redisplay t)
         (inhibit-message t)
         (stats (ert-run-tests-batch "^org-zettel-link-ui-")))
    (when-let* ((messages (get-buffer "*Messages*")))
      (princ (with-current-buffer messages (buffer-string))
             #'external-debugging-output))
    (kill-emacs (if (zerop (ert-stats-completed-unexpected stats)) 0 1))))

;;; org-zettel-link-completion-tests.el ends here
