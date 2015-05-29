;; Ex-mode interface for `helm-recentf' and `helm-projectile-recentf'. If
;; `bang', then `search' is interpreted as regexp
(evil-define-command my:helm-recentf (&optional bang)
  :repeat nil
  (interactive "<!>")
  (if bang (helm-recentf) (helm-projectile-recentf)))

(use-package projectile
  :commands (projectile-ack
             projectile-ag
             projectile-compile-project
             projectile-dired
             projectile-grep
             projectile-find-dir
             projectile-find-file
             projectile-find-tag
             projectile-find-test-file
             projectile-invalidate-cache
             projectile-kill-buffers
             projectile-multi-occur
             projectile-project-root
             projectile-recentf
             projectile-regenerate-tags
             projectile-replace
             projectile-run-async-shell-command-in-root
             projectile-run-shell-command-in-root
             projectile-switch-project
             projectile-switch-to-buffer
             projectile-vc
             projectile-project-p
             helm-projectile-find-file
             helm-projectile-recentf
             helm-projectile-find-other-file
             helm-projectile-switch-project)
  :diminish projectile-mode
  :config
  (progn
    (setq-default projectile-enable-caching t)
    (setq projectile-sort-order 'recentf
          projectile-cache-file (concat my-tmp-dir "projectile.cache")
          projectile-known-projects-file (concat my-tmp-dir "projectile.projects")
          projectile-indexing-method 'alien
          projectile-project-root-files project-root-files)
    (add-to-list 'projectile-globally-ignored-files "ido.last")
    (add-to-list 'projectile-globally-ignored-directories "assets")
    (add-to-list 'projectile-other-file-alist '("scss" "css"))
    (add-to-list 'projectile-other-file-alist '("css" "scss"))

    (use-package helm-projectile)
    (projectile-global-mode +1)

    ;; Don't show the project name in the prompts; I already know.
    (defun projectile-prepend-project-name (string) helm-global-prompt)))

(use-package helm
  :commands (helm
             helm-M-x
             helm-buffers-list
             helm-semantic-or-imenu
             helm-etags-select
             helm-apropos
             helm-show-kill-ring
             helm-bookmarks
             helm-wg)
  :init
  (evil-set-initial-state 'helm-mode 'emacs)
  :config
  (progn ; helm settings
    (defvar helm-global-prompt ">>> ")
    (setq helm-quick-update t
          helm-idle-delay 0.01
          helm-input-idle-delay 0.01
          helm-reuse-last-window-split-state t
          helm-buffers-fuzzy-matching nil
          helm-candidate-number-limit 40
          helm-bookmark-show-location t)

    (after "winner"
      ;; Tell winner-mode to ignore helm buffers
      (dolist (bufname '("*helm recentf*"
                         "*helm projectile*"
                         "*helm imenu*"
                         "*helm company*"
                         "*helm buffers*"
                         ;; "*helm tags*"
                         "*helm-ag*"
                         "*Helm Swoop*"))
        (push bufname winner-boring-buffers)))

    (my--cleanup-buffers-add "^\\*[Hh]elm.*\\*$")

    (progn ; helm hacks
      ;; No persistent header
      (defadvice helm-display-mode-line (after undisplay-header activate)
        (setq header-line-format nil))

      ;; Hide the mode-line in helm (<3 minimalism)
      (defun helm-display-mode-line (source &optional force)
        (set (make-local-variable 'helm-mode-line-string)
             (helm-interpret-value (or (and (listp source) ; Check if source is empty.
                                            (assoc-default 'mode-line source))
                                       (default-value 'helm-mode-line-string))
                                   source))
        (let ((follow (and (eq (cdr (assq 'follow source)) 1) "(HF) ")))
          (if helm-mode-line-string
              (setq mode-line-format nil)
            (setq mode-line-format (default-value 'mode-line-format)))
          (let* ((hlstr (helm-interpret-value
                         (and (listp source)
                              (assoc-default 'header-line source))
                         source))
                 (hlend (make-string (max 0 (- (window-width) (length hlstr))) ? )))
            (setq header-line-format
                  (propertize (concat " " hlstr hlend) 'face 'helm-header))))
        (when force (force-mode-line-update))))

    (bind helm-map
          "C-w"        'evil-delete-backward-word
          "C-u"        'helm-delete-minibuffer-contents
          "C-r"        'evil-ex-paste-from-register ; Evil registers in helm! Glorious!
          [escape]     'helm-keyboard-quit)))

(use-package helm-files
  :commands (helm-recentf)
  :config
  (progn
    ;; Reconfigured `helm-recentf' to use `helm', instead of `helm-other-buffer'
    (defun helm-recentf ()
      (interactive)
      (let ((helm-ff-transformer-show-only-basename nil))
        (helm :sources '(helm-source-recentf)
              :buffer "*helm recentf*"
              :prompt helm-global-prompt)))))

(use-package helm-ag
  :commands (helm-ag
             my:helm-ag-search
             my:helm-ag-regex-search
             my:helm-ag-search-cwd
             my:helm-ag-regex-search-cwd)
  :config
  (progn
    ;; Ex-mode interface for `helm-ag'. If `bang', then `search' is interpreted as
    ;; regexp.
    (evil-define-operator my:helm-ag-search (beg end &optional search hidden-files-p pwd-p regex-p)
      :type inclusive
      :repeat nil
      (interactive "<r><a><!>")
      (let* ((helm-ag-default-directory (if pwd-p default-directory (project-root)))
             (helm-ag-command-option (concat (unless regex-p "-Q ") (if hidden-files-p "--hidden ")))
             (input "")
             (header-name (format "Search in %s" helm-ag-default-directory)))
        (if search
            (progn
              (helm-attrset 'search-this-file nil helm-ag-source)
              (setq helm-ag--last-query search))
          (if (and beg end (/= beg (1- end)))
              (setq input (buffer-substring-no-properties beg end))))
        (helm-attrset 'name header-name helm-ag-source)
        (helm :sources (if search (helm-ag--select-source) '(helm-source-do-ag))
              :buffer "*helm-ag*"
              :input input
              :prompt helm-global-prompt)))

    (evil-define-operator my:helm-ag-regex-search (beg end &optional search bang)
      :type inclusive :repeat nil
      (interactive "<r><a><!>")
      (my:helm-ag-search beg end search bang nil t))
    (evil-define-operator my:helm-ag-search-cwd (beg end &optional search bang)
      ;; Ex-mode interface for `helm-do-ag'. If `bang', then `search' is interpreted
      ;; as regexp
      :type inclusive :repeat nil
      (interactive "<r><a><!>")
      (my:helm-ag-search beg end search bang t nil))
    (evil-define-operator my:helm-ag-regex-search-cwd (beg end &optional search bang)
      :type inclusive :repeat nil
      (interactive "<r><a><!>")
      (my:helm-ag-search beg end search bang t t))))

(use-package helm-company :defer t)

(use-package helm-css-scss ; https://github.com/ShingoFukuyama/helm-css-scss
      :commands (helm-css-scss
                 helm-css-scss-multi
                 helm-css-scss-insert-close-comment))

(use-package helm-swoop    ; https://github.com/ShingoFukuyama/helm-swoop
  :commands (helm-swoop helm-multi-swoop my:helm-swoop)
  :config
  (progn
    (setq helm-swoop-use-line-number-face t
          helm-swoop-split-with-multiple-windows t
          helm-swoop-speed-or-color t)

    ;; Ex-mode interface for `helm-swoop', `helm-multi-swoop-all' (if `bang'), or
    ;; `helm-css-scss' and `helm-css-scss-multi' (if `bang') if major-mode is
    ;; `scss-mode'
    (evil-define-command my:helm-swoop (&optional search bang)
      :repeat nil
      (interactive "<a><!>")
      (if (eq major-mode 'scss-mode)
          (if bang (helm-css-scss-multi search) (helm-css-scss search))
        (if bang (helm-multi-swoop-all search) (helm-swoop :$query search))))))

(provide 'init-helm)
;;; init-helm.el ends here
