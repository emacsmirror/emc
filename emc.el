;;; -*- Mode: Emacs-Lisp; lexical-binding: t; -*-
;;; emc --- Invoking a C/C++ build toolchain from Emacs

;;; emc.el
;;;
;;; See the file COPYING in the top directory for copyright and
;;; licensing information.

;; Author: Marco Antoniotti <marcoxa [at] gmail.com>
;; Maintainer: Marco Antoniotti <marcoxa [at] gmail.com>
;;
;; Summary: Invoking a C/C++ build toolchain from Emacs.
;;
;; Created: 2025-01-02
;; Version: 2025-01-20
;;
;; Keywords: languages, operating systems, binary platform.


;;; Commentary:
;;
;; Invoking a C/C++ build toolchain from Emacs.
;;
;; The standard 'compile' machinery is mostly designed for interactive
;; use, but nowadays, for C/C++ at least, build systems and different
;; platforms make the process a bit complicated.
;;
;; The goal of this library is to hide some of these details for Unix
;; (Linux), Mac OS and Windows.
;;
;; The combinations supported are
;; +--------------------+--------------------+--------------------+
;; |                    |                    |                    |
;; | Unix/Linux         | Mac OS             | Windows (10/11)    |
;; |                    |                    |                    |
;; +--------------------+--------------------+--------------------+
;; | make               | make               | nmake              |
;; | executable         | executable         | executable: .exe   |
;; | library: .a .so    | lobrary: .a .dylib | library: .obj .dll |
;; +--------------------+--------------------+--------------------+
;;
;; On Windows 'emc' assumes the installation of Microsoft Visual
;; Studio (Community -- provisions are made to handle the Enterprise
;; or other versions but they are untested).


;;; Code:

(require 'cl-lib)
(require 'compile)


(defvar emc:path (file-name-directory (or load-file-name "."))
  "The location EMC is loaded from.")


(defun emc::emacs-version ()
  "Return the Emacs version as \"MM.mm\".

It depends on command `emacs-version'."
  (let* ((emv (emacs-version))
	 (em-maj-min-match
	  (string-match "GNU Emacs \\([0-9]+\\).\\([0-9]+\\)" emv))
	 )
    (if em-maj-min-match
	(concat (match-string 1 emv)
		"."
		(match-string 2 emv))
      (error "EMC: cannot determine Emacs Major.minor version")
      )))


;; MSVC definitions.
;; -----------------

(defvar emc::*msvc-top-folder*
  "C:\\Program Files\\Microsoft Visual Studio\\2022\\"
  "The Microsoft Visual Studio 2022 Community standard location."
  )


(defvar emc:*msvc-installation* "Community"
  "The type of the MSVC installation.")


(defvar emc:*msvc-vcvars-bat* "vcvars64.bat"
  "The name of the MSVC batch file used to set up the MSVC environment.")
  

(cl-defun emc:msvc-folder (&optional (msvc-installation "Community"))
  "Return the MSVC main folder.

The parameter MSVC-INSTALLATION defaults to \"Community\", but it can
be changed to, e.g., \"Enterprise\".

The result is a string representing the pathname of the main MSVC
folder, that is `emc::*msvc-top-folder*' contatenated with
MSVC-INSTALLATION."
  (concat emc::*msvc-top-folder* msvc-installation "\\"))


(cl-defun emc:msvc-vcvarsall-cmd (&optional
                                  (msvc-installation "Community")
                                  (msvc-vcvarsall-bat "vcvars64.bat")
                                  )
  "Return the command to be used to set up the MSVC environment.

The variable MSVC-INSTALLATION defaults to \"Community\", while the
variable MSVC-VCVARSALL-BAT defaults to \"vcvars64.bat\".

See Also:

https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line

The web link is from 2025-01-03.  It may need some tweaking."
  (concat (emc:msvc-folder msvc-installation)
          "VC\\Auxiliary\\Build\\"
          msvc-vcvarsall-bat))


(cl-defun emc:msvc-make-cmd
    (&key
     ((:installation msvc-installation) "Community")
     ((:vcvars-bat msvc-vcvarsall-bat) "vcvars64.bat")
     (makefile "Makefile" makefile-p)
     (make-macros "" make-macros-p)
     (nologo t)
     (targets "")
     &allow-other-keys)
  "Return the \\='nmake\\=' command (a string) to execute.

The \\='nmake\\=' command is prepended by the necessary MSVC
setup done by `emc:msc-vcvarsall-cmd'.  The variables
:INSTALLATION (keyword variable MSVC-INSTALLATION) and
:VCVARS-BAT (keyword variable MSVC-VCVARS-BAT) are passed to
`emc:msc-vcvarsall-cmd'; MAKE-MACROS is a string containing
MACRO=DEF definitions; NOLOGO specifies whether or not to pass
the \\='/NOLOGO\\=' flag to \\='nmake\\='; finally TARGETS is a
string of makefile targets."

  (concat "("
          (shell-quote-argument
           (emc:msvc-vcvarsall-cmd msvc-installation msvc-vcvarsall-bat))
          " > nul )"  ; To suppress the logo from 'msvc-vcvarsall-bat'.
          " & "
          "nmake "
          (when nologo "/NOLOGO ")
          (when makefile-p (format "/F %s " (shell-quote-argument makefile)))
          (when make-macros-p (concat (shell-quote-argument make-macros) " "))
          targets)
  )


;; UNIX/Linux definitions.
;; -----------------------

(cl-defun emc:unix-make-cmd (&key
                             (makefile "Makefile" makefile-p)
                             (make-macros "" make-macros-p)
                             (targets "")
                             &allow-other-keys)
  "Return the \\='make\\=' command (a string) to execute.

MAKEFILE is the \\='Makefile\\=' to pass to \\='make\\=' via the
\\='-f\\=' flag; MAKE-MACROS is a string containing 'MACRO=DEF'
definitions; TARGETS is a string of Makefile targets."

  (concat "make "
          (when makefile-p (format "-f %s " (shell-quote-argument makefile)))
          (when make-macros-p (concat (shell-quote-argument make-macros) " "))
          targets)
  )


;; Mac OS definitions.
;; -------------------

(cl-defun emc:macos-make-cmd (&rest keys &key &allow-other-keys)
  "Return the \\='make\\=' command (a string) to execute.

MAKEFILE is the \\='Makefile\\=' to pass to \\='make\\=' via the
\\='-f\\=' flag; MAKE-MACROS is a string containing
\\='MACRO=DEF\\=' definitions; TARGETS is a string of Makefile
targets.

This function is essentially an alias for `emc:unix-make-cmd'.
The variable KEYS collects the arguments to pass to the latter
function."
  (apply #'emc:unix-make-cmd keys)
  )


;; Generic API exported functions.
;; -------------------------------
;;
;; I reuse the 'compile.el' machinery.

(defvar emc:*max-line-length* 80
  "The maximum compilatio line length used by `compile'.

See Also:

`compilation-max-output-line-length'")


(defvar emc::*compilation-process* nil
  "The \\='emc\\=' last compilation process.

The processe is  initiated by \\=`compile\\=' and recorded my \\='emc\\='.")


(cl-defun emc::compile-finish-fn (cur-buffer msg)
  "Function to be added as a hook tp `compilation-finish-functions'.

The arguments are the current buffer CUR-BUFFER and MSG, the messsage
that is built by the \\='compile\\=' machinery.

Notes:

For the time being, the function is a simple wrapper to add the
\"EMC\" prefix to the message."
  (message (format "EMC: %S %S" (buffer-name cur-buffer) msg)))


(defun emc::compilation-buffer-name (name-of-mode)
  "The function used as value for `compilation-buffer-name-function'.

The variable NAME-OF-MODE is used to build the buffer name."

  ;; This is a hack.  It is just a tiny variation of
  ;; `compilation--default-buffer-name', since the logic in
  ;; \\='compile.el\\=' dealing with the compilation buffer names is
  ;; ... not linear.
  
  (cond ((or (eq major-mode (intern-soft name-of-mode))
             (eq major-mode (intern-soft (concat name-of-mode "-mode"))))
	 (buffer-name))
	(t
	 (concat "*EMC " (downcase name-of-mode) "*"))))
   

(cl-defun emc::invoke-make (make-cmd &optional (max-ll emc:*max-line-length*))
  "Call the MAKE-CMD using `compile'.

The optional MAX-LL argument is used to set the compilation buffer
maximum line length."
  (let ((compilation-max-output-line-length max-ll)
	(compilation-buffer-name-function #'emc::compilation-buffer-name)
	)
    (prog1 (compile make-cmd)

      ;; Let's hope no intervening `compile' was issued in the
      ;; meanwhile.

      (setf emc::*compilation-process* (cl-first compilation-in-progress))
      )))


;; (cl-defun emc::invoke-make (make-cmd)
;;   "Call the MAKE-CMD in an inferior shell process."

;;   (with-temp-buffer
;;     (let ((cwd ".")
;;           (exit-code
;;            (call-process-shell-command make-cmd nil t))
;;           )
;;       (ignore cwd)
;;       (if (zerop exit-code)
;;           (message "EMC: making succesfull.")
;;         ;; The rest is somewhat lifted from 'emacs-libq'.
;;         (let ((result-msg (buffer-string)))
;;           (if noninteractive
;;               (message "EMC: making failed:\n%s\n" result-msg)
;;             (with-current-buffer
;;                 (get-buffer-create "*emc-make*")
;;               (let ((inhibit-read-only t))
;;                 (erase-buffer)
;;                 (insert result-msg))
;;               (compilation-mode)
;;               (pop-to-buffer (current-buffer))
;;               (error "EMC: making failed"))
;;             ))
;;         ))
;;     ))


(cl-defun emc:make (&rest keys
                          &key
                          (makefile "Makefile")
                          (make-macros "")
                          (targets "")
			  (wait nil)
			  (build-system :make)
                          &allow-other-keys)
  "Call a \\='make\\=' program in a platform dependend way.

KEYS contains the keyword arguments passed to the specialized
`emc:X-make-cmd' functions; MAKEFILE is the name of the makefile
to use (defaults to \"Makefile\"); MAKE-MACROS is a string
containing \\='MACRO=DEF\\=' definitions; TARGETS is a string of
Makefile targets.  WAIT is a boolean telling `emc:make' whether to
wait or not for the compilation process termination.  BUILD-SYSTEM
specifies what type of tool is used to build result; the default is
\\=':make\\=' which works of the different known platforms using
\\='make\\=' or \\='nmake\\='; another experimental value is
\\=':cmake\\=' which invokes a \\='CMake\\' build pipeline with some
assumptions (not yet working)."

  ;; This function needs rewriting.

  (message "EMC: making with:")
  (message "EMC: makefile:    %S" makefile)
  (message "EMC: make-macros: %S" make-macros)
  (message "EMC: targets:     %S" targets)
  (message "EMC: making...")

  (cl-case system-type
    (windows-nt
     (cl-case build-system
       (:make (emc::invoke-make (apply #'emc:msvc-make-cmd keys)))
       (t (error "EMC: build system %s cannot be used (yet)"
		 build-system))
       ))
    (darwin
     (cl-case build-system
       (:make (emc::invoke-make (apply #'emc:macos-make-cmd keys)))
       (t (error "EMC: build system %s cannot be used (yet)"
		 build-system))
       ))
    (otherwise                          ; Generic UNIX/Linux.
     (cl-case build-system
       (:make (emc::invoke-make (apply #'emc:unix-make-cmd keys)))
       (t (error "EMC: build system %s cannot be used (yet)"
		 build-system))
       ))
    )

  (when wait
    (message "EMC: waiting...")
    (while (memq emc::*compilation-process*  compilation-in-progress)
      ;; Spin loop.
      (sit-for 1.0))
    (message "EMC: done."))
  )


;;; Epilogue.

(provide 'emc '(make))

;;; emc.el ends here
