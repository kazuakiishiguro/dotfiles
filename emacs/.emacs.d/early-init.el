;;; early-init.el --- Emacs early startup config -*- lexical-binding: t; -*-
;;; Commentary:

;; Initialize packages explicitly in init.el after setting their archives.

;;; Code:

(setq package-enable-at-startup nil)

;; Elpy's snippet helper omits Python/Yasnippet declarations.  It works when
;; loaded in Python buffers, but its standalone JIT compile produces warnings.
;; Keep that tiny helper byte-compiled/interpreted across Emacs versions.
(dolist (compiler-feature '(comp comp-run))
  (eval-after-load compiler-feature
    '(when (boundp 'native-comp-jit-compilation-deny-list)
       (add-to-list
        'native-comp-jit-compilation-deny-list
        "/elpy\\(?:-[^/]+\\)?/snippets/python-mode/\\.yas-setup\\.el\\'"))))

;;; early-init.el ends here
