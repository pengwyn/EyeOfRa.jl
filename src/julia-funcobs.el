
(require 'widget)
(require 'julia-repl)
(require 's)

;;; Code:

(defvar jfo--field-size 25)
(defvar jfo--buffer-name "*Julia Observing*")


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; * Widgets
;;----------------------------

(defun jfo--setup (mod func args kwds)
  (switch-to-buffer-other-frame jfo--buffer-name)
  (kill-all-local-variables)
  
  (let ((inhibit-read-only t))
    (erase-buffer))
  (remove-overlays)

  (widget-insert "Function observing.\n\n")
  (setq-local jfo--form-mod-name
              (widget-create 'editable-field
                 :size jfo--field-size
                 :format "Module: %v " ; Text after the field!
                 mod))
  (widget-insert "\n")
  (setq-local jfo--form-name
              (widget-create 'editable-field
                 :size jfo--field-size
                 :format "Function name: %v " ; Text after the field!
                 func))
  (widget-insert "\n")

  (widget-insert "\n\n")
  (widget-insert "Argument mode:\n")
  (widget-create 'radio-button-choice
                 :value "Single eval"
                 ;; :notify (lambda (&rest ignore) (jfo--update-evaluation-style))
                 '(item "Single eval")
                 '(item "Multiple eval - zipped.")
                 '(item "Multiple eval - outer product."))
  (widget-insert "\n\n")
  (widget-insert "Arguments:")
  ;; TODO: These args need to have a checkbox (or some other identifying thing) for arg/kwd
  ;; (setq-local jfo--form-args-old
  ;;       (widget-create 'editable-list
  ;;                      :entry-format "%i %d %v"
  ;;                      :value arg-names
  ;;                      '(editable-field :value "")))
  (setq-local jfo--form-args
              (cl-loop for arg in args
                       collect (let ((name (nth 0 arg))
                                     (val (nth 1 arg)))
                                 (widget-insert "\n")
                                 (widget-create 'editable-field
                                                :size jfo--field-size
                                                :format (concat name ": %v")
                                                :name name
                                                :required (not val)
                                                :action #'jfo--field-changed
                                                (or val "")))))
  (widget-insert "\n")
  (widget-create 'push-button
                 :notify (lambda (&rest ignore) (jfo--add-arg))
                 "Add")

  (widget-insert "\n\n")
  (widget-insert "Keywords:")
  (setq-local jfo--form-kwds
              (cl-loop for arg in kwds
                       collect (let ((name (nth 0 arg))
                                     (val (nth 1 arg)))
                                 (widget-insert "\n")
                                 (widget-create 'editable-field
                                                :size jfo--field-size
                                                :format (concat name ": %v")
                                                :name name
                                                :required (not val)
                                                :action #'jfo--field-changed
                                                (or val "")))))
  (widget-insert "\n")
  (widget-create 'push-button
                 :notify (lambda (&rest ignore) (jfo--add-kwd))
                 "Add")

  ;; (widget-create 'editable-field :size 13 :format "arg name: %v "
  ;;                :notify
  ;;                (lambda (widget &rest ignore)
  ;;                  (let ((old (widget-get widget
  ;;                                         ':example-length))
  ;;                        (new (length (widget-value widget))))
  ;;                    (unless (eq old new)
  ;;                      (widget-put widget ':example-length new)
  ;;                      (message "You can count to %d." new))))
  ;;                )
  (widget-insert "\n\n")
  (setq-local jfo--form-show-diffs (widget-create 'checkbox t))
  (widget-insert " Show diffs\n")

  (widget-insert "\n")
  (setq-local jfo--form-submit-button
              (widget-create 'push-button
                             :notify (lambda (&rest ignore) (jfo--run-command))
                             "Start observing"))
  (widget-insert "\n")
  (widget-create 'push-button
                 :notify (lambda (&rest ignore) (jfo--break))
                 "Break observing")
  ;; (widget-insert " ")
  ;; (widget-create 'push-button
  ;;                :notify (lambda (&rest ignore)
  ;;                          (widget-example))
  ;;                "Reset Form")
  (widget-insert "\n")
  (widget-insert "\n")
  (widget-insert "--OUTPUT--\n")
  (widget-insert "\n")
  ;; (use-local-map widget-keymap)
  (widget-setup)
  ;; (goto-char (point-min))
  ;; (search-forward "[Start")
  (goto-char (widget-get jfo--form-submit-button :from))
  )

(defun jfo--running-p ()
  (when (boundp 'jfo--form-submit-button)
    (widget-get jfo--form-submit-button :submitted)))

;; (widget-example "ExampleFunc" '("5" "[1,2,3]" "\"something\"") '(("flip" "true") ("other" ":maybe")))

(defun jfo--add-arg ()
  "Add an extra argument."
  (let* ((last-widget (car (last jfo--form-args)))
         (ind (length jfo--form-args))
         (pos (if last-widget
                  (widget-get last-widget :to)
                (save-excursion
                  (goto-char (point-min))
                  (search-forward "Arguments:")
                  (point)))))
    (goto-char pos)
    (forward-char)
    (let ((w (widget-create 'editable-field
                   :size jfo--field-size
                   :format (concat (format "Arg %d: " ind) "%v")
                   :name (format "Arg %d" ind)
                   :required nil
                   "")))
      (widget-insert "\n")
      (add-to-list 'jfo--form-args w t)
      ;; (remove-overlays)
      (widget-setup)
      )))
  
(defun jfo--get-widget-args ()
  (seq-filter #'identity (mapcar (lambda (w)
            (let ((name (widget-get w :name))
                  (val (string-trim (widget-value w)))
                  (required (widget-get w :required)))
              (if (string-empty-p val)
                (when required (error "Argument '%s' is missing" name))
                val)
              ))
          jfo--form-args)))

(defun jfo--get-widget-kwds ()
  (seq-filter #'identity (mapcar (lambda (w)
            (let ((val (string-trim (widget-value w)))
                  (name (widget-get w :name))
                  (required (widget-get w :required)))
              (if (string-empty-p val)
                (when required (error "Required keyword '%s' is missing" name))
                (concat ":" name "=>" val))))
          jfo--form-kwds)))

(defun jfo--field-changed (&rest ignored)
  (message "Trying to update")
  (when (jfo--running-p)
    (jfo--run-command)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; * Interactives
;;----------------------------

;; These were stolen from julia-mode

(defconst jfo--capturing-function-regex
  (rx-to-string `(: line-start (regexp ,julia-prefixed-macro-list) symbol-start
      "function"
      (1+ space)
      ;; Don't highlight module names in function declarations:
      (* (seq (1+ (or word (syntax symbol))) "."))
      ;; The function name itself
      (group-n 1 (1+ (or word (syntax symbol))))
      ;; The arguments
      ;; Terrible! This won't always work. Need to parse properly.
      ;; "(" (group-n 2
      ;;      (* (or
      ;;         (seq "(" (* (not (any "(" ")"))) ")")
      ;;         (not (any "(" ")")))))
      ;; ")"
      "("
      (group-n 2 (*? (not (any "(" ")"))))
      (optional ";"
                (group-n 3 (* (not (any "(" ")")))))
      ")"
      )))

;; functions of form "f(x) = nothing"
(defconst jfo--capturing-function-assignment-regex
  (rx-to-string `(: line-start (regexp ,julia-prefixed-macro-list) symbol-start
      (* (seq (1+ (or word (syntax symbol))) ".")) ; module name
      (group-n 1 (1+ (or word (syntax symbol))))
      "("
      (group-n 2 (*? (not (any "(" ")"))))
      (optional ";"
                (group-n 3 (* (not (any "(" ")")))))
      ")"
      (* space)
      (? "::" (* space) (1+ (not (any space))))
      (* space)
      (* (seq "where" (or "{" (+ space)) (+ (not (any "=")))))
      "="
      (not (any "=")))))

(defconst jfo--capturing-function-combined-regex
  (concat jfo--capturing-function-regex "\\|"
          jfo--capturing-function-assignment-regex))

(defconst jfo--arg-parse
  (rx (* blank) (group (1+ (or word (syntax symbol)))) (* blank) (optional "=" (* blank) (group (* any)) (* blank))))

(defun julia-function-observe ()
  "Start a function observation.

Tries to identify the current function and arguments."
  (interactive)
  (let* ((orig-pos (point))
         (line (save-excursion
                 (beginning-of-defun)
                 (thing-at-point 'line t)))
         (mod-name (save-excursion
                     (goto-char (point-min))
                     (if (search-forward-regexp (rx line-start "module" (1+ blank) (group (1+ word))) orig-pos t)
                         (match-string-no-properties 1)
                       ;; ":auto"
                       (concat "\"" (buffer-file-name) "\"")
                       )))
         (func-name (if (string-match jfo--capturing-function-combined-regex line)
                        (if (string-prefix-p "\"" mod-name)
                          (match-string-no-properties 1 line)
                          (concat mod-name "." (match-string-no-properties 1 line)))
                      (error "Not at a function start")))
         (args-str (match-string-no-properties 2 line))
         (kwds-str (match-string-no-properties 3 line))
         (args (jfo--parse-args-string args-str))
         (kwds (jfo--parse-args-string kwds-str)))
    (jfo--setup mod-name func-name args kwds)))

(defun jfo--parse-args-string (args-str)
  ;; Need to parse properly, but for now something simple.
  (when args-str
    (mapcar (lambda (arg)
              (if (string-match jfo--arg-parse arg)
                  (list (match-string 1 arg) (match-string 2 arg))
                (error "Shouldn't get here")));;(list arg nil))
            (split-string args-str ","))))




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; * Process stuff
;;----------------------------

(defun jfo--run-command ()
  (with-current-buffer jfo--buffer-name 
    (let ((mod-name (widget-value jfo--form-mod-name))
          (name (widget-value jfo--form-name))
          (args (jfo--get-widget-args))
          (kwds (jfo--get-widget-kwds))
          (show-diffs (widget-value jfo--form-show-diffs)))
      ;; (message "%S" jfo--form-submit-button)
      (let* ((arg-string (concat "[ " (s-join ", " args) " ]"
                                 ", [ " (s-join ", " kwds) " ]"))
             (option-kwds (s-join ", " (cl-loop for (name val) in `(("show_diffs" show-diffs)
                                                                    ("continuing" ,(jfo--running-p)))
                                                  collect (concat name "=" (if val "true" "false"))))))

        ;; Need to hack term-mode's filter
        (advice-remove 'term-emulate-terminal #'jfo--term-filter)
        (advice-add 'term-emulate-terminal :before #'jfo--term-filter)
        ;; TODO: Need to remove this when the terminal stops.

        ;; Cancel an existing run if there is one.
        (when (julia-repl--live-buffer)
          (with-current-buffer (julia-repl--live-buffer)
            (term-interrupt-subjob)))

        ;; Prep the package/file
        (jfo--send-to-repl "using FunctionObserving")
        (when (not (string= mod-name ":auto"))
          (if (string-prefix-p "\"" mod-name)
              ;; This seems to be broken
              (progn (jfo--send-to-repl (concat "Revise.includet("  mod-name ")"))
                     (jfo--send-to-repl (concat "include("  mod-name ")")))
            (jfo--send-to-repl (concat "import " mod-name))))

        (jfo--send-to-repl (concat "FunctionObserving.ObserveFunction(" mod-name ", " name ", " arg-string " ; " option-kwds ")"))
        (widget-put jfo--form-submit-button :submitted t)))

    ;; Change the button name to reflect the new behaviour
    (save-excursion
      (let ((inhibit-read-only t))
        ;; TODO: Replace this with an overlay or go directly from the widget
        (let ((beg (widget-get jfo--form-submit-button :from))
              (end (widget-get jfo--form-submit-button :to)))
          (goto-char beg)
          ;; TODO: shouldn't even need a re-search-forward here...
          (when (re-search-forward "[[]Start observing]" end t)
            (replace-match "[Update]"))
          )))
    ))

;; (jfo--run-command)

(defun jfo--break ()
  (with-current-buffer (julia-repl--live-buffer)
        (advice-remove 'term-emulate-terminal #'jfo--term-filter)
        (term-interrupt-subjob))
  (with-current-buffer jfo--buffer-name 
    (widget-put jfo--form-submit-button :submitted nil)
    (save-excursion
      (let ((inhibit-read-only t)
            (beg (widget-get jfo--form-submit-button :from))
            (end (widget-get jfo--form-submit-button :to)))
        (goto-char beg)
        ;; TODO: shouldn't even need a re-search-forward here...
        (when (re-search-forward "[[]Update]" end t)
          (replace-match "[Start observing]"))
        ))
    ))
(defun jfo--update-text (text &optional append)
  (with-current-buffer jfo--buffer-name
    (save-excursion
    (let ((inhibit-read-only t))
      (unless append
        (goto-char (point-min))
        (search-forward "--OUTPUT--")
        (forward-line)
        (delete-region (point) (point-max))
        )
      (goto-char (point-max))
      ;; (insert text))))
      ;; TODO: This should be replaced with custom font-locking
      ;; The replacement of endlines seems odd here. Just a hack I need?
      (insert (ansi-color-apply (replace-regexp-in-string "\r?\n" "\n" text)))))))
      ;; (insert (ansi-color-apply text)))))
;; (jfo--update-text "asdf\n123123\n" t)
;; (jfo--update-text "asdf\n123123\n" nil)

(defun jfo--term-filter (process str)
  "Hijack term process filter and grab all text output."
  ;; (message str)
  (let* ((ind (string-match "ZCLEARZ" str))
         (append (not ind))
         (text (if ind
                   (substring str (match-end 0))
                 str)))
    (jfo--update-text text append)))

(defun jfo--send-to-repl (command)
  (let ((display-buffer-overriding-action '((display-buffer-no-window) (allow-no-window . t))))
    (julia-repl--send-string command)))




(provide 'julia-funcobs)

;;; julia-funcobs.el ends here
