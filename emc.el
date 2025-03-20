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
;; Version: 2025-03-20
;;
;; Keywords: languages, operating systems, binary platform.


;;; Commentary:
;;
;; Invoking a C/C++ build tool-chain from Emacs.
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
;; | library: .a .so    | library: .a .dylib | library: .obj .dll |
;; +--------------------+--------------------+--------------------+
;;
;; On Windows 'emc' assumes the installation of Microsoft Visual
;; Studio (Community -- provisions are made to handle the Enterprise
;; or other versions but they are untested).  'MSYS' will be added in the
;; future, but is will mostly look like UNIX.
;;
;; All in all, the best way to use this library is to call the `emc:make'
;; function, which invokes the underlying build system (at the time of this
;; writing either 'make' or 'nmake'); e.g., the call:
;;
;; ```
;;    (emc:make)
;; ```
;;
;; calls `compile' after having constructed a platform dependent "make"
;; command.  On MacOS and Linux/UNIX system this defaults to:
;;
;; ```
;;    make -f Makefile
;; ```
;;
;; On Windows with MSVC this defaults to (assuming MSVC is installed on drive
;; ':C')
;;
;; ```
;;    (C:\Path\To\MSVC\...\vcvars64.bat) & nmake /F Makefile
;; ```
;;
;; The 'emc' package gives you several knobs to customize your environment,
;; especially on Windows, where things are more complicated.  Please refer to
;; the `emc:make' function for an initial set of arguments you can use.  E.g.,
;; on Linux/UNIX the call
;;
;; ```
;;    (emc:make :makefile "FooBar.mk" :build-dir "foobar-build")
;; ```
;;
;; will result in a call to "make" such as:
;;
;; ```
;;    cd foobar-build ; make -f Foobar.mk
;; ```
;;
;; as a result `compile' will do the right thing by intercepting the 'cd' in
;; the string.


;;; Code:

(require 'cl-lib)
(require 'compile)


(defgroup emc ()
  "The Emacs Make Compile (EMC) thin layer over the invocation of
  C/C++ and compiler toolchains."
  :group 'tools
  )


(defvar emc:path (file-name-directory (or load-file-name "."))
  "The location EMC is loaded from.")


;; MSVC definitions.
;; -----------------

(defgroup emc-msvc ()
  "Customizations for EMC MS Visual Studio setup."
  :group 'emc
  )


(defcustom emc:*msvc-top-folder*
  "C:\\Program Files\\Microsoft Visual Studio\\2022\\"
  "The Microsoft Visual Studio 2022 Community standard location."
  :group 'emc-msvc
  :type 'directory
  )


(defcustom emc:*msvc-installation* "Community"
  "The type of the MSVC installation."
  :group 'emc-msvc
  :type 'string
  )



(defcustom emc:*msvc-vcvars-bat* "vcvars64.bat"
  "The name of the MSVC batch file used to set up the MSVC environment."
  :group 'emc-msvc
  :type 'string
  )
  

(cl-defun emc:msvc-folder (&optional (msvc-installation "Community"))
  "Return the MSVC main folder.

The parameter MSVC-INSTALLATION defaults to \"Community\", but it can
be changed to, e.g., \"Enterprise\".

The result is a string representing the pathname of the main MSVC
folder, that is `emc::*msvc-top-folder*' contatenated with
MSVC-INSTALLATION."
  (concat emc:*msvc-top-folder* msvc-installation "\\"))


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
     (build-dir default-directory bd-p)
     (makefile "Makefile" makefile-p)
     (make-macros "" make-macros-p)
     (nologo t)
     (targets "")
     &allow-other-keys)
  "Return the \\='nmake\\=' command (a string) to execute.

The \\='nmake\\=' command is prepended by the necessary MSVC
setup done by `emc:msc-vcvarsall-cmd'.  The variables :INSTALLATION (keyword variable MSVC-INSTALLATION) and
:VCVARS-BAT (keyword variable MSVC-VCVARS-BAT) are passed to
`emc:msc-vcvarsall-cmd'; MAKE-MACROS is a string containing
MACRO=DEF definitions; NOLOGO specifies whether or not to pass
the \\='/NOLOGO\\=' flag to \\='nmake\\='; finally TARGETS is a
string of makefile targets.  Finally, BUILD-DIR contains the folder
where \\='nmake\\=' will be run."

  (concat (if bd-p (concat "cd " build-dir " & ") "") ; Cf., `compile'.

	  "("
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
			     (build-dir default-directory bd-p)
                             (makefile "Makefile" makefile-p)
                             (make-macros "" make-macros-p)
                             (targets "")
                             &allow-other-keys)
  "Return the \\='make\\=' command (a string) to execute.

MAKEFILE is the \\='Makefile\\=' to pass to \\='make\\=' via the
\\='-f\\=' flag; MAKE-MACROS is a string containing \\='MACRO=DEF\\='
definitions; TARGETS is a string of Makefile targets.  BUILD-DIR is
the folder where \\='make\\=' will be invoked."

  (concat (if bd-p (concat "cd " build-dir " ; ") "")
	  "make "
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

(defcustom emc:*max-line-length* 80
  "The maximum compilation line length used by `compile'.

See Also:

`compilation-max-output-line-length'"
  :group 'emc
  :type 'natnum
  )


(defun emc::platform-type ()
  "Return the current \\='platform-type\\='.

The possible values are \\='darwin\\=' (for Mac OS),
\\='windows-nt\\=', \\='unix\\=', or NIL for an unusable (for the time
being) platoform type.

See Also:

`system-type'."
  (cl-case system-type
    (darwin
     'darwin)
    (windows-nt
     'windows-nt)
    ((gnu
      gnu/linux
      gnu/kfreebsd
      cygwin

      ;; Old, Emacs 26 specs: see `system-type'.
      aix
      berkeley-unix
      hpux
      usg-unix-v)
     'generic-unix)
    (otherwise
     nil)))


(cl-defgeneric emc:start-making (sys build-system &rest keys
				     &key
				     &allow-other-keys)
  "Invoke the BUILD-SYSTEM on platform SYS.

The variable KEYS contains extra parameters."
  
  ;; 'flycheck-mode' needs to do some work.
  ;;
  ;; (:documentation
  ;;  "Invoke the BUILD-SYSTEM on platform SYS; KEYS contains extra parameters.")
  )


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


(cl-defun emc:make (&rest keys
                          &key
                          (makefile "Makefile")
                          (make-macros "")
                          (targets "")
			  (wait nil)
			  (build-system :make)
			  (build-dir default-directory)
                          &allow-other-keys)
  "Call a \\='make\\=' program in a platform dependend way.

KEYS contains the keyword arguments passed to the specialized
`emc:X-make-cmd' functions via `emc:start-making'; MAKEFILE is the name
of the makefile to use (defaults to \"Makefile\"); MAKE-MACROS is a
string containing \\='MACRO=DEF\\=' definitions; TARGETS is a string of
Makefile targets.  WAIT is a boolean telling `emc:make' whether to wait
or not for the compilation process termination.  BUILD-SYSTEM specifies
what type of tool is used to build result; the default is \\=':make\\='
which works of the different known platforms using \\='make\\=' or
\\='nmake\\='; another experimental value is \\=':cmake\\=' which
invokes a \\='CMake\\' build pipeline with some assumptions (not yet
working).  Finally, BUILD-DIR is the directory (folder) where the build
system will be invoked."

  ;; Some preventive basic error checking.
  
  (unless (file-exists-p build-dir)
    (error "EMC: error: non-existing build directory %S" build-dir))

  (unless (file-exists-p (concat (file-name-as-directory build-dir) makefile))
    (error "EMC: error: no %S in build directory %S" makefile build-dir))


  ;; Here we go.

  (message "EMC: making with:")
  (message "EMC: makefile:    %S" makefile)
  (message "EMC: make-macros: %S" make-macros)
  (message "EMC: targets:     %S" targets)
  (message "EMC: making...")

  ;; (cl-case system-type
  ;;   (windows-nt
  ;;    (cl-case build-system
  ;;      (:make (emc::invoke-make (apply #'emc:msvc-make-cmd keys)))
  ;;      (t (error "EMC: build system %s cannot be used (yet)"
  ;; 		 build-system))
  ;;      ))
  ;;   (darwin
  ;;    (cl-case build-system
  ;;      (:make (emc::invoke-make (apply #'emc:macos-make-cmd keys)))
  ;;      (t (error "EMC: build system %s cannot be used (yet)"
  ;; 		 build-system))
  ;;      ))
  ;;   (otherwise                          ; Generic UNIX/Linux.
  ;;    (cl-case build-system
  ;;      (:make (emc::invoke-make (apply #'emc:unix-make-cmd keys)))
  ;;      (t (error "EMC: build system %s cannot be used (yet)"
  ;; 		 build-system))
  ;;      ))
  ;;   )

  (apply #'emc:start-making (emc::platform-type) build-system keys)

  (when wait
    (message "EMC: waiting...")
    (while (memq emc::*compilation-process* compilation-in-progress)
      ;; Spin loop.
      (sit-for 1.0))
    (message "EMC: done."))
  )



;; make/nmake `emc:start-making' methods.

(cl-defmethod emc:start-making ((sys t) (build-system t)
				&rest keys
				&key
				&allow-other-keys)
  "Raise an error.

This is a catch-all method that gets Invoked when a generic/unknown
SYS and BUILD-SYSTEM pair is passed to the generic function.   KEYS is
ignored."
  (ignore keys)
  (error "EMC: build system %s cannot be used (yet) on %s"
	 build-system
	 sys)
  )


(cl-defmethod emc:start-making ((sys (eql 'windows-nt))
				(build-system (eql :make))
				&rest keys
				&key
				&allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='windows-nt\\=' and
BUILD-SYSTEM equal to \\=':make\\=' is invoked with KEYS."
  (ignore sys build-system)
  (emc::invoke-make (apply #'emc:msvc-make-cmd keys))
  )


(cl-defmethod emc:start-making ((sys (eql 'darwin))
				(build-system (eql :make))
				&rest keys
				&key
				&allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='darwin\\=' and
BUILD-SYSTEM equal to \\=':make\\=' is invoked with KEYS."
  (ignore sys build-system)
  (emc::invoke-make (apply #'emc:macos-make-cmd keys))
  )


(cl-defmethod emc:start-making ((sys (eql 'generic-unix))
				(build-system (eql :make))
				&rest keys
				&key
				&allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='generic-unix\\=' and
BUILD-SYSTEM equal to \\=':make\\=' is invoked with KEYS."
  (ignore sys build-system)
  (emc::invoke-make (apply #'emc:unix-make-cmd keys))
  )


;; CMake `emc:start-making' methods.


  
;;; Epilogue.

(provide 'emc '(make))

;;; emc.el ends here
