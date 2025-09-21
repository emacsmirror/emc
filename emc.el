;;; emc.el --- Invoking a C/C++ (et al.) build toolchain from ELisp -*- Mode: Emacs-Lisp; lexical-binding: t; -*-
;;;
;;; See the file COPYING in the top directory for copyright and
;;; licensing information.

;; Author: Marco Antoniotti <marcoxa [at] gmail.com>
;; Maintainer: Marco Antoniotti <marcoxa [at] gmail.com>
;; SPDX-License-Identifier: MIT
;; Package-Requires: ((delight "1.7") (emacs "29.1"))
;; Keywords: extensions, c, lisp, building tools, development, deployment.
;; URL: https://github.com/marcoxa/emc
;;
;; Summary: Invoking a C/C++ (and other) build toolchain from Emacs.
;;
;; Created: 2025-01-02
;; Timestamp: 2025-09-21
;; Version: 0.42


;;; Commentary:
;;
;; Invoking a C/C++ (and other) build tool-chain from Emacs.
;;
;; The standard 'compile' machinery is mostly designed for interactive
;; use, but nowadays, for C/C++ at least, build systems and different
;; platforms make the process a bit more complicated.
;; Moreover, it is often desirable to have a slightly higher level API
;; to programmatically invoke a build system.
;;
;; The goal of this library is to hide some of these details for Unix
;; (Linux), Mac OS and Windows.  The 'emc' library interfaces to
;; 'make' and 'nmake' building setup and to 'cmake' (www.cmake.org).
;;
;; The supported 'Makefile' combinations are:
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
;; There are three main `emc' commands: `emc-run', `emc-make', and
;;`emc-cmake'.  `emc-run' is the most generic command and allows to
;; select the build system.  `emc-make' and `emc-cmake' assume instead
;; 'make' or 'nmake' and 'cmake' respectively.
;;
;; Invoking the command `emc-run' will use the
;; `emc-*default-build-system*' (defaulting to `:make') on the current
;; platform supplying hopefully reasonable defaults.  E.g.,
;; ```
;;    (emc-run)
;; ```
;; will usually result in a call to
;; ```
;;    make -f Makefile
;; ```
;; on UN*X platoforms.
;;
;;
;; ### 'make'
;;
;; All in all, the easiest way to use this library is to call the `emc-make'
;; function, which invokes the underlying build system (at the time of this
;; writing either 'make' or 'nmake'); e.g., the call:
;;
;; ```
;;    (emc-make)
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
;; the `emc-make' function for an initial set of arguments you can use.  E.g.,
;; on Linux/UNIX the call
;;
;; ```
;;    (emc-make :makefile "FooBar.mk" :build-dir "foobar-build")
;; ```
;;
;; will result in a call to "make" such as:
;;
;; ```
;;    cd foobar-build ; make -f Foobar.mk
;; ```
;;
;; as a result `compile' will do the right thing by intercepting the 'cd' in
;; the string (the directory name is actually fully expanded by EMC).
;;
;;
;; ### 'cmake'
;;
;; To invoke 'cmake' the relevant function is `emc-cmake' which takes
;; the following "subcommands" (the '<bindir>' below is to be
;; interpreted in the 'cmake' sense).
;; 1. `setup': which is equivalent to 'cmake <srcdir>' issued in a
;;    `binary' directory.
;; 2. `build': which is equivalent to 'cmake --build <bindir>'.
;; 3. `install': which is equivalent to 'cmake --install <bindir>'.
;; 4. `uninstall': which currently has no `cmake' equivalent.
;; 5. `clean': equivalent to 'cmake --build <bindir> -t clean'.
;; 5. `fresh': equivalent to 'cmake --fresh <bindir>'.
;;
;; As for `emc-make`, you can invoke the `emc-cmake` command either as
;; `M-x emc-make` or `C-u M-x emc-cmake`.  In the first case **EMC** will
;; assume that most parameters are already set; in the second case,
;; **EMC** will ask for each parameter needed by the sub-command.
;;
;;
;; ### Other Commands
;;
;; You can use the `emc-run` command which will ask you which
;; *sub-command* to use.  Again, if you prefix it with `C-u`, it will ask
;; you for several other variables, including the choice of *build
;; system* (which, for the time being, is either `make`, or `cmake`).
;;
;; Other commands (and functions) you can use correspond to `cmake' sub
;; commands.
;;
;; 1. `emc-setup`: which is equivalent to `cmake <srcdir>` issued in a
;;    `binary` directory and to a `make setup` issued in the appropriate
;;    directory as well.  Note that this command usually does not mean
;;    much in a `make` based setup, unless the `Makefile` contains a
;;    `setup` target.
;; 2. `emc-build`: which is equivalent to `cmake --build <bindir>` and to
;;    `make` issued in `<bindir>`; note that `make` will execute the
;;    recipe associated to the first target.
;; 3. `emc-install`: which is equivalent to `cmake --install <bindir>`
;;    and to `make install` issued in `<bindir>`; note that `make` must
;;    provide the `install` target.
;; 4. `emc-uninstall`: which currently has no `cmake` equivalent.  To execute
;;    this command with `cmake`, `CMakeLists.txt` must make provisions to
;;    handle and generate the `uninstall` targets.
;; 5. `emc-clean`: equivalent to `cmake --build <bindir> -t clean`,  and to
;;    `make clean` issued in `<bindir>`; note that `make` must provide
;;    the `clean` target.
;; 5. `emc-fresh`: equivalent to `cmake --fresh <bindir>`, and to `make
;;    fresh`.  Note that this command usually does not mean much in a
;;    `make` based setup, unless the `Makefile` contains a `setup`
;;    target.
;;
;;
;; #### **EMC** *GUI*
;;
;; **EMC** also has a simple user interface that uses Emacs `widget`
;; library.  It may simplify setting up the build system commands,
;; especially because it shows the command before executing it.
;;
;; You can invoke the GUI by invoking the `emc-emc` Emacs command
;; (`M-x emc-emc`).  Using it should be rather straightforward.


;;; Code:

(require 'cl-lib)
(require 'compile)
(require 'dired)
(require 'delight)			; Only non built-in dependency.


(defgroup emc ()
  "The Emacs Make Compile (EMC).

EMC is thin layer over the invocation of C/C++ and compiler
toolchains."
  :group 'tools
  )


(defcustom emc-*logging* nil
  "The EMC flag used to control messaging."
  :group 'emc
  :type 'symbol
  :options '(t info debug error warn nil)
  :local t
  )


;; emc-msg
;; I will switch to 'log4e' sooner or later.

(defun emc--msg (fmt &rest args)
  "Call `message' or issues an `error' or a `warn'ing.

The behavior is controlled by the value of the variable
`emc-*logging*'.  FMT is a `format' string  and ARGS are the
arguments for `format'."
  
  (when emc-*logging*
    (let* ((msg-prefix
	    (cl-case emc-*logging*
	      ((info t) "EMC INFO: ")
	      (debug "EMC DEBUG: ")
	      (error "EMC DEBUG: ")
	      (warn "EMC DEBUG: ")
	      ))
	   (msg-fmt (concat msg-prefix fmt))
	   )
      (cl-case emc-*logging*
	(error (apply #'error msg-fmt args))
	(warn (apply #'warn msg-fmt args))
	(otherwise (apply #'message msg-fmt args))))))


(cl-deftype emc-build-system-type ()
  "The known EMC build-systems."
  '(member make cmake)			; Used to have :make :cmake.
  )


(defun emc--normalize-build-system (build-system)
  "Normalize BUILD-SYSTEM to its keyword form."

  ;; This is a bit too rigid and it will become useless.
  
  (cond ((or (eq build-system 'make)
	     (eq build-system :make)
	     (and (stringp build-system)
		  (or (string-equal-ignore-case build-system ":make")
		      (string-equal-ignore-case build-system "make"))))
	 'make)
	((or (eq build-system 'cmake)
	     (eq build-system :cmake)
	     (and (stringp build-system)
		  (or (string-equal-ignore-case build-system ":cmake")
		      (string-equal-ignore-case build-system "cmake"))))
	 'cmake)
	(t
	 (error "EMC: error: unknown build system %S" build-system))
	))


;; The following functions are needed because I shuffle back and forth
;; between strings and symbols.  (And because ELisp does not seem to
;; do coercion as CL STRING.

(defun emc--normalize-to-symbol (x)
  "Ensure that the X argument is rendered as a symbol."

  ;; The `cl-typecase' could be made tighter by referring to
  ;; `emc-build-system-type'.
  
  (cl-etypecase x
    (symbol x)
    (string (intern x))
    ))


(defun emc--normalize-to-string (x)
  "Ensure that the X argument is rendered as a symbol."

  ;; The `cl-typecase' could be made tighter by referring to
  ;; `emc-build-system-type'.
  
  (cl-etypecase x
    (symbol (symbol-name x))
    (string x)
    ))


(defconst emc-+path+ (file-name-directory (or load-file-name "."))
  "The location EMC is loaded from.")


(defcustom emc-*default-build-system* nil
  "The EMC default build system.

When EMC is called interactively this variable will be locally set in
the buffer."
  :group 'emc
  :type 'symbol
  :options '(make cmake)
  :local t
  )


;; API exported functions and variables.
;; -------------------------------------
;;
;; I reuse the 'compile.el' machinery.

(defcustom emc-*max-line-length* 72
  "The maximum compilation line length used by `compile'.

See Also:

`compilation-max-output-line-length'"
  :group 'emc
  :type 'natnum
  )


(defcustom emc-*verbose* nil
  "If non NIL show messages about EMC progress."
  :group 'emc
  :type 'sexp
  )


(defun emc--platform-type ()
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


(defcustom emc-*emacs-include-dir*
  (cl-case (emc--platform-type)
    (darwin
     "/Applications/Emacs.app/Contents/Resources/include")
    
    (windows-nt
     (concat
      "C:\\Program Files\\Emacs\\"
      "emacs-"
      emacs-version
      "\\include\\"))
    
    (generic-unix
     (concat
      "/usr/local/share/emacs/"
      "emacs-"
      emacs-version
      "/include/"))
    )
  "Guessing the Emacs \\='include\\=' dir to handle \\='dynamic modules\\='.
Unfortunately, Emacs Lisp does not expose a \\='include-dir\\='
variable; which it should."
  :group 'emc
  :type 'string
  )


;; Support for special `interactive' calls.
;; ----------------------------------------
;;
;; Note the trick of passing 'keywords' that must
;; interactively "read"; unfortunately the keyword plist must be
;; manually reconstructed within the `interactive' call.
;;
;; Bottom line: `interactive' and `cl-defun' mix well only in simple
;; cases.

(cl-defun emc--read-command-parms
    (&optional prefix-argument
	       (build-system emc-*default-build-system*)
	       (parms-to-be-read ())
	       defaults)
  "Read the common command parameters from minibuffer.

PREFIX-ARGUMENT is possibly bound to PREFIX-ARG.  BUILD-SYSTEM is the
current build-system; it cannot be NIL here.  PARMS-TO-BE-READ
contains a list of standard-parameters to be read interactively; if
empty (i.e., NIL) all parameters are read interactively.  DEFAULTS is
a keyword p-list (passed down from \\='&rest keys\\=' parameters by
callers."

  (cl-assert build-system)
  
  (let ((read-answer-short nil)		; Force long answers.
	)
    (cl-macrolet ((read-parm (parm &body reader)
		    `(if (or (null parms-to-be-read)
			     (memq ',parm parms-to-be-read))
			 ,@reader
		       (cl-getf defaults ',parm)
		       ))
		  )
      
      (if prefix-argument
	  (let* ((makefile
		  (read-parm :makefile
			     (progn
			       (emc--msg "1")
			       (when (or (eq build-system 'make)
					 (and (stringp build-system)
					      (string-equal build-system
							    "make")))
				 (emc--msg "2")
				 (read-file-name "Makefile: "
						 nil
						 "Makefile"
						 t))))
		  )
		 (source-dir
		  (read-parm :source-dir
			     (expand-file-name
			      (read-directory-name
			       "Source directory: "))))
		 (build-dir
		  (read-parm :build-dir
			     (expand-file-name
			      (read-directory-name
			       "Build directory: "))))
		 (install-dir
		  (read-parm :install-dir
			     (expand-file-name
			      (read-directory-name
			       "Install directory: "))))
		 (macros
		  (read-parm :make-macros
			     (read-string "Macros: " nil nil "")))
		 (targets
		  (read-parm :targets
			     (read-string "Targets: " nil nil "")))
		 )
	    (append (and source-dir (list :source-dir source-dir))
		    (and build-dir (list :build-dir build-dir))
		    (and install-dir (list :install-dir install-dir))
		    (and macros (list :make-macros macros))
		    (and targets (list :targets targets))
		    (and makefile (list :makefile makefile))
		    ;; (and current-prefix-arg (list :prefix current-prefix-arg))
		    ))
	
	;; Default is no prefix arg was given.
	
	(list :source-dir default-directory
	      :build-dir default-directory
	      :install-dir default-directory
	      :make-macros ""
	      :targets ""
	      :makefile "Makefile"
	      ;; :prefix current-prefix-arg
	      ))
      )					; macrolet
    ))


;;; Reading EMC parameters from minibuffer.
;;; ---------------------------------------
;;;
;;; Single purpose reader functions.

(cl-defun emc--read-cmd (&rest args)
  "Read the EMC \\='command\\=' from the minibuffer.

ARGS is ignored.
Returns a symbol."
  (ignore args)
  (let ((read-answer-short nil))	; Force long answers.
    (intern
     (read-answer "Command: "
		  '(("setup" ?s "setup the project")
		    ("build" ?b "build the project")
		    ("install" ?i "install the project")
		    ("uninstall" ?u "uninstall the project")
		    ("fresh" ?f "freshen the project")
		    ("clean" ?c "clean the project")
		    )))
    ))


(cl-defun emc--read-build-system (&rest args)
  "Read the EMC \\='command\\=' from the minibuffer.

ARGS is ignored.
Returns a symbol."
  (ignore args)
  (let ((read-answer-short nil))	; Force long answers.
    (intern
     (read-answer "Build with: "
		  '(("make" ?m "use 'make'.")
		    ("cmake" ?c "use 'cmake'.")
		    )))
    ))


(cl-defun emc--read-directory (prompt &key (directory default-directory)
				      &allow-other-keys)
  "Read an EMC \\='directory\\=' from the minibuffer.

PROMPT is used to ask what directory should be read in.  DIRECTORY is
passed as defaults to `read-directory'.

Returns a directory."
  (read-directory-name prompt directory nil directory))


(cl-defun emc--read-makefile-name (&key (directory default-directory)
					(use-system-dialog nil))
  "Read the name of a proper \\='Makefile\\='.

DIRECTORY is passed as default DIR to `read-file-name'  If
USE-SYSTEM-DIALOG is T, then a dialog box is used to select the
\\='Makefile\\=' (cf., `use-dialog-box'; default is NIL).

Returns a directory."
  (let ((use-dialog-box use-system-dialog))
    (when use-dialog-box
      (let ((emc-*logging* t))
	(emc--msg "find a 'Makefile' in %s" directory)))
    (read-file-name "Makefile: " directory "Makefile" t "Makefile")))


(cl-defun emc--read-string (prompt &rest args)
  "Read a \\='string\\=' from the minibuffer.

PROMPT is passed to `read-string'.  ARGS is ignored.
Returns a string."
  (ignore args)
  (read-string prompt))


;;; emc--read-ensure-build-system

(cl-defun emc--read-ensure-build-system (&optional build-system)
  "Ensure that a \\='build system\\=' has been chosen.

The optional argument BUILD-SYSTEM can be one of the known build
systems.  The buffer local variable `emc-*default-build-system' will
be set to a known build system after this function is run.  If both
BUILD-SYSTEM and `emc-*default-build-system*' are NIL, then a new
build system must be entered via `emc-read-build-system'.

See Also:

`emc-read-build-system', `emc-read-build-system'."

  (cond ((and emc-*default-build-system* build-system)
	 (display-warning 'emc
			  (format-message
			   "changing default build system from %s to %s."
			   emc-*default-build-system*
			   build-system))
	 (setq-local emc-*default-build-system* build-system))
	(build-system
	 (setq-local emc-*default-build-system* build-system))
	(emc-*default-build-system*)
	(t
	 (setq-local emc-*default-build-system* (emc--read-build-system)))
	))


;;; emc--read-emc-command
;;; ---------------------

(cl-defun emc--read-emc-command (&optional prefix-argument
					   (parms-to-be-read ())
					   defaults)
  "Read the common build system parameters from minibuffer.

PREFIX-ARGUMENT is possibly bound to CURRENT-PREFIX-ARG.
PARMS-TO-BE-READ contains a list of standard-parameters to be
interactively read; if empty (i.e., NIL) all parameters are read
interactively.  DEFAULTS is a keyword p-list (passed down from \\='&rest
keys\\=' parameters by callers.

The function returns an argument list \\='(cmd . keys-plist)\\='.  It
may locally set `emc-*default-build-system*' if not set yet."

  (let* ((build-system (emc--read-ensure-build-system))
	 (cmd (emc--read-cmd))
	 (parms (emc--read-command-parms prefix-argument
					 build-system
					 parms-to-be-read
					 defaults))
	 )

    (when emc-*verbose*
      (let ((emc-*logging* t))
	(emc--msg "read build parms from minibuffer (%S %S)."
		  prefix-arg
		  prefix-argument)))

    (cl-list* cmd :build-system build-system parms)
    ))


;;; cmake common definitions.
;;; -------------------------

(defun emc--select-cmake-cmd (command)
  "Select a proper \\='cmake\\=' COMMAND line switch."

  ;; The selectors used to be just keywords.
  
  (cl-ecase (emc--normalize-command command)
    (setup
     ;; Nothing really in this case.  This is called to create the
     ;; \\='cmake\\=' makefiles from the \\='CMakeLists.txt\\='
     ;; specifications.
     "")
    ((build :build) "--build")
    ((install :install)  "--install")
    ((uninstall :uninstall)
     ;; Come back to fix this.
     "--uninstall")
    ((clean :clean)
     ;; Come back to fix this.
     "--clean")
    ((fresh :fresh)
     ;; Come back to fix this.
     "--fresh")
    ))


(defun emc--cmake-cmd (kwd sd bd id)
  "Return the proper \\='cmake\\=' command.

KWD is one of `emc--commands' in keyword form.  SD, BD, and ID are the
source, binary and installation directories that must be used in the
\\='cmake\\=' commands."

  ;; The selectors used to be just keywords.
  
  (cl-ecase kwd
    ((setup :setup) (concat "cmake " sd))
    ((build :build) (concat "cmake --build " bd))
    ((install :install) (concat "cmake --install " id))
    ((uninstall :uninstall)
     ;; Come back to fix this.
     (concat "cmake --uninstall"))
    ((clean :clean)
     ;; Come back to fix this.
     (concat "cmake --build " bd " -t clean"))
    ((fresh :fresh)
     ;; Come back to fix this.
     (concat "cmake --fresh " bd))
    ))


;; MSVC definitions.
;; -----------------

(defgroup emc-msvc ()
  "Customizations for EMC MS Visual Studio setup."
  :group 'emc
  )


(defcustom emc-*msvc-top-folder*
  "C:\\Program Files\\Microsoft Visual Studio\\2022\\"
  "The Microsoft Visual Studio 2022 Community standard location."
  :group 'emc-msvc
  :type 'directory
  )


(defcustom emc-*msvc-installation* "Community"
  "The type of the MSVC installation."
  :group 'emc-msvc
  :type 'string
  )



(defcustom emc-*msvc-vcvars-bat* "vcvars64.bat"
  "The name of the MSVC batch file used to set up the MSVC environment."
  :group 'emc-msvc
  :type 'string
  )


(cl-defun emc-msvc-folder (&optional (msvc-installation "Community"))
  "Return the MSVC main folder.

The parameter MSVC-INSTALLATION defaults to \"Community\", but it can
be changed to, e.g., \"Enterprise\".

The result is a string representing the pathname of the main MSVC
folder, that is `emc--*msvc-top-folder*' contatenated with
MSVC-INSTALLATION."
  (concat emc-*msvc-top-folder* msvc-installation "\\"))


(cl-defun emc-msvc-vcvarsall-cmd (&optional
                                  (msvc-installation "Community")
                                  (msvc-vcvarsall-bat "vcvars64.bat")
                                  )
  "Return the command to be used to set up the MSVC environment.

The variable MSVC-INSTALLATION defaults to \"Community\", while the
variable MSVC-VCVARSALL-BAT defaults to \"vcvars64.bat\".

See Also:

https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line

The web link is from 2025-01-03.  It may need some tweaking."
  (concat (emc-msvc-folder msvc-installation)
          "VC\\Auxiliary\\Build\\"
          msvc-vcvarsall-bat))


(cl-defun emc-msvc-make-cmd
    (&key
     ((:installation msvc-installation) "Community")
     ((:vcvars-bat msvc-vcvarsall-bat) "vcvars64.bat")
     (build-dir default-directory bd-p)
     (makefile "Makefile" makefile-p)
     (make-macros "" make-macros-p)
     (nologo t)
     (targets "")
     ;; (dry-run nil)
     &allow-other-keys)
  "Return the \\='nmake\\=' command (a string) to execute.

The \\='nmake\\=' command is prepended by the necessary MSVC setup done
by `emc-msc-vcvarsall-cmd'.  The variables :INSTALLATION (keyword
variable MSVC-INSTALLATION) and :VCVARS-BAT (keyword variable
MSVC-VCVARS-BAT) are passed to `emc-msc-vcvarsall-cmd'; MAKE-MACROS is a
string containing MACRO=DEF definitions; NOLOGO specifies whether or not
to pass the \\='/NOLOGO\\=' flag to \\='nmake\\='; finally TARGETS is a
string of makefile targets.  Finally, BUILD-DIR contains the folder
where \\='nmake\\=' will be run.  DRY-RUN runs the \\='nmake\\=' command
without executing it."

  (concat (if bd-p (concat "cd " build-dir " & ") "") ; Cf., `compile'.

	  "( "
          (shell-quote-argument
           (emc-msvc-vcvarsall-cmd msvc-installation msvc-vcvarsall-bat))
          " > nul )"  ; To suppress the logo from 'msvc-vcvarsall-bat'.
          " & "
          "nmake "
          (when nologo "/NOLOGO ")
          (when makefile-p (format "/F %s " (shell-quote-argument makefile)))
          (when make-macros-p (concat (shell-quote-argument make-macros) " "))
	  ;; (when dry-run "-n ")
          targets)
  )


(cl-defun emc-msvc-cmake-cmd
    (&key
     (command 'build)			; Used to be :build.
     ((:installation msvc-installation) "Community")
     ((:vcvars-bat msvc-vcvarsall-bat) "vcvars64.bat")
     (build-dir default-directory bd-p)
     (source-dir default-directory sd-p)
     (install-dir default-directory id-p)
     ;; (makefile "Makefile" makefile-p)
     ;; (make-macros "" make-macros-p)
     ;; (nologo t)
     (targets "")
     (dry-run nil)
     &allow-other-keys)
  "Return the \\='cmake\\=' command (a string) to execute.

The \\='cmake\\=' command is prepended by the necessary MSVC setup done
by `emc-msc-vcvarsall-cmd'.  The variables :INSTALLATION (keyword
variable MSVC-INSTALLATION) and :VCVARS-BAT (keyword variable
MSVC-VCVARS-BAT) are passed to `emc-msc-vcvarsall-cmd'..  COMMAND is the
\\='cmake\\=' selector for the top level switch.  TARGETS is a string of
Makefile targets.  BUILD-DIR is the folder where \\='cmake\\=' will
build the project.  SOURCE-DIR is the folder where the project folder
resides.  INSTALL-DIR is used for the \\=':install\\=' command.  DRY-RUN
runs the \\='cmake\\=' command without executing it."

  (let* ((sd (if sd-p (shell-quote-argument source-dir) source-dir))
	 (bd (if bd-p (shell-quote-argument build-dir) build-dir))
	 (id (if id-p (shell-quote-argument install-dir) install-dir))
	 (targets-list (string-split targets nil t " "))
	 (cmd-kwd (emc--normalize-command command))
	 )
    (concat (if bd-p (concat "cd " build-dir " & ") "")
	    "( "
            (shell-quote-argument
             (emc-msvc-vcvarsall-cmd msvc-installation msvc-vcvarsall-bat))
            " > nul )" ; To suppress the logo from 'msvc-vcvarsall-bat'.
            " & "
	    (emc--cmake-cmd cmd-kwd sd bd id)
	    (when dry-run " -N ")
	    (mapconcat #'(lambda (s) (concat " -t " s))
		       targets-list)
	    )
    ))


;; UNIX/Linux definitions.
;; -----------------------

(cl-defun emc-unix-make-cmd (&key
			     (build-dir default-directory bd-p)
                             (makefile "Makefile" makefile-p)
                             (make-macros "" make-macros-p)
                             (targets "")
			     (dry-run nil)
                             &allow-other-keys)
  "Return the \\='make\\=' command (a string) to execute.

MAKEFILE is the \\='Makefile\\=' to pass to \\='make\\=' via the
\\='-f\\=' flag; MAKE-MACROS is a string containing \\='MACRO=DEF\\='
definitions; TARGETS is a string of Makefile targets.  BUILD-DIR is the
folder where \\='make\\=' will be invoked.  DRY-RUN runs the
\\='cmake\\=' command without executing it."

  (concat (if bd-p (concat "cd " build-dir " ; ") "")
	  "make "
          (when (and makefile-p (not (string-empty-p makefile)))
	    ;; (format "-f %s " (shell-quote-argument makefile))
	    (format "-f %s " makefile))
          (when (and make-macros-p (not (string-empty-p make-macros)))
	    (concat (shell-quote-argument make-macros) " "))
	  (when dry-run "-n ")
          targets)
  )


(cl-defun emc-unix-cmake-cmd (&key
			      (command 'build) ; Used to be :build.
			      (source-dir default-directory sd-p)
			      (build-dir default-directory bd-p)
			      (install-dir default-directory id-p)
                              (targets "")
			      (dry-run nil)
                              &allow-other-keys)
  "Return the \\='cmake\\=' command (a string) to execute.

COMMAND is the \\='cmake\\=' selector for the top level switch.  TARGETS
is a string of Makefile targets.  BUILD-DIR is the folder where
\\='cmake\\=' will build the project.  SOURCE-DIR is the folder where
the project folder resides.  INSTALL-DIR is used for the
\\=':install\\=' command DRY-RUN runs the \\='cmake\\=' command without
executing it..

Examples:

    (emc--unix-cmake-cmd :command :build :build-dir \".\")

yields

\"cmake --build .\""

  (let* ((sd (if sd-p (shell-quote-argument source-dir) source-dir))
	 (bd (if bd-p (shell-quote-argument build-dir) build-dir))
	 (id (if id-p (shell-quote-argument install-dir) install-dir))
	 (targets-list (string-split targets nil t " "))
	 (cmd-kwd (emc--normalize-command command))
	 )
    
    (concat (emc--cmake-cmd cmd-kwd sd bd id)
	    (when dry-run " -N ")
	    (mapconcat #'(lambda (s) (concat " -t " s))
		       targets-list)
	    )
    ))


;; Mac OS definitions.
;; -------------------

(cl-defun emc-macos-make-cmd (&rest keys &key &allow-other-keys)
  "Return the \\='make\\=' command (a string) to execute.

MAKEFILE is the \\='Makefile\\=' to pass to \\='make\\=' via the
\\='-f\\=' flag; MAKE-MACROS is a string containing
\\='MACRO=DEF\\=' definitions; TARGETS is a string of Makefile
targets.

This function is essentially an alias for `emc-unix-make-cmd'.
The variable KEYS collects the arguments to pass to the latter
function."
  (apply #'emc-unix-make-cmd keys)
  )


(cl-defun emc-macos-cmake-cmd (&rest keys &key &allow-other-keys)
  "Return the \\='cmake\\=' command (a string) to execute.

KEYS collects all the keywords that are used by the underlying
dispathc machinery.

COMMAND is the \\='cmake\\=' selector for the top level switch.
TARGETS is a string of Makefile targets.  BUILD-DIR is the folder where
\\='cmake\\=' will build the project.  SOURCE-DIR is the folder where
the project folder resides.  INSTALL-DIR is used for the
\\=':install\\=' command.

Examples:

    (emc--unix-cmake-cmd :command :build :build-dir \".\")

yields

\"cmake --build .\"

Notes:

This is just a wrapper for `emc-unix-cmake-cmd'."
  (apply #'emc-unix-cmake-cmd keys)
  )


;; emc--commands
;; Unused FTTB.

(cl-deftype emc--commands ()
  "The recognized EMC commands.

The commands are the \\='typical\\=' one for a build tool."
  '(member
    :setup setup			; Mostly for CMake.
    :build build
    :install install
    :uninstall uninstall
    :clean clean
    :fresh fresh			; Mosty for CMake.
    ))


(defun emc--normalize-command (command)
  "Return the \\='keyword\\=' form of COMMAND."
  (cond ((or (eq command 'setup)
	     (eq command :setup)
	     (and (stringp command)
		  (string-equal-ignore-case command "setup")))
	 'setup)
	
	((or (eq command 'build)
	     (eq command :build)
	     (and (stringp command)
		  (string-equal-ignore-case command "build")))
	 'build)

	((or (eq command 'install)
	     (eq command :install)
	     (and (stringp command)
		  (string-equal-ignore-case command "install")))
	 'install)

	((or (eq command 'uninstall)
	     (eq command :uninstall)
	     (and (stringp command)
		  (string-equal-ignore-case command "uninstall")))
	 'uninstall)
	
	((or (eq command 'clean)
	     (eq command :clean)
	     (and (stringp command)
		  (string-equal-ignore-case command "clean")))
	 'clean)

	((or (eq command 'fresh)
	     (eq command :fresh)
	     (and (stringp command)
		  (string-equal-ignore-case command "fresh")))
	 'fresh)
	))


(cl-defgeneric emc-craft-command (sys build-system
				      &rest keys
				      &key
				      &allow-other-keys)
  "Craft (shape, build, evoke) the actual command to be executed.

SYS is the platform (cf., `system'), BUILD-SYSTEM is the tool and KEYS
contains the extra parameters needed."
  ;; `flycheck-mode' needs to get its act together.
  )


(cl-defgeneric emc-start-making (sys build-system &rest keys
				     &key
				     &allow-other-keys)
  "Invoke the BUILD-SYSTEM on platform SYS.

The variable KEYS contains extra parameters."
  
  ;; 'flycheck-mode' needs to do some work.
  ;;
  ;; (:documentation
  ;;  "Invoke the BUILD-SYSTEM on platform SYS; KEYS contains extra parameters.")
  )


(defvar emc--*compilation-process* nil
  "The \\='emc\\=' last compilation process.

The processe is  initiated by \\=`compile\\=' and recorded my
\\='emc\\='.")


(cl-defun emc--compile-finish-fn (cur-buffer msg)
  "Function to be added as a hook tp `compilation-finish-functions'.

The arguments are the current buffer CUR-BUFFER and MSG, the messsage
that is built by the \\='compile\\=' machinery.

Notes:

For the time being, the function is a simple wrapper to add the
\"EMC\" prefix to the message."
  (let ((emc-*logging* t))
    (emc--msg "%S %S" (buffer-name cur-buffer) msg)))


(defun emc--compilation-buffer-name (name-of-mode)
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


(cl-defun emc--invoke-make (make-cmd &optional
				     (max-ll emc-*max-line-length*)
				     (verbose emc-*verbose*)
				     )
  "Call the MAKE-CMD using `compile'.

The optional MAX-LL argument is used to set the compilation buffer
maximum line length.  VERBOSE controls whether the function prints out
progress messages."
  (let ((compilation-max-output-line-length max-ll)
	(compilation-buffer-name-function #'emc--compilation-buffer-name)
	)

    (when verbose
      (let ((emc-*logging* t))
	(emc--msg "invoking %S" make-cmd)))
    
    (prog1 (compile make-cmd)

      ;; Let's hope no intervening `compile' was issued in the
      ;; meanwhile.

      (setf emc--*compilation-process* (cl-first compilation-in-progress))
      )))


;; make and make `emc-start-making' methods.
;; -----------------------------------------

(cl-defun emc-make (&rest keys
                          &key
                          (makefile "Makefile")
                          (make-macros "")
                          (targets "")
			  (dry-run nil)
			  (wait nil)
			  (build-system emc-*default-build-system*)
			  (build-dir default-directory)
			  (source-dir default-directory)
			  (install-dir default-directory)
			  
                          &allow-other-keys)
  "Call a \\='make\\=' program in a platform dependend way.

KEYS contains the keyword arguments passed to the specialized
`emc-X-make-cmd' functions via `emc-start-making'; MAKEFILE is the name
of the makefile to use (defaults to \"Makefile\"); MAKE-MACROS is a
string containing \\='MACRO=DEF\\=' definitions; TARGETS is a string of
Makefile targets.  WAIT is a boolean telling `emc-make' whether to wait
or not for the compilation process termination.  BUILD-SYSTEM specifies
what type of tool is used to build result; the default is \\=':make\\='
which works on the different known platforms using \\='make\\=' or
\\='nmake\\='; another experimental value is \\=':cmake\\=' which
invokes a \\='CMake\\=' build pipeline with some assumptions (not yet
working).  BUILD-DIR is the directory (folder) where the build
system will be invoked. DRY-RUN runs the \\='cmake\\=' command without
executing it."

  (interactive
   (cl-list* :build-system 'make
	     (emc--read-command-parms current-prefix-arg
				      'make
				      '(:makefile
					:source-dir
					:build-dir
					:install-dir
					:make-macros
					:dry-run
					:targets)
				      (list :makefile "Makefile"
					    :make-macros ""
					    :targets ""
					    :build-dir default-directory
					    :source-dir default-directory
					    :install-dir default-directory
					    :dry-run nil
					    ))))

  ;; This may be removed.
  
  (cl-assert (or (eq build-system 'make) (eq build-system :make))
	     t
	     "build system is '%s', but it should be 'make'")

  ;; Ensure we have a proper Makefile.
  (emc--msg "emc-make: %s" keys)
  (emc--msg "emc-make: interactively %s %s"
	    (called-interactively-p 'any)
	    current-prefix-arg)
  
  (when (and (called-interactively-p 'any) (null current-prefix-arg))
    ;; The function was called interactively but without the "full"
    ;; reading of keyword parameters.
    
    (unless (or (file-exists-p makefile)
		(file-exists-p
		 (expand-file-name (file-name-nondirectory makefile)
				   build-dir)))
      (setf makefile
	    (emc--read-makefile-name)
	    ;; (read-file-name "Makefile: " nil "Makefile" t "Makefile")
	    )
      ))

  ;; End interactive handling.

  (ignore dry-run source-dir install-dir)

  ;; Some preventive basic error checking.

  (unless (file-directory-p build-dir)
    (error "EMC: error: non-existing build directory %S" build-dir))

  ;; This is a check useful for non-interactive calls.
  
  (unless (or (file-exists-p makefile)
	      (file-exists-p
	       (expand-file-name (file-name-nondirectory makefile)
				 build-dir)))

    (error (concat "EMC: error: no %S in build directory %S"
		   "\nEMC: error: try calling the command with a prefix,"
		   "\nEMC: error: or rhe function with different arguments"
		   )
	   makefile
	   build-dir))


  ;; Here we go.

  (let ((emc-*logging* t))
    (emc--msg "making with:")
    (emc--msg "makefile:    %S" makefile)
    (emc--msg "make-macros: %S" make-macros)
    (emc--msg "targets:     %S" targets)
    (emc--msg "keys:        %S" keys)
    (emc--msg "making...")

    (apply #'emc-start-making (emc--platform-type) build-system
	   :makefile makefile		; Ensure we have the right
					; makefile.
	   keys)

    (when wait
      (emc--msg "waiting...")
      (while (memq emc--*compilation-process* compilation-in-progress)
	;; Spin loop.
	(sit-for 1.0))
      (emc--msg "done."))
    ))


;; make/nmake `emc-craft-command' methods.

(cl-defmethod emc-craft-command ((sys t) (build-system t)
				 &rest keys
				 &key
				 &allow-other-keys)
  "Raise and error.

This is a catch-all method that gets Invoked when a generic/unknown
SYS and BUILD-SYSTEM pair is passed to the generic function.   KEYS is
ignored."

  (ignore keys)
  (error "EMC: build system %S cannot be used (yet) on %S"
	 build-system
	 sys)
  )


(defun emc--craft-make-targets (command targets)
  "Craft the final set of targets for a \\='make\\=' call.

COMMAND is the EMC command indicator (a symbol) and TARGETS is the
initial target list (actually a space separated string)."
  
  (let ((cmd-target (if (eq command 'build)
			"" 		; Maybe it should be "all".
		      (emc--normalize-to-string command)))
	)
    (cond ((and (not (eq command 'build))
		(string-search cmd-target targets))
	   targets)
	  ((eq command 'build)
	   targets)
	  (t
	   (concat cmd-target " " targets))))
  )


(cl-defmethod emc-craft-command ((sys (eql 'windows-nt))
				 (build-system (eql 'make))
				 &rest keys
				 &key
				 (command 'build)
				 (targets "")
				 &allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='windows-nt\\=' and
BUILD-SYSTEM equal to \\='make\\=' is invoked with KEYS.  COMMAND is the
actual EMC command indicator (a symbol).  TARGETS is the initial target
list (actually a space separated string)."
  
  (ignore sys build-system)
  (let ((tgts (emc--craft-make-targets command targets)))
    
    ;; (emc--msg "craft-command: MSVC nmake: %S %S" command tgts)
    (cl-remf keys :targets)
    ;; (emc--msg "craft-command: %S" keys)
    (apply #'emc-msvc-make-cmd :targets tgts keys)
    ))


(cl-defmethod emc-craft-command ((sys (eql 'darwin))
				 (build-system (eql 'make))
				 &rest keys
				 &key
				 (command 'build)
				 (targets "")
				 &allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='windows-nt\\=' and
BUILD-SYSTEM equal to \\='make\\=' is invoked with KEYS.  COMMAND is the
actual EMC command indicator (a symbol).  TARGETS is the initial target
list (actually a space separated string)."
  
  (ignore sys build-system)

  (let ((tgts (emc--craft-make-targets command targets)))
    
    ;; (emc--msg "craft-command: MacOS make: %S %S" command tgts)
    (cl-remf keys :targets)
    ;; (emc--msg "craft-command: %S" keys)
    (apply #'emc-unix-make-cmd :targets tgts keys)
    ))


(cl-defmethod emc-craft-command ((sys (eql 'generic-unix))
				 (build-system (eql 'make))
				 &rest keys
				 &key
				 (command 'build)
				 (targets "")
				 &allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='windows-nt\\=' and
BUILD-SYSTEM equal to \\=':make\\=' is invoked with KEYS.  COMMAND is
the \\='subcommand\\=' (ignored by \\='make\\=') and TARGETS are the
targets to pass down."
  
  (ignore sys build-system)

  (let ((tgts (emc--craft-make-targets command targets)))

    ;; (emc--msg "craft-command: UNX make: %S %S" command tgts)
    (cl-remf keys :targets)
    ;; (emc--msg "craft-command: %S" keys)
    (apply #'emc-unix-make-cmd :targets tgts keys)
    ))


;; make/nmake `emc-start-making' methods.

(cl-defmethod emc-start-making ((sys t) (build-system t)
				&rest keys
				&key
				&allow-other-keys)
  "Raise and error.

This is a catch-all method that gets Invoked when a generic/unknown
SYS and BUILD-SYSTEM pair is passed to the generic function.   KEYS is
ignored."

  (ignore keys)
  (error "EMC: build system %S cannot be used (yet) on %S"
	 build-system
	 sys)
  )

(cl-defmethod emc-start-making ((sys (eql 'windows-nt))
				(build-system (eql 'make))
				&rest keys
				&key
				&allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='windows-nt\\=' and
BUILD-SYSTEM equal to \\=':make\\=' is invoked with KEYS."
  (ignore sys build-system)
  (emc--invoke-make (apply #'emc-msvc-make-cmd keys))
  )


(cl-defmethod emc-start-making ((sys (eql 'darwin))
				(build-system (eql 'make))
				&rest keys
				&key
				&allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='darwin\\=' and
BUILD-SYSTEM equal to \\=':make\\=' is invoked with KEYS."
  (ignore sys build-system)
  (emc--invoke-make (apply #'emc-macos-make-cmd keys))
  )


(cl-defmethod emc-start-making ((sys (eql 'generic-unix))
				(build-system (eql 'make))
				&rest keys
				&key
				&allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='generic-unix\\=' and
BUILD-SYSTEM equal to \\=':make\\=' is invoked with KEYS."
  (ignore sys build-system)
  (emc--invoke-make (apply #'emc-unix-make-cmd keys))
  )


;; CMake and CMake `emc-start-making' methods.
;; -------------------------------------------

(cl-defun emc-cmake (cmd &rest keys
                         &key
                         (make-macros "")
                         (targets "")
			 (dry-run nil)
			 (wait nil)
			 (source-dir default-directory)
			 (build-dir default-directory)
			 (install-dir default-directory)
                         &allow-other-keys)
  "Call \\='cmake\\=' in a platform dependend way.

CMD is the \\='cmake\\=' subcommand to invoke (e.g., \\='build\\=' or
\\='install\\=').  KEYS contains the keyword arguments passed to the
specialized `emc-X-cmake-cmd' functions via `emc-start-making';
MAKE-MACROS is a string containing \\='MACRO=DEF\\=' definitions;
TARGETS is a string of Makefile targets.  WAIT is a boolean telling
`emc-cmake' whether to wait or not for the compilation process
termination.  Finally, SOURCE-DIR is the directory (folder) where the
project resides, while BUILD-DIR is the directory (folder) where the
build system will be invoked.  DRY-RUN runs the \\='cmake\\=' command
without executing it."

  (interactive
   (cl-list* (emc--read-cmd)
	     :build-system 'cmake
	     (emc--read-command-parms current-prefix-arg
				      'cmake
				      '(:source-dir
					:build-dir
					:install-dir
					:make-macros
					:dry-run
					:targets)
				      (list :make-macros ""
					    :targets ""
					    :build-dir default-directory
					    :source-dir default-directory
					    :install-dir default-directory
					    :dry-run nil
					    )))
   )
  
  (ignore dry-run)
  
  ;; Some preventive basic error checking.
  
  (unless (file-directory-p source-dir)
    (error "EMC: error: non-existing source directory %S" source-dir))
  (unless (file-directory-p build-dir)
    (error "EMC: error: non-existing build directory %S" build-dir))
  (unless (file-directory-p install-dir)
    (error "EMC: error: non-existing install directory %S" build-dir))

  (unless (file-exists-p (expand-file-name "CMakeLists.txt" source-dir))
    (error "EMC: error: no 'CMakeLists.txt' file found in\n     %s" source-dir)
    )

  
  ;; Here we go.

  (let ((emc-*logging* t))
    (emc--msg "running 'cmake' command %S" cmd)
    (emc--msg "source-dir:  %S" source-dir)
    (emc--msg "build-dir:   %S" build-dir)
    (emc--msg "install-dir: %S" install-dir)
    (emc--msg "make-macros: %S" make-macros)
    (emc--msg "targets:     %S" targets)
    (emc--msg "making...")

    (apply #'emc-start-making (emc--platform-type) 'cmake :command cmd keys)

    (when wait
      (emc--msg "waiting...")
      (while (memq emc--*compilation-process* compilation-in-progress)
	;; Spin loop.
	(sit-for 1.0))
      (emc--msg "done."))
    ))


(cl-defmethod emc-craft-command ((sys (eql 'windows-nt))
				 (build-system (eql 'cmake))
				 &rest keys
				 &key
				 &allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='windows-nt\\=' and
BUILD-SYSTEM equal to \\=':make\\=' is invoked with KEYS."
  
  (ignore sys build-system)
  (apply #'emc-msvc-cmake-cmd keys)
  )


(cl-defmethod emc-craft-command ((sys (eql 'darwin))
				 (build-system (eql 'cmake))
				 &rest keys
				 &key
				 &allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='windows-nt\\=' and
BUILD-SYSTEM equal to \\=':make\\=' is invoked with KEYS."
  
  (ignore sys build-system)
  (apply #'emc-macos-cmake-cmd keys)
  )


(cl-defmethod emc-craft-command ((sys (eql 'generic-unix))
				 (build-system (eql 'cmake))
				 &rest keys
				 &key
				 &allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='windows-nt\\=' and
BUILD-SYSTEM equal to \\=':make\\=' is invoked with KEYS."
  
  (ignore sys build-system)
  (apply #'emc-unix-cmake-cmd keys)
  )


(cl-defmethod emc-start-making ((sys (eql 'windows-nt))
				(build-system (eql 'cmake))
				&rest keys
				&key
				&allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='windows-nt\\=' and
BUILD-SYSTEM equal to \\='cmake\\=' is invoked with KEYS."
  (ignore sys build-system)
  (emc--invoke-make (apply #'emc-msvc-cmake-cmd keys))
  )


(cl-defmethod emc-start-making ((sys (eql 'generic-unix))
				(build-system (eql 'cmake))
				&rest keys
				&key
				&allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='generic-unix\\=' and
BUILD-SYSTEM equal to \\='cmake\\=' is invoked with KEYS."
  (ignore sys build-system)
  (emc--invoke-make (apply #'emc-unix-cmake-cmd keys))
  )


(cl-defmethod emc-start-making ((sys (eql 'darwin))
				(build-system (eql 'cmake))
				&rest keys
				&key
				&allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='darwin\\=' (MacOS) and
BUILD-SYSTEM equal to \\='cmake\\=' is invoked with KEYS."
  (ignore sys build-system)
  (emc--invoke-make (apply #'emc-macos-cmake-cmd keys))
  )


;; Commands
;; --------
;;
;; The following are functions that have the `interactive' feature.
;; Some useful extra functions are also provided (the `emc--read-*'
;; functions).


;; emc-setup

(cl-defun emc-setup (&rest keys
                           &key
                           (makefile "Makefile")
                           (make-macros "")
                           (targets "")
			   (wait nil)
			   (build-system emc-*default-build-system*)
			   (build-dir default-directory)
                           &allow-other-keys)
  "EMC Build command.

For a \\'make\\=' based build it is essentially a no-op.  For a
\\'CMake\\' based build system it re-packages the targets and calls the
relevant function.

The variables KEYS, MAKEFILE, MAKE-MACROS, WAIT, TARGETS, BUILD-SYSTEM
and BUILD-DIR are as per `emc-make'."

  (interactive
   (let ((build-system (emc--read-ensure-build-system)))
     (cl-list* :build-system build-system
	       (emc--read-command-parms
		current-prefix-arg
		build-system
		'(:makefile
		  :build-dir
		  :source-dir
		  :make-macros
		  :targets)
		(list :makefile "Makefile"
		      :make-macros ""
		      :targets ""
		      :build-dir default-directory
		      :source-dir default-directory
		      )))
     )
   )

  
  (ignore makefile make-macros targets wait build-dir)

  (cl-case (emc--normalize-build-system build-system)
    ((make :make)

     (when (and (called-interactively-p 'any) (null current-prefix-arg))
       ;; The function was called interactivle but without the "full"
       ;; reading of keyword parameters.
       
       (unless (or (file-exists-p makefile)
		   (file-exists-p
		    (expand-file-name (file-name-nondirectory makefile)
				      build-dir)))
	 (setf makefile
	       (emc--read-makefile-name)
	       ;; (read-file-name "Makefile: " nil "Makefile" t "Makefile")
	       )
	 ))
     
     (if (string-search "setup" targets)
	 (apply #'emc-make :makefile makefile keys)
       (progn
	 (warn "EMC: warn: 'setup' command not foreseen for 'make'")
	 t))
     )
    
    ((cmake :cmake) (apply #'emc-cmake :setup keys))
    (t
     (error "EMC: error: unknown build system %S" build-system))
    ))


(cl-defun emc-build (&rest keys
                           &key
                           (makefile "Makefile")
                           (make-macros "")
                           (targets "")
			   (wait nil)
			   (build-system emc-*default-build-system*)
			   (build-dir default-directory)
			   (source-dir default-directory)
                           &allow-other-keys)
  "EMC Build command.

For a \\'make\\=' based build it is essentially a no-op.  For a
\\'CMake\\' based build system it re-packages the targets and calls the
relevant function.

The variables KEYS, MAKEFILE, MAKE-MACROS, WAIT, TARGETS, BUILD-SYSTEM
and BUILD-DIR are as per `emc-make'."

  (interactive
   (let ((build-system (emc--read-ensure-build-system)))
     (cl-list* :build-system build-system
	       (emc--read-command-parms
		current-prefix-arg
		build-system
		'(:makefile
		  :source-dir
		  :build-dir
		  :make-macros
		  :targets)
		(list :makefile "Makefile"
		      :make-macros ""
		      :targets ""
		      :build-dir default-directory
		      :source-dir default-directory
		      )))
     ))
  
  (ignore makefile make-macros targets wait build-dir source-dir)

  (emc--msg "emc-build: %s" keys)
  (emc--msg "emc-build: interactively %s %s"
	    (called-interactively-p 'any)
	    current-prefix-arg)
  
  (cl-case (emc--normalize-build-system build-system)
    ((make :make)

     (when (and (called-interactively-p 'any) (null current-prefix-arg))
       ;; The function was called interactivle but without the "full"
       ;; reading of keyword parameters.
       
       (unless (or (file-exists-p makefile)
		   (file-exists-p
		    (expand-file-name (file-name-nondirectory makefile)
				      build-dir)))
	 (setf makefile
	       (emc--read-makefile-name)
	       ;; (read-file-name "Makefile: " nil "Makefile" t "Makefile")
	       )
	 ))
     
     (apply #'emc-make :makefile makefile keys))
    
    ((cmake :cmake) (apply #'emc-cmake :build keys))
    (t
     (error "EMC: error: unknown build system %S" build-system))
    ))


(cl-defun emc-install (&rest keys
                             &key
                             (makefile "Makefile")
                             (make-macros "")
                             (targets "install")
			     (wait nil)
			     (build-system :make)
			     (build-dir default-directory)
			     (install-dir default-directory)
                             &allow-other-keys)
  "EMC Install command.

For a \\'make\\=' based build it is essentially a no-op.  For a
\\'CMake\\' based build system it re-packages the targets and calls the
relevant function.

The variables KEYS, MAKEFILE, MAKE-MACROS, WAIT, TARGETS, BUILD-SYSTEM
and BUILD-DIR are as per `emc-make'."

  (interactive
   (let ((build-system (emc--read-ensure-build-system)))
     (cl-list* :build-system build-system
	       (emc--read-command-parms
		current-prefix-arg
		build-system
		'(:makefile
		  :build-dir
		  :install-dir
		  )
		(list :makefile "Makefile"
		      :make-macros ""
		      :targets ""
		      :build-dir default-directory
		      :install-dir default-directory
		      )))
     )
   )
  
  (ignore makefile make-macros targets wait install-dir build-dir)

  (emc--msg "emc-install: %s" keys)
  (emc--msg "emc-install: interactively %s %s"
	    (called-interactively-p 'any)
	    current-prefix-arg)

  
  (cl-case (emc--normalize-build-system build-system)
    ((:make make)

     (when (and (called-interactively-p 'any) (null current-prefix-arg))
       ;; The function was called interactivle but without the "full"
       ;; reading of keyword parameters.
       
       (unless (or (file-exists-p makefile)
		   (file-exists-p
		    (expand-file-name (file-name-nondirectory makefile)
				      build-dir)))
	 (setf makefile
	       (emc--read-makefile-name)
	       ;; (read-file-name "Makefile: " nil "Makefile" t "Makefile")
	       )
	 ))
     
     (let ((targets (if (string-equal-ignore-case "install" targets)
			targets
		      (concat "install " targets)))
	   )
       (apply #'emc-make :makefile makefile :targets targets keys)))
    
    ((cmake :cmake)
     (apply #'emc-cmake :install keys))
    (t
     (error "EMC: error: unknown build system %S" build-system))
    ))


(cl-defun emc-uninstall (&rest keys
                               &key
                               (makefile "Makefile")
                               (make-macros "")
                               (targets "uninstall")
			       (wait nil)
			       (build-system emc-*default-build-system*)
			       (build-dir default-directory)
			       (install-dir default-directory)
                               &allow-other-keys)
  "EMC Uninstall command.

For a \\'make\\=' based build it is essentially a no-op.  For a
\\'CMake\\' based build system it re-packages the targets and calls the
relevant function.

The variables KEYS, MAKEFILE, MAKE-MACROS, WAIT, TARGETS, BUILD-SYSTEM
and BUILD-DIR are as per `emc-make'."

  (interactive
   (let ((build-system (emc--read-ensure-build-system)))
     (cl-list* :build-system build-system
	       (emc--read-command-parms
		current-prefix-arg
		build-system
		'(:makefile
		  :build-dir
		  :install-dir
		  )
		(list :makefile "Makefile"
		      :make-macros ""
		      :targets ""
		      :build-dir default-directory
		      :install-dir default-directory
		      )))
     )
   )
  
  (ignore makefile make-macros targets wait install-dir)

  (cl-case (emc--normalize-build-system build-system)
    ((make :make)

     (when (and (called-interactively-p 'any) (null current-prefix-arg))
       ;; The function was called interactivle but without the "full"
       ;; reading of keyword parameters.
       
       (unless (or (file-exists-p makefile)
		   (file-exists-p
		    (expand-file-name (file-name-nondirectory makefile)
				      build-dir)))
	 (setf makefile
	       (emc--read-makefile-name)
	       ;; (read-file-name "Makefile: " nil "Makefile" t "Makefile")
	       )
	 ))
     
     (let ((targets (if (string-equal-ignore-case "uninstall" targets)
			targets
		      (concat "uninstall " targets)))
	   )
       (apply #'emc-make :makefile makefile :targets targets keys)))
    
    ((cmake :cmake)
     (warn "EMC: warning: ensure the 'CMakeLists.txt' files handle 'uninstall'")
     (apply #'emc-cmake :uninstall keys))
    (t
     (error "EMC: error: unknown build system %S" build-system))
    ))


(cl-defun emc-clean (&rest keys
                           &key
                           (makefile "Makefile")
                           (make-macros "")
                           (targets "clean")
			   (wait nil)
			   (build-system emc-*default-build-system*)
			   (build-dir default-directory)
                           &allow-other-keys)
  "EMC Clean command.

For a \\'make\\=' based build it is essentially a no-op.  For a
\\'CMake\\' based build system it re-packages the targets and calls the
relevant function.

The variables KEYS, MAKEFILE, MAKE-MACROS, WAIT, TARGETS, BUILD-SYSTEM
and BUILD-DIR are as per `emc-make'."

  (interactive
   (let ((build-system (emc--read-ensure-build-system)))
     (cl-list* :build-system build-system
	       (emc--read-command-parms
		current-prefix-arg
		build-system
		'(:makefile
		  )
		(list :makefile "Makefile"
		      :make-macros ""
		      :targets "clean"
		      :build-dir default-directory
		      )))
     ))
  
  (ignore makefile make-macros targets wait build-dir)

  (cl-case (emc--normalize-build-system build-system)
    ((make :make)

     (when (and (called-interactively-p 'any) (null current-prefix-arg))
       ;; The function was called interactivle but without the "full"
       ;; reading of keyword parameters.
       
       (unless (or (file-exists-p makefile)
		   (file-exists-p
		    (expand-file-name (file-name-nondirectory makefile)
				      build-dir)))
	 (setf makefile
	       (emc--read-makefile-name)
	       ;; (read-file-name "Makefile: " nil "Makefile" t "Makefile")
	       )
	 ))
     
     (let ((targets (if (string-equal-ignore-case "clean" targets)
			targets
		      (concat "clean " targets)))
	   )
       (apply #'emc-make :makefile makefile :targets targets keys)))
    
    ((cmake :cmake) (apply #'emc-cmake :clean keys))
    (t
     (error "EMC: error: unknown build system %S" build-system))
    ))


(cl-defun emc-fresh (&rest keys
                           &key
                           (makefile "Makefile")
                           (make-macros "")
                           (targets "clean")
			   (wait nil)
			   (build-system emc-*default-build-system*)
			   (build-dir default-directory)
                           &allow-other-keys)
  "EMC Fresh command.

For a \\'make\\=' based build it is essentially a no-op.  For a
\\'CMake\\' based build system it re-packages the targets and calls the
relevant function.

The variables KEYS, MAKEFILE, MAKE-MACROS, WAIT, TARGETS, BUILD-SYSTEM
and BUILD-DIR are as per `emc-make'."

  (interactive
   (let ((build-system (emc--read-ensure-build-system)))
     (cl-list* :build-system build-system
	       (emc--read-command-parms
		current-prefix-arg
		build-system
		'(:makefile
		  :source-dir
		  :build-dir
		  :make-macros
		  :targets
		  )
		(list :makefile "Makefile"
		      :make-macros ""
		      :targets "clean"
		      :build-system emc-*default-build-system*
		      :build-dir default-directory
		      )
		))
     ))
  
  (ignore makefile make-macros targets wait build-dir)

  (cl-case (emc--normalize-build-system build-system)
    ((make :make)

     (when (and (called-interactively-p 'any) (null current-prefix-arg))
       ;; The function was called interactivle but without the "full"
       ;; reading of keyword parameters.
       
       (unless (or (file-exists-p makefile)
		   (file-exists-p
		    (expand-file-name (file-name-nondirectory makefile)
				      build-dir)))
	 (setf makefile
	       (emc--read-makefile-name)
	       ;; (read-file-name "Makefile: " nil "Makefile" t "Makefile")
	       )
	 ))

     (if (string-search "fresh" targets)
	 (apply #'emc-make :makefile makefile keys)
       (progn
	 (warn (concat "EMC: warn: 'fresh' command not foreseen for 'make'; "
		       "maybe you mean 'clean'?"))
	 t))
     )
    
    ((cmake :cmake) (apply #'emc-cmake :fresh keys))
    (t
     (error "EMC: error: unknown build system %S" build-system))
    ))


;; emc-run
;; The most general entry point.

(cl-defun emc-run (cmd &rest keys
		       &key
		       ;; (prefix 42)
		       (build-system emc-*default-build-system*)
		       (source-dir default-directory)
		       (build-dir default-directory)
		       (install-dir default-directory)
		       (make-macros "")
		       (targets "")
		       (verbose emc-*verbose*)
		       &allow-other-keys)
  "Run the \\='making toolchain\\='.

CMD is the main subcommand to execute (e.g., \\='build\\=' or
\\'clean\\=').  BUILD-SYSTEM is the kind of toolchain to use (for the
time being \\='make\\=', the default, or \\='cmake\\=').  BUILD-DIR,
SOURCE-DIR, and INSTALL-DIR, defaulting to `default-directory' have the
usual meaning.  MACROS is a string of \"make like macro\" definitions.
TARGETS is a string of \"make tartgets\" (space separated) to be passed
to \\='make\\=' and \\='cmake\\='.  Finally, KEYS, collects all the
keyword parameters passed as arguments to `emc-run'.  VERBOSE controls
whether EMC prints out progress messages."
  
  (interactive
   (let ((build-system (emc--read-ensure-build-system)))
     (cl-list* (emc--read-cmd)
	       :build-system build-system
	       (emc--read-command-parms
		current-prefix-arg
		build-system
		'(:makefile
		  :source-dir
		  :build-dir
		  :install-dir
		  :make-macros
		  :targets
		  )
		(list :makefile "Makefile"
		      :make-macros ""
		      :targets ""
		      :source-dir default-directory
		      :build-dir default-directory
		      :install-dir default-directory
		      )
		))
     ))

  (ignore build-system source-dir build-dir install-dir make-macros targets)
  
  (emc--msg "emc-run: %s %S" cmd keys)

  (let ((emc-*verbose* verbose))
    (cl-ecase cmd
      ((setup :setup) (apply #'emc-setup keys))
      ((build :build) (apply #'emc-build keys))
      ((install :install) (apply #'emc-install keys))
      ((uninstall :uninstall) (apply #'emc-uninstall keys))
      ((fresh :fresh) (apply #'emc-fresh keys))
      ((clean :clean) (apply #'emc-clean keys))
      ))
  )


(defvar emc-*help-text* "
EMC Help
========

The main commands available in EMC are listed hereafter.  All of them
come in a 'no-prefix' or in a 'prefix' form (using 'C-u'); the
'no-prefix' form runs the command in a minimal form with hopefully
useful defaults, while the 'prefix' form asks for several arguments to
be supplied.

- emc-make      : Invoke make (or nmake).
- emc-cmake     : Invoke cmake.
- emc-run       : Ask which 'build system' to use, what 'command' to run,
                  and then the necessary parameters.
- emc-setup     : Ask which 'build system' to use, and issues a 'setup'
                  command; usually not so useful for make, unless you know
                  there is a 'setup' target in the Makefile.
- emc-build     : Ask which 'build system' to use, and issues a
                  'build' command.
- emc-install   : Ask which 'build system' to use, and issues a
                  'install' command.
- emc-uninstall : Ask which 'build system' to use, and issues a
                  'uninstall' command; note that cmake needs special
                  provisions to make this command available.
- emc-clean     : Ask which 'build system' to use, and issues a
                  'clean' command.
- emc-fresh     : Ask which 'build system' to use, and issues a 'fresh'
                  command; usually not so useful for make, unless you know
                  there is a 'setup' target in the Makefile.
- emc-emc       : Start an Emacs Widget UI to run EMC.

Issuing emc-help or emc-? shows this help buffer.

You can customize EMC by setting values for the variables under the
tools -> emc customization section.
"
  "The EMC Help text dispalyed by emc-help.")


(defun emc-help ()
  "Display EMC basic help."

  (interactive)

  (switch-to-buffer "*EMC Help*")

  (kill-all-local-variables)

  (let ((inhibit-read-only t))
    (erase-buffer)

    (help-mode)

    (insert emc-*help-text*)

    (goto-char (point-min))
    )
  )


(defalias 'emc-? #'emc-help "Display EMC basic help.")


;; emc-mode
;; Minor mode, just to get the "EMC" menu.

(define-minor-mode emc-mode
  "Toggles the minor mode providing a menu for \\='EMC\\=' commands."

  :init-value nil
  :lighter " EMC"

  ;; Ensure that `emc-*default-build-system*' has a local value.

  (when (null emc-*default-build-system*)
    ;; If non NIL it was set, and is, therefore, local.
    
    (setq-local emc-*default-build-system* nil))
  
  ;; Set up the "EMC" menu.

  (easy-menu-define emc--menu (list prog-mode-map dired-mode-map)
    "EMC menu choices"
    '("EMC"
      :help "The EMC selectors and commands"
      ("Build System"
       :help "Known build systems; choose one"
       ["make" (progn
		 (setq-local emc-*default-build-system* 'make)
		 (when (fboundp 'delight)
		   (delight '((emc-mode " EMC[make]" "emc")))
		   )
		 )
	:enable t
	:selected (eq emc-*default-build-system* 'make)
	:style radio
	]
       ["cmake" (progn
		  (setq-local emc-*default-build-system* 'cmake)
		  (when (fboundp 'delight)
		    (delight '((emc-mode " EMC[cmake]" "emc")))
		    )
		  )
	:enable	t
	:selected (eq emc-*default-build-system* 'cmake)
	:style radio
	]
       )
      "---"
      "Commands"
      ["Run" emc-run "Runs the generic builder function"]
      "---"
      ["Setup" emc-setup
       "Sets up the build; mostly useful for CMake"]
      ["Build" emc-build
       "Builds the project/library"]
      ["Install" emc-install
       "Installs the project/library"]
      ["Uninstall" emc-uninstall
       "Uninstalls the project/library; CMake must be setup accordingly"]
      ["Clean" emc-clean
       "Cleans the build directory"]
      ["Fresh" emc-fresh
       "Refresh the build directory; moslty useful for CMake"]
      "---"
      ["EMC panel" emc-emc
       "Starts the Emacs EMC interaction panel"]
      )
    )

  'emc-mode
  )


;; EMC panel.
;; ----------
;;
;; In for an arm, in for a leg.  Let's also have an Emacs Wideget user
;; interface.

(require 'widget)
(require 'wid-edit)


(defvar emc--keymap
  (let ((km (make-sparse-keymap)))
    (set-keymap-parent km widget-keymap)
    (define-key km (kbd "<f1>") 'emc-help)
    (define-key km (kbd "<f3>") 'emc--exit-panel)
    (define-key km (kbd "q") 'emc--exit-panel)
    (define-key km (kbd "Q") 'emc--exit-panel)
    km
    )
  "The EMC Panel mode key map.

The key map inherits from `widget-keymap'.
The keys \\='<f3>\\=' (that is, \\='PF3\\='), \\='q\\=' and \\='Q\\='
exit the EMC panel system.")


(defvar-local emc--from-buffer nil
  "The buffer from which the `emc-emc' command is called.

The value is NIL if not set within the `emc-emc' function.")


(defun emc--header-line ()
  "Create the panel header line."
  (identity
   `(:propertize
     " Emacs Make Compile (EMC, or Emacs Master of Cerimonies)"
     face (:weight bold))
   ))


(define-derived-mode emc--emc-panel-mode nil "EMC"
  "The EMC Panel Mode.

The major mode for the EMC simple user inteface.  Just useful to have
a nice keymap and look.

You an use the function key \\='F3\\=' (i.e., \\='PF3\\=') or the
\\='[Qq]\\=' keys to exit the EMC panel."

  ;; (emc--msg "using local map %S" (keymap-lookup emc--keymap "q"))
  (use-local-map emc--keymap)
  ;; (emc--msg "keymap is now %s" (current-local-map))

  (setq-local mode-line-format
	      (identity
	       '(" "
		 mode-line-buffer-identification
		 " "
		 mode-line-modes
		 " Use 'Q', 'q', or '<F3>' to quit; '<F1>' for help.")))
  )


(defvar emc--*emc-field-size* 50
  "The default size of EMC UI field.")


(cl-defun emc-emc (&aux (from-buffer (current-buffer)))
  "Builds a widgets window that can be used to fill in several parameters.

The window is popped up and the command that will be run is shown in
the ancillary window."

  (interactive)
  
  (switch-to-buffer "*EMC Interface*")

  (kill-all-local-variables)

  (let ((inhibit-read-only t))
    (erase-buffer))

  (emc--emc-panel-mode)

  (setq-local emc--from-buffer from-buffer)
  (setq-local emc--build-system-chosen emc-*default-build-system*)
  (setq-local emc--command-chosen 'build)

  (let ((src-dir-widget nil)
	(bin-dir-widget nil)
	(install-dir-widget nil)
	(cmd-widget nil)
	(makefile-widget nil)
	(targets-widget nil)
	(make-macros-widget nil)
	)
    
    (cl-flet ((modify-cmd-widget ()
		(save-excursion
		  (let* ((build-system emc--build-system-chosen)
			 (cmd emc--command-chosen)
			 (src-dir (widget-value src-dir-widget))
			 (bin-dir (widget-value bin-dir-widget))
			 (install-dir (widget-value install-dir-widget))
			 (makefile (widget-value makefile-widget))
			 (targets (widget-value targets-widget))
			 (macros (widget-value make-macros-widget))
			 
			 (cmdline
			  (emc-craft-command system-type
					     build-system
					     :command cmd
					     :source-dir src-dir
					     :build-dir bin-dir
					     :install-dir install-dir
					     :makefile makefile
					     :targets targets
					     :make-macros macros
					     ))
			 )

		    ;; (emc--msg "%s %s %s %s"
		    ;; 	     build-system
		    ;; 	     src-dir
		    ;; 	     bin-dir
		    ;; 	     cmdline)
		    (widget-value-set cmd-widget cmdline)
		    )))			; modify-cmd-widget

	      (run-cmd ()
		(let* ((build-system emc--build-system-chosen)
		       (cmd emc--command-chosen)
		       (src-dir (widget-value src-dir-widget))
		       (bin-dir (widget-value bin-dir-widget))
		       (install-dir (widget-value install-dir-widget))
		       (makefile-name (widget-value makefile-widget))
		       (targets (widget-value targets-widget))
		       (macros (widget-value make-macros-widget))
		       )

		  (let ((emc-*logging* t))
		    (emc--msg "running %s" build-system)
		    (emc--msg "command %s" cmd)
		    (emc--msg "source dir  : %s" src-dir)
		    (emc--msg "build dir   : %s" bin-dir)
		    (emc--msg "install dir : %s" install-dir)
		    (emc-run cmd
			     :build-system build-system
			     :source-dir src-dir
			     :build-dir bin-dir
			     :install-dir install-dir
			     :make-macros macros
			     :makefile makefile-name
			     :targets targets
			     ))
		  ))			; run-cmd
	      )

      ;; (widget-insert "Emacs Make Compile (EMC, or Emacs Master of Cerimonies)")
      (setq-local header-line-format (emc--header-line))

      (widget-insert "\n")
      (widget-insert (format "Current dir     : %S"
                             default-directory))
      
      (widget-insert "\n\n")
      (widget-create 'menu-choice
		     :tag "Build system "
		     ;; :void ":make"
		     :help-echo "Choose a build system"
		     :value "make"
		     :notify (lambda (w &rest ignore)
			       (ignore ignore)
			       (emc--msg "chose build system: %S"
					 (widget-value w))
			       (setq-local
				emc--build-system-chosen
				(emc--normalize-to-symbol (widget-value w)))
			       (modify-cmd-widget ; (widget-value w)
				)
			       )

		     '(choice-item :tag "make" :value "make")
		     '(choice-item :tag "cmake" :value "cmake")
		     )

      (widget-insert "\n")
      (setq makefile-widget
	    (widget-create 'string
			   :value "Makefile"
			   :format "Makefile        : %v"
			   :size emc--*emc-field-size*
			   :notify (lambda (w &rest ignore)
				     (ignore w ignore)
				     (save-excursion
				       (modify-cmd-widget ; (widget-value w)
					)))
			   :help-echo "The 'makefile' name."
			   ))

      (widget-insert "\n\n")
      
      (setq src-dir-widget
	    (widget-create 'directory
			   :value default-directory
			   :format "Source dir      : %v"
                           
			   :size emc--*emc-field-size*
			   
			   :notify (lambda (w &rest ignore)
				     (ignore w ignore)
				     (save-excursion
				       (modify-cmd-widget ; (widget-value w)
					)))


			   :help-echo
			   "The directory where the 'source' is found."
			   ))
      (widget-insert "\n")
      
      (setq bin-dir-widget
	    (widget-create 'directory
			   :value default-directory
			   :format "Build dir       : %v"

			   :size emc--*emc-field-size*
			   
			   :notify (lambda (w &rest ignore)
				     (ignore w ignore)
				     (save-excursion
				       (modify-cmd-widget ; (widget-value w)
					)))
			   
			   :help-echo
			   "The directory where the 'source' is built."
			   ))
      (widget-insert "\n")

      (setq install-dir-widget
	    (widget-create 'directory
			   :value default-directory
			   :format "Install dir     : %v"
			   :size emc--*emc-field-size*
			   
			   :notify (lambda (w &rest ignore)
				     (ignore w ignore)
				     (save-excursion
				       (modify-cmd-widget ; (widget-value w)
					)))
			   
			   :help-echo
			   "The directory where the build result is 'installed'."
			   ))
      
      (widget-insert "\n\n")
      (widget-create 'menu-choice
		     :tag "Command "
		     :help-echo "Choose the (sub) 'command' to execute."
		     :value "build"
		     :notify (lambda (w &rest ignore)
			       (ignore ignore)
			       (emc--msg "chose build system: %S"
					 (widget-value w))
			       (setq-local
				emc--command-chosen
				(emc--normalize-to-symbol (widget-value w)))
			       (modify-cmd-widget ; (widget-value w)
				)
			       )
		     '(choice-item :tag "setup" :value "setup"
				   :help-echo
				   (concat "Sets up the build system; "
					   "useful for 'cmake', not so "
					   "much for 'make'."))
		     '(choice-item :tag "build" :value "build"
				   :help-echo "Invokes the build system.")
		     '(choice-item :tag "install" :value "install"
				   :help-echo
				   (concat "Invokes the build system "
					   "installation machinery."))
		     '(choice-item :tag "uninstall" :value "uninstall"
				   :help-echo
				   (concat "Invokes the build system "
					   "uninstallation machinery. "
					   "Note that 'cmake' "
					   "requires  special "
					   "provisions to make the "
					   "'uninstall' command available."))
		     
		     '(choice-item :tag "clean" :value "clean"
				   :help-echo "Invokes the cleanup machinery.")
		     '(choice-item :tag "fresh" :value "fresh"
				   :help-echo
				   (concat "For 'cmake' it invokes the "
					   "eponimous command; for "
					   "'make' it may generate an error.")
				   )
		     )

      (widget-insert "\n")
      (setq make-macros-widget
	    (widget-create 'string
			   :value ""
			   :format "Macros          : %v"
			   :size emc--*emc-field-size*
			   :notify (lambda (w &rest ignore)
				     (ignore w ignore)
				     (save-excursion
				       (modify-cmd-widget ; (widget-value w)
					)))
			   ))
      
      (widget-insert "\n")
      (setq targets-widget
	    (widget-create 'string
			   :value ""
			   :format "(Extra) targets : %v"
			   :size emc--*emc-field-size*
			   :notify (lambda (w &rest ignore)
				     (ignore w ignore)
				     (save-excursion
				       (modify-cmd-widget ; (widget-value w)
					)))
			   ))

      
      (widget-insert "\n\n")
      ;; (widget-create 'group :tag "Actual command")
      (widget-insert "Actual command:")
      (widget-insert "\n")
      (setq cmd-widget
	    (widget-create 'item :value ""))

      (widget-insert "\n\n")
      (widget-create 'push-button :value "Run"
		     :notify (lambda (w &rest args)
			       (ignore w args)
			       (emc--msg "running %S"
					 (widget-value cmd-widget))
			       (run-cmd)
			       ))
      (widget-insert "     ")
      (widget-create 'push-button
		     :value "Cancel/Close"
		     :notify (lambda (w &rest args)
			       (ignore w args)
			       (emc--exit-panel))
		     )


      (widget-insert "     ")
      (widget-create 'push-button
		     :value "Help"
		     :notify (lambda (w &rest args)
			       (ignore w args)
			       (emc-help))
		     )
      
      ;; (widget-insert "     ")
      ;; (widget-create 'push-button
      ;; 		     :value "Mess src dir"
      ;; 		     :notify (lambda (w &rest args)
      ;; 			       (ignore w args)
      ;; 			       (message "Widget %s"
      ;; 					(widget-get src-dir-widget :widget))
      ;; 			       (widget-browse src-dir-widget)
      ;; 			       (widget-delete src-dir-widget)
      ;; 			       )
      ;; 		     )
      ;; (widget-insert "     ")
      ;; (widget-create 'push-button
      ;; 		     :value "Redo src dir"
      ;; 		     :notify (lambda (w &rest args)
      ;; 			       (ignore w args)
      ;; 			       ;; (widget-insert src-dir-widget)
      ;; 			       )
      ;; 		     )

      (widget-insert "\n")

      (prog1 (widget-setup)
	(goto-char (point-min))
	(widget-forward 1))
      )))


(defun emc--exit-panel ()
  "Exit the EMC panel (and buffer)."

  (interactive)

  (let ((emc-panel (current-buffer)))	; I could find it by name.

    (with-current-buffer emc-panel
      ;; Order of `switch-to-buffer' and `kill-buffer' is important.
      (if (and (bufferp emc--from-buffer)
	       (buffer-live-p emc--from-buffer))
	  (switch-to-buffer emc--from-buffer nil t)
	(switch-to-buffer nil))
      
      (kill-buffer emc-panel)
      )))


;;; Epilogue.

(provide 'emc '(make cmake))


;;; emc.el ends here
