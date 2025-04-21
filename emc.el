;;; -*- Mode: Emacs-Lisp; lexical-binding: t; -*-
;;; emc --- Invoking a C/C++ (et al.) build toolchain from Emacs.

;;; emc.el
;;;
;;; See the file COPYING in the top directory for copyright and
;;; licensing information.

;; Author: Marco Antoniotti <marcoxa [at] gmail.com>
;; Maintainer: Marco Antoniotti <marcoxa [at] gmail.com>
;;
;; Summary: Invoking a C/C++ (and other) build toolchain from Emacs.
;;
;; Created: 2025-01-02
;; Version: 2025-04-21
;;
;; Keywords: languages, operating systems, binary platform.


;;; Commentary:
;;
;; Invoking a C/C++ (and other) build tool-chain from Emacs.
;;
;; The standard 'compile' machinery is mostly designed for interactive
;; use, but nowadays, for C/C++ at least, build systems and different
;; platforms make the process a bit more complicated.
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
;; There are three main `emc' commands: `emc:run', `emc:make', and
;;`emc:cmake'.  `emc:run' is the most generic command and allows to
;; select the build system.  `emc:make' and `emc:cmake' assume instead
;; 'make' or 'nmake' and 'cmake' respectively.
;;
;; Invoking the command `emc:run' will use the
;; `emc:*default-build-system*' (defaulting to `:make') on the current
;; platform supplying hopefully reasonable defaults.  E.g.,
;; ```
;;    (emc:run)
;; ```
;; will usually result in a call to
;; ```
;;    make -f Makefile
;; ```
;; on UN*X platoforms.
;;
;; All in all, the easiest way to use this library is to call the `emc:make'
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
;;
;; To invoke 'cmake' the relevant function is `emc:cmake' which takes
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



;;; Code:

(require 'cl-lib)
(require 'compile)


(cl-deftype emc:build-system-type ()
  "The known EMC build-systems."
  '(member make cmake)			; Used to have :make :cmake.
  )


(defun emc::normalize-build-system (build-system)
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

(defun emc::normalize-to-symbol (x)
  "Ensure that the X argument is rendered as a symbol."

  ;; The `cl-typecase' could be made tighter by referring to
  ;; `emc:build-system-type'.
  
  (cl-etypecase x
    (symbol x)
    (string (intern x))
    ))


(defun emc::normalize-to-string (x)
  "Ensure that the X argument is rendered as a symbol."

  ;; The `cl-typecase' could be made tighter by referring to
  ;; `emc:build-system-type'.
  
  (cl-etypecase x
    (symbol (symbol-name x))
    (string x)
    ))


(defgroup emc ()
  "The Emacs Make Compile (EMC).

EMC is thin layer over the invocation of C/C++ and compiler
toolchains."
  :group 'tools
  )


(defvar emc:path (file-name-directory (or load-file-name "."))
  "The location EMC is loaded from.")


(defcustom emc:*default-build-system* 'make
  "The EMC default build system."
  :group 'emc
  :type 'symbol
  :options '(make cmake)
  )


;;; cmake common definitions.
;;; -------------------------

(defun emc::select-cmake-cmd (command)
  "Select a proper \\='cmake\\=' COMMAND line switch."

  ;; The selectors used to be just keywords.
  
  (cl-ecase (emc::normalize-command command)
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


(defun emc::cmake-cmd (kwd sd bd id)
  "Return the proper \\='cmake\\=' command.

KWD is one of `emc::commands' in keyword form.  SD, BD, and ID are the
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
     ;; (dry-run nil)
     &allow-other-keys)
  "Return the \\='nmake\\=' command (a string) to execute.

The \\='nmake\\=' command is prepended by the necessary MSVC setup done
by `emc:msc-vcvarsall-cmd'.  The variables :INSTALLATION (keyword
variable MSVC-INSTALLATION) and :VCVARS-BAT (keyword variable
MSVC-VCVARS-BAT) are passed to `emc:msc-vcvarsall-cmd'; MAKE-MACROS is a
string containing MACRO=DEF definitions; NOLOGO specifies whether or not
to pass the \\='/NOLOGO\\=' flag to \\='nmake\\='; finally TARGETS is a
string of makefile targets.  Finally, BUILD-DIR contains the folder
where \\='nmake\\=' will be run. DRY-RUN runs the \\='nmake\\=' command
without executing it."

  (concat (if bd-p (concat "cd " build-dir " & ") "") ; Cf., `compile'.

	  "( "
          (shell-quote-argument
           (emc:msvc-vcvarsall-cmd msvc-installation msvc-vcvarsall-bat))
          " > nul )"  ; To suppress the logo from 'msvc-vcvarsall-bat'.
          " & "
          "nmake "
          (when nologo "/NOLOGO ")
          (when makefile-p (format "/F %s " (shell-quote-argument makefile)))
          (when make-macros-p (concat (shell-quote-argument make-macros) " "))
	  ;; (when dry-run "-n ")
          targets)
  )


(cl-defun emc:msvc-cmake-cmd
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
by `emc:msc-vcvarsall-cmd'.  The variables :INSTALLATION (keyword
variable MSVC-INSTALLATION) and :VCVARS-BAT (keyword variable
MSVC-VCVARS-BAT) are passed to `emc:msc-vcvarsall-cmd'..  COMMAND is the
\\='cmake\\=' selector for the top level switch.  TARGETS is a string of
Makefile targets.  BUILD-DIR is the folder where \\='cmake\\=' will
build the project.  SOURCE-DIR is the folder where the project folder
resides.  INSTALL-DIR is used for the \\=':install\\=' command. DRY-RUN
runs the \\='cmake\\=' command without executing it."

  (let* ((sd (if sd-p (shell-quote-argument source-dir) source-dir))
	 (bd (if bd-p (shell-quote-argument build-dir) build-dir))
	 (id (if id-p (shell-quote-argument install-dir) install-dir))
	 (targets-list (string-split targets nil t " "))
	 (cmd-kwd (emc::normalize-command command))
	 )
    (concat (if bd-p (concat "cd " build-dir " & ") "")
	    "( "
            (shell-quote-argument
             (emc:msvc-vcvarsall-cmd msvc-installation msvc-vcvarsall-bat))
            " > nul )" ; To suppress the logo from 'msvc-vcvarsall-bat'.
            " & "
	    (emc::cmake-cmd cmd-kwd sd bd id)
	    (when dry-run " -N ")
	    (mapconcat #'(lambda (s) (concat " -t " s))
		       targets-list)
	    )
    ))


;; UNIX/Linux definitions.
;; -----------------------

(cl-defun emc:unix-make-cmd (&key
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
          (when makefile-p (format "-f %s " (shell-quote-argument makefile)))
          (when make-macros-p (concat (shell-quote-argument make-macros) " "))
	  (when dry-run "-n ")
          targets)
  )


(cl-defun emc:unix-cmake-cmd (&key
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

    (emc::unix-cmake-cmd :command :build :build-dir \".\")

yields

\"cmake --build .\""

  (let* ((sd (if sd-p (shell-quote-argument source-dir) source-dir))
	 (bd (if bd-p (shell-quote-argument build-dir) build-dir))
	 (id (if id-p (shell-quote-argument install-dir) install-dir))
	 (targets-list (string-split targets nil t " "))
	 (cmd-kwd (emc::normalize-command command))
	 )
	
    (concat (emc::cmake-cmd cmd-kwd sd bd id)
	    (when dry-run " -N ")
	    (mapconcat #'(lambda (s) (concat " -t " s))
		       targets-list)
	    )
    ))


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


(cl-defun emc:macos-cmake-cmd (&rest keys &key &allow-other-keys)
  "Return the \\='cmake\\=' command (a string) to execute.

KEYS collects all the keywords that are used by the underlying
dispathc machinery.

COMMAND is the \\='cmake\\=' selector for the top level switch.
TARGETS is a string of Makefile targets.  BUILD-DIR is the folder where
\\='cmake\\=' will build the project.  SOURCE-DIR is the folder where
the project folder resides.  INSTALL-DIR is used for the
\\=':install\\=' command.

Examples:

    (emc::unix-cmake-cmd :command :build :build-dir \".\")

yields

\"cmake --build .\"

Notes:

This is just a wrapper for `emc:unix-cmake-cmd'."
  (apply #'emc:unix-cmake-cmd keys)
  )


;; Generic API exported functions.
;; -------------------------------
;;
;; I reuse the 'compile.el' machinery.

(defcustom emc:*max-line-length* 72
  "The maximum compilation line length used by `compile'.

See Also:

`compilation-max-output-line-length'"
  :group 'emc
  :type 'natnum
  )


(defcustom emc:*verbose* nil
  "If non NIL show messages about EMC progress."
  :group 'emc
  :type 'sexp
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


;; emc::commands
;; Unused FTTB.

(cl-deftype emc::commands ()
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


(defun emc::normalize-command (command)
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


(cl-defgeneric emc:craft-command (sys build-system
				      &rest keys
				      &key
				      &allow-other-keys)
  "Craft (shape, build, evoke) the actual command to be executed.

SYS is the platform (cf., `system'), BUILD-SYSTEM is the tool and KEYS
contains the extra parameters needed."
  ;; `flycheck-mode' needs to get its act together.
  )


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

The processe is  initiated by \\=`compile\\=' and recorded my
\\='emc\\='.")


(cl-defun emc::compile-finish-fn (cur-buffer msg)
  "Function to be added as a hook tp `compilation-finish-functions'.

The arguments are the current buffer CUR-BUFFER and MSG, the messsage
that is built by the \\='compile\\=' machinery.

Notes:

For the time being, the function is a simple wrapper to add the
\"EMC\" prefix to the message."
  (message "EMC: %S %S" (buffer-name cur-buffer) msg))


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
   

(cl-defun emc::invoke-make (make-cmd &optional
				     (max-ll emc:*max-line-length*)
				     (verbose emc:*verbose*)
				     )
  "Call the MAKE-CMD using `compile'.

The optional MAX-LL argument is used to set the compilation buffer
maximum line length.  VERBOSE controls whether the function prints out
progress messages."
  (let ((compilation-max-output-line-length max-ll)
	(compilation-buffer-name-function #'emc::compilation-buffer-name)
	)

    (when verbose
      (message "EMC: invoking %S" make-cmd))
    
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
			  (dry-run nil)
			  (wait nil)
			  (build-system 'make)
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
invokes a \\='CMake\\=' build pipeline with some assumptions (not yet
working).  BUILD-DIR is the directory (folder) where the build
system will be invoked. DRY-RUN runs the \\='cmake\\=' command without
executing it."

  (ignore dry-run)
  
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

  (apply #'emc:start-making (emc::platform-type) build-system keys)

  (when wait
    (message "EMC: waiting...")
    (while (memq emc::*compilation-process* compilation-in-progress)
      ;; Spin loop.
      (sit-for 1.0))
    (message "EMC: done."))
  )


;; make/nmake `emc:craft-command' methods.

(cl-defmethod emc:craft-command ((sys t) (build-system t)
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


(defun emc::craft-make-targets (command targets)
  "Craft the final set of targets for a \\='make\\=' call.

COMMAND is the EMC command indicator (a symbol) and TARGETS is the
initial target list (actually a space separated string)."
  
  (let ((cmd-target (if (eq command 'build)
			"" 		; Maybe it should be "all".
		      (emc::normalize-to-string command)))
	)
    (cond ((and (not (eq command 'build))
		(string-search cmd-target targets))
	   targets)
	  ((eq command 'build)
	   targets)
	  (t
	   (concat cmd-target " " targets))))
  )

    
(cl-defmethod emc:craft-command ((sys (eql 'windows-nt))
				 (build-system (eql 'make))
				 &rest keys
				 &key
				 (command 'buil)
				 (targets "")
				 &allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='windows-nt\\=' and
BUILD-SYSTEM equal to \\='make\\=' is invoked with KEYS."
  
  (ignore sys build-system)
  (let ((tgts (emc::craft-make-targets command targets)))
    
    (message "EMC: craft-command: MSVC nmake: %S %S" command tgts)
    (cl-remf keys :targets)
    (message "EMC: craft-command: %S" keys)
    (apply #'emc:msvc-make-cmd :targets tgts keys)
    ))


(cl-defmethod emc:craft-command ((sys (eql 'darwin))
				 (build-system (eql 'make))
				 &rest keys
				 &key
				 (command 'build)
				 (targets "")
				 &allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='windows-nt\\=' and
BUILD-SYSTEM equal to \\=':make\\=' is invoked with KEYS."
  
  (ignore sys build-system)

  (let ((tgts (emc::craft-make-targets command targets)))
    
    (message "EMC: craft-command: MacOS make: %S %S" command tgts)
    (cl-remf keys :targets)
    (message "EMC: craft-command: %S" keys)
    (apply #'emc:unix-make-cmd :targets tgts keys)
    ))


(cl-defmethod emc:craft-command ((sys (eql 'generic-unix))
				 (build-system (eql 'make))
				 &rest keys
				 &key
				 (command 'build)
				 (targets "")
				 &allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='windows-nt\\=' and
BUILD-SYSTEM equal to \\=':make\\=' is invoked with KEYS."
  
  (ignore sys build-system)

  (let ((tgts (emc::craft-make-targets command targets)))

    (message "EMC: craft-command: UNX make: %S %S" command tgts)
    (cl-remf keys :targets)
    (message "EMC: craft-command: %S" keys)
    (apply #'emc:unix-make-cmd :targets tgts keys)
    ))


;; make/nmake `emc:start-making' methods.

(cl-defmethod emc:start-making ((sys t) (build-system t)
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

(cl-defmethod emc:start-making ((sys (eql 'windows-nt))
				(build-system (eql 'make))
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
				(build-system (eql 'make))
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
				(build-system (eql 'make))
				&rest keys
				&key
				&allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='generic-unix\\=' and
BUILD-SYSTEM equal to \\=':make\\=' is invoked with KEYS."
  (ignore sys build-system)
  (emc::invoke-make (apply #'emc:unix-make-cmd keys))
  )


;; CMake and CMake `emc:start-making' methods.

(cl-defun emc:cmake (cmd &rest keys
                         &key
                         (make-macros "")
                         (targets "")
			 (dry-run nil)
			 (wait nil)
			 (source-dir default-directory)
			 (build-dir default-directory)
                         &allow-other-keys)
  "Call \\='cmake\\=' in a platform dependend way.

CMD is the \\='cmake\\=' subcommand to invoke (e.g., \\='build\\=' or
\\='install\\=').  KEYS contains the keyword arguments passed to the
specialized `emc:X-cmake-cmd' functions via `emc:start-making';
MAKE-MACROS is a string containing \\='MACRO=DEF\\=' definitions;
TARGETS is a string of Makefile targets.  WAIT is a boolean telling
`emc:cmake' whether to wait or not for the compilation process
termination.  Finally, SOURCE-DIR is the directory (folder) where the
project resides, while BUILD-DIR is the directory (folder) where the
build system will be invoked.  DRY-RUN runs the \\='cmake\\=' command
without executing it."

  (ignore dry-run)
  
  ;; Some preventive basic error checking.
  
  (unless (file-exists-p source-dir)
    (error "EMC: error: non-existing source directory %S" source-dir))
  (unless (file-exists-p build-dir)
    (error "EMC: error: non-existing build directory %S" build-dir))

  ;; Here we go.

  (message "EMC: running 'cmake' command %S" cmd)
  (message "EMC: source-dir:  %S" source-dir)
  (message "EMC: build-dir:   %S" build-dir)
  (message "EMC: make-macros: %S" make-macros)
  (message "EMC: targets:     %S" targets)
  (message "EMC: making...")

  (apply #'emc:start-making (emc::platform-type) :cmake :command cmd keys)

  (when wait
    (message "EMC: waiting...")
    (while (memq emc::*compilation-process* compilation-in-progress)
      ;; Spin loop.
      (sit-for 1.0))
    (message "EMC: done."))
  )


;; To be removed.

;; (cl-defgeneric emc:cmake-gf (cmd &rest keys &key &allow-other-keys)
;;   "Interface for \\='cmake\\='.
;;
;; The CMD parameter works almost like the \\='cmake\\=' command line
;; couterpart.  KEYS groups the extra parameters passed to the
;; function.")
;;
;;
;; (cl-defmethod emc:cmake-gf ((cmd (eql :build)) &key &allow-other-keys)
;;   "Method to invoke \\='cmake\\=' \"build\" command, when CMD is \\=':build\\='."
;;   (ignore cmd)
;;   )
;;
;;
;; (cl-defmethod emc:cmake-gf ((cmd (eql :install)) &key &allow-other-keys)
;;   "Method to invoke \\='cmake\\=' \"build\" command, when CMD is \\=':install\\='."
;;   (ignore cmd)
;;   )
;;
;;
;; (cl-defmethod emc:cmake-gf ((cmd (eql :uninstall)) &key &allow-other-keys)
;;   "Method to invoke \\='cmake\\=' \"build\" command, when CMD is \\=':uninstall\\='."
;;   (ignore cmd)
;;   )
;;
;;
;; (cl-defmethod emc:cmake-gf ((cmd (eql :build)) &key &allow-other-keys)
;;   "Method to invocke \\='cmake\\=' \"build\" command, when CMD is \\=':build\\='."
;;   (ignore cmd)
;;   )
;;
;;
;; (cl-defmethod emc:cmake-gf ((cmd (eql :fresh)) &key &allow-other-keys)
;;   "Method to invoke \\='cmake\\=' \"build\" command, when CMD is \\=':fresh\\='."
;;   (ignore cmd)
;;   )


(cl-defmethod emc:craft-command ((sys (eql 'windows-nt))
				 (build-system (eql 'cmake))
				 &rest keys
				 &key
				 &allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='windows-nt\\=' and
BUILD-SYSTEM equal to \\=':make\\=' is invoked with KEYS."
  
  (ignore sys build-system)
  (apply #'emc:msvc-cmake-cmd keys)
  )


(cl-defmethod emc:craft-command ((sys (eql 'darwin))
				 (build-system (eql 'cmake))
				 &rest keys
				 &key
				 &allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='windows-nt\\=' and
BUILD-SYSTEM equal to \\=':make\\=' is invoked with KEYS."
  
  (ignore sys build-system)
  (apply #'emc:macos-cmake-cmd keys)
  )


(cl-defmethod emc:craft-command ((sys (eql 'generic-unix))
				 (build-system (eql 'cmake))
				 &rest keys
				 &key
				 &allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='windows-nt\\=' and
BUILD-SYSTEM equal to \\=':make\\=' is invoked with KEYS."
  
  (ignore sys build-system)
  (apply #'emc:unix-cmake-cmd keys)
  )


(cl-defmethod emc:start-making ((sys (eql 'windows-nt))
				(build-system (eql 'cmake))
				&rest keys
				&key
				&allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='windows-nt\\=' and
BUILD-SYSTEM equal to \\=':cmake\\=' is invoked with KEYS."
  (ignore sys build-system)
  (emc::invoke-make (apply #'emc:msvc-cmake-cmd keys))
  )


(cl-defmethod emc:start-making ((sys (eql 'generic-unix))
				(build-system (eql 'cmake))
				&rest keys
				&key
				&allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='generic-unix\\=' and
BUILD-SYSTEM equal to \\=':cmake\\=' is invoked with KEYS."
  (ignore sys build-system)
  (emc::invoke-make (apply #'emc:unix-cmake-cmd keys))
  )



(cl-defmethod emc:start-making ((sys (eql 'darwin))
				(build-system (eql 'cmake))
				&rest keys
				&key
				&allow-other-keys)
  "Dispatch to the specialized machinery.

The proper calls for the pair SYS equal to \\='darwin\\=' (MacOS) and
BUILD-SYSTEM equal to \\=':cmake\\=' is invoked with KEYS."
  (ignore sys build-system)
  (emc::invoke-make (apply #'emc:macos-cmake-cmd keys))
  )


;; Commands

(cl-defun emc:setup (&rest keys
                           &key
                           (makefile "Makefile")
                           (make-macros "")
                           (targets "")
			   (wait nil)
			   (build-system 'make)
			   (build-dir default-directory)
                           &allow-other-keys)
  "EMC Build command.

For a \\'make\\=' based build it is essentially a no-op.  For a
\\'CMake\\' based build system it re-packages the targets and calls the
relevant function.

The variables KEYS, MAKEFILE, MAKE-MACROS, WAIT, TARGETS, BUILD-SYSTEM
and BUILD-DIR are as per `emc:make'."

  (ignore makefile make-macros targets wait build-dir)

  (cl-case build-system
    ((make :make) t)
    ((cmake :cmake) (apply #'emc:cmake :setup keys))
    (t
     (error "EMC: error: unknown build system %S" build-system))
    ))


(cl-defun emc:build (&rest keys
                           &key
                           (makefile "Makefile")
                           (make-macros "")
                           (targets "")
			   (wait nil)
			   (build-system 'make)
			   (build-dir default-directory)
                           &allow-other-keys)
  "EMC Build command.

For a \\'make\\=' based build it is essentially a no-op.  For a
\\'CMake\\' based build system it re-packages the targets and calls the
relevant function.

The variables KEYS, MAKEFILE, MAKE-MACROS, WAIT, TARGETS, BUILD-SYSTEM
and BUILD-DIR are as per `emc:make'."

  (ignore makefile make-macros targets wait build-dir)

  (cl-case build-system
    ((make :make) (apply #'emc:make keys))
    ((cmake :cmake) (apply #'emc:cmake :build keys))
    (t
     (error "EMC: error: unknown build system %S" build-system))
    ))


(cl-defun emc:install (&rest keys
                             &key
                             (makefile "Makefile")
                             (make-macros "")
                             (targets "install")
			     (wait nil)
			     (build-system :make)
			     (build-dir default-directory)
                             &allow-other-keys)
  "EMC Install command.

For a \\'make\\=' based build it is essentially a no-op.  For a
\\'CMake\\' based build system it re-packages the targets and calls the
relevant function.

The variables KEYS, MAKEFILE, MAKE-MACROS, WAIT, TARGETS, BUILD-SYSTEM
and BUILD-DIR are as per `emc:make'."

  (ignore makefile make-macros targets wait build-dir)

  (cl-case build-system
    ((:make make)
     (let ((targets (if (string-equal-ignore-case "install" targets)
			targets
		      (concat "install " targets)))
	   )
       (apply #'emc:make :targets targets keys)))
    ((cmake :cmake)
     (apply #'emc:cmake :install keys))
    (t
     (error "EMC: error: unknown build system %S" build-system))
    ))


(cl-defun emc:uninstall (&rest keys
                               &key
                               (makefile "Makefile")
                               (make-macros "")
                               (targets "uninstall")
			       (wait nil)
			       (build-system 'make)
			       (build-dir default-directory)
                               &allow-other-keys)
  "EMC Uninstall command.

For a \\'make\\=' based build it is essentially a no-op.  For a
\\'CMake\\' based build system it re-packages the targets and calls the
relevant function.

The variables KEYS, MAKEFILE, MAKE-MACROS, WAIT, TARGETS, BUILD-SYSTEM
and BUILD-DIR are as per `emc:make'."

  (ignore makefile make-macros targets wait build-dir)

  (cl-case build-system
    ((make :make)
     (let ((targets (if (string-equal-ignore-case "uninstall" targets)
			targets
		      (concat "uninstall " targets)))
	   )
       (apply #'emc:make :targets targets keys)))
    ((cmake :cmake)
     (warn "EMC: warning: ensure the 'CMakeLists.txt' files handle 'uninstall'")
     (apply #'emc:cmake :uninstall keys))
    (t
     (error "EMC: error: unknown build system %S" build-system))
    ))


(cl-defun emc:clean (&rest keys
                           &key
                           (makefile "Makefile")
                           (make-macros "")
                           (targets "clean")
			   (wait nil)
			   (build-system 'make)
			   (build-dir default-directory)
                           &allow-other-keys)
  "EMC Clean command.

For a \\'make\\=' based build it is essentially a no-op.  For a
\\'CMake\\' based build system it re-packages the targets and calls the
relevant function.

The variables KEYS, MAKEFILE, MAKE-MACROS, WAIT, TARGETS, BUILD-SYSTEM
and BUILD-DIR are as per `emc:make'."

  (ignore makefile make-macros targets wait build-dir)

  (cl-case build-system
    ((make :make)
     (let ((targets (if (string-equal-ignore-case "clean" targets)
			targets
		      (concat "clean " targets)))
	   )
       (apply #'emc:make :targets targets keys)))
    ((cmake :cmake) (apply #'emc:cmake :clean keys))
    (t
     (error "EMC: error: unknown build system %S" build-system))
    ))


(cl-defun emc:fresh (&rest keys
                           &key
                           (makefile "Makefile")
                           (make-macros "")
                           (targets "clean")
			   (wait nil)
			   (build-system 'make)
			   (build-dir default-directory)
                           &allow-other-keys)
  "EMC Fresh command.

For a \\'make\\=' based build it is essentially a no-op.  For a
\\'CMake\\' based build system it re-packages the targets and calls the
relevant function.

The variables KEYS, MAKEFILE, MAKE-MACROS, WAIT, TARGETS, BUILD-SYSTEM
and BUILD-DIR are as per `emc:make'."

  (ignore makefile make-macros targets wait build-dir)

  (cl-case build-system
    ((make :make)
     (let ((targets (if (string-equal-ignore-case "fresh" targets)
			targets
		      (concat "fresh " targets)))
	   )
       (warn "EMC: warning: ensure 'Makefile's have a 'fresh' target")
       (apply #'emc:make :targets targets keys)))
    ((cmake :cmake) (apply #'emc:cmake :fresh keys))
    (t
     (error "EMC: error: unknown build system %S" build-system))
    ))



;; emc::read-build-parms-minibuffer

(defun emc::read-build-parms-minibuffer (&optional prefix-argument)
  "Read the common build system parameters from minibuffer.

PREFIX-ARGUMENT is possibly bound to PREFIX-ARG."
  (let* ((read-answer-short nil)	; Force long answers.
	 (cmd
	  (car
	   (read-from-string
	    (read-answer "Command: "
			 '(("setup" ?s "setup the project")
			   ("build" ?b "build the project")
			   ("install" ?i "install the project")
			   ("uninstall" ?u "uninstall the project")
			   ("fresh" ?f "freshen the project")
			   ("clean" ?c "clean the project")
			   ))))
	  )
	 )
    
    (when emc:*verbose*
      (message "EMC: read build parms from minibuffer (%S %S)."
	       prefix-arg
	       prefix-argument))
    
    (if prefix-argument
	(let ((build-system
	       (read-answer "Build with: "
			    '(("make" ?m "use 'make.")
			      (":make" ?c "use 'cmake'.")
			      ))
	       )
	      (source-dir
	       (expand-file-name
		(read-directory-name "Source directory: ")))
	      (build-dir
	       (expand-file-name
		(read-directory-name "Build directory: ")))
	      (macros
	       (read-from-minibuffer "Macros: " nil nil nil nil ""))
	      (targets
	       (read-from-minibuffer "Targets: " nil nil nil nil ""))
	      )
	  (list cmd
		:build-system (car (read-from-string build-system))
		:source-dir source-dir
		:build-dir build-dir
		:macros macros
		:targets targets
		;; :prefix current-prefix-arg
		))
      
      ;; Default is no prefix arg was given.
      
      (list cmd
	    :build-system 'make
	    :source-dir default-directory
	    :build-dir default-directory
	    :macros ""
	    :targets ""
	    ;; :prefix current-prefix-arg
	    ))
    ))


;; emc:run
;; The most general entry point.

(cl-defun emc:run (cmd &rest keys
		       &key
		       ;; (prefix 42)
		       (build-system 'make)
		       (source-dir default-directory)
		       (build-dir default-directory)
		       (macros "")
		       (targets "")
		       (verbose emc:*verbose*)
		       &allow-other-keys)
  "Run the \\='making toolchain\\='.

CMD is the main subcommand to execute (e.g., \\='build\\=' or
\\'clean\\=').  BUILD-SYSTEM  is the kind of toolchain to use (for
the time being \\='make\\=', the default, or \\='cmake\\=').
BUILD-DIR and SOURCE-DIR, defaulting to `default-directory' have the
usual meaning.  MACROS is a string of \"make like macro\" definitions.
TARGETS is a string of \"make tartgets\" (space separated) to be
passed to \\='make\\=' and \\='cmake\\='.  Finally, KEYS, collects all
the keyword parameters passed as arguments to `emc:run'.  VERBOSE
controls whether EMC prints out progress messages."
  
  (interactive (emc::read-build-parms-minibuffer current-prefix-arg))

  (ignore build-system source-dir build-dir macros targets)
  
  (message "EMC: %s %S" cmd keys)

  (let ((emc:*verbose* verbose))
    (cl-ecase cmd
      ((setup :setup) (apply #'emc:setup keys))
      ((build :build) (apply #'emc:build keys))
      ((install :install) (apply #'emc:install keys))
      ((uninstall :uninstall) (apply #'emc:uninstall keys))
      ((fresh :fresh) (apply #'emc:fresh keys))
      ((clean :clean) (apply #'emc:clean keys))
      ))
  )


;; EMC panel.
;;
;; In for an arm, in for a leg.

(require 'widget)
(require 'wid-edit)


(defvar emc::keymap
  (let ((km (make-sparse-keymap)))
    (set-keymap-parent km widget-keymap)
    (define-key km (kbd "<f3>") 'emc::exit-panel)
    (define-key km (kbd "q") 'emc::exit-panel)
    (define-key km (kbd "Q") 'emc::exit-panel)
    km
    )
  "The EMC Panel mode key map.

The key map inherits from `widget-keymap'.
The keys \\='<f3>\\=' (that is, \\='PF3\\='), \\='q\\=' and \\='Q\\='
exit the EMC panel system.")


(defvar-local emc::from-buffer nil
  "The buffer from which the `emc:emc' command is called.

The value is NIL if not set within the `emc:emc' function.")


(defun emc::header-line ()
  "Create the panel header line."
  (identity
   `(:propertize
     " Emacs Make Compile (EMC, or Emacs Master of Cerimonies)"
     face (:weight bold))
   ))


(define-derived-mode emc::emc-panel-mode nil "EMC"
  "The EMC Panel Mode.

The major mode for the EMC simple user inteface.  Just useful to have
a nice keymap and look.

You an use the function key \\='F3\\=' (i.e., \\='PF3\\=') or the
\\='[Qq]\\=' keys to exit the EMC panel."

  (message "EMC: using local map %S"
	   (keymap-lookup emc::keymap "q"))
  (use-local-map emc::keymap)
  (message "EMC: keymap is now %s" (current-local-map))
  )


(cl-defun emc:emc (&aux (from-buffer (current-buffer)))
  "Builds a widgets window that can be used to fill in several parameters.

The window is popped up and the command that will be run is shown in
the ancillary window."

  (interactive)
 
  (switch-to-buffer "*EMC Interface*")

  (kill-all-local-variables)

  (let ((inhibit-read-only t))
    (erase-buffer))

  (emc::emc-panel-mode)

  (message "EMC: key 'q' in current-local-map %S"
	   (keymap-lookup (current-local-map) "q"))
  (message "EMC: key 'q' in current-global-map %S"
	   (keymap-lookup (current-global-map) "q"))
  (message "EMC: local == global ? %S"
	   (eql (current-local-map) (current-global-map)))

  (setq-local emc::from-buffer from-buffer)
  (setq-local emc::build-system-chosen 'make)
  (setq-local emc::command-chosen 'build)

  (let ((src-dir-widget nil)
	(bin-dir-widget nil)
	(cmd-widget nil))
    (cl-flet (
	      ;; (modify-cmd-widget (cmd)
	      ;;   (widget-value-set cmd-widget cmd))
	      (modify-cmd-widget ()
		(save-excursion
		  (let* ((build-system emc::build-system-chosen)
			 (cmd emc::command-chosen)
			 (src-dir (widget-value src-dir-widget))
			 (bin-dir (widget-value bin-dir-widget))
			 (cmdline (emc:craft-command system-type
						     build-system
						     :command cmd
						     :source-dir src-dir
						     :build-dir bin-dir))
			 )

		    (message "EMC: %s %s %s %s"
			     build-system
			     src-dir
			     bin-dir
			     cmdline)
		    (widget-value-set cmd-widget cmdline)
		    )))
	      )

      ;; (widget-insert "Emacs Make Compile (EMC, or Emacs Master of Cerimonies)")
      (setq-local header-line-format (emc::header-line))
      
      (widget-insert "\n")
      (widget-create 'menu-choice
		     :tag "Build system "
		     ;; :void ":make"
		     :help-echo "Choose a build system"
		     :value "make"
		     :notify (lambda (w &rest ignore)
			       (ignore ignore)
			       (message "EMC: chose build system: %S"
					(widget-value w))
			       (setq-local
				emc::build-system-chosen
				(emc::normalize-to-symbol (widget-value w)))
			       (modify-cmd-widget ; (widget-value w)
				)
			       )

		     '(choice-item :tag "make" :value "make")
		     '(choice-item :tag "cmake" :value "cmake")
		     )

      (widget-insert "\n")
      (setq src-dir-widget
	    (widget-create 'directory
			   :value default-directory
			   :format "Source dir: %v"
			   :size 40
			   
			   :notify (lambda (w &rest ignore)
				     (ignore w ignore)
				     (save-excursion
				       (modify-cmd-widget ; (widget-value w)
					)))


			   :help-echo "The directory where the 'source' is found."
			   ))
      (widget-insert "\n")
      (setq bin-dir-widget
	    (widget-create 'directory
			   :value default-directory
			   :format "Build dir : %v"
			   :size 40
			   
			   :notify (lambda (w &rest ignore)
				     (ignore w ignore)
				     (save-excursion
				       (modify-cmd-widget ; (widget-value w)
					)))
			   
			   :help-echo "The directory where the 'source' is built."
			   ))

      (widget-insert "\n\n")
      (widget-create 'menu-choice
		     :tag "Command "
		     :help-echo "Choose the (sub) 'command' to execute."
		     :value "build"
		     :notify (lambda (w &rest ignore)
			       (ignore ignore)
			       (message "EMC: chose build system: %S"
					(widget-value w))
			       (setq-local
				emc::command-chosen
				(emc::normalize-to-symbol (widget-value w)))
			       (modify-cmd-widget ; (widget-value w)
				)
			       )
		     '(choice-item :tag "setup" :value "setup"
				   :help-echo
				   (concat "Sets up the build system; "
					   "useful for 'cmake', not so "
					   "much for 'make'."))
		     '(choice-item :tag "build" :value "build")
		     '(choice-item :tag "install" :value "install")
		     '(choice-item :tag "uninstall" :value "uninstall")
		     '(choice-item :tag "clean" :value "clean")
		     '(choice-item :tag "fresh" :value "fresh")
		     )

  
      (widget-insert "\n")
      ;; (widget-create 'group :tag "Actual command")
      (widget-insert "Actual command:")
      (widget-insert "\n")
      (setq cmd-widget
	    (widget-create 'item :value ""))

      (widget-insert "\n\n")
      (widget-create 'push-button :value "Run")
      (widget-insert "     ")
      (widget-create 'push-button
		     :value "Cancel"
		     :notify (lambda (w &rest args)
			       (ignore w args)
			       (emc::exit-panel))
		     )
      (widget-insert "\n")

      (prog1 (widget-setup)
	(goto-char (point-min))
	(widget-forward 1))
      )))


(defun emc::exit-panel () 
  "Exit the EMC panel (and buffer)."

  (interactive)

  (let ((emc-panel (current-buffer)))	; I could find it by name.

    (with-current-buffer emc-panel
      ;; Order of `switch-to-buffer' and `kill-buffer' is important.
      (if (and (bufferp emc::from-buffer)
	       (buffer-live-p emc::from-buffer))
	  (switch-to-buffer emc::from-buffer nil t)
	(switch-to-buffer nil))
      
      (kill-buffer emc-panel)
      )))


;;; Epilogue.

(provide 'emc '(make cmake))

;;; emc.el ends here
