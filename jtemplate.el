;; jtemplate.el --- Helper for building java class
;;
;; Author: Alexandre Brillant <djefer@club-internet.fr>
;; Maintainer: Alexandre Brillant <djefer@club-internet.fr>
;; Official site : http://www.djefer.com
;; Created: 24/09/00
;;
;; This program is free software; you can redistribute it and / or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2, or (at
;; your option) any later version.
;;
;; This is the version 1.1.1 of 02 January 2002
;;
;; Installation : copy jtemplate-db.el with jtemplate.el to an emacs valid path 
;; use the following command in your .emacs :
;; (require `jtemplate)
;;
;; Keys :
;;
;; C-c k c : Build a new class (use full class name)
;; C-c k i : Build a new interface (use full interface name)
;; C-c k p : Set a default package name
;; C-c k o : Open-source header enabled/disabled
;; C-c k m : Main method enabled/disabled
;; C-c k v : Show the jtemplate version
;; C-c k j : For Jdok if available
;;
;; Commands :
;; `jtemplate-make-class'
;; Wizard for class building. You can use a full java class name 
;; ex: awt.djefer.MyClass to set both package and class
;; `jtemplate-make-interface'
;; Wizard for interface building
;; `jtemplate-set-default-package'
;; Decide the default package
;; `jtemplate-opensource'
;; Decide to insert an open-source header

;;; Commentary:
;; Thank you to Stefan Monnier (foo@acm.com) for listp information
;; Thank you to Christoph Conrad (cc@cli.de) for bug report on 1.1

;;; Change Log:

;; Revision: 1.1.1
;; - Correction for actions
;; Revision: 1.1
;; - Eliminate extract blank while merging the model with data
;; - Change the Keyboard mapping for a C-c k prefix
;; - Scan in buffers for interface methods and imports
;; - Bug correction for working without the data base jtemplate-db.el
;; - Add a 'Java Template' menu in the 'Tools' menu
;; Revision: 1.0
;; - Eliminate multiple occurence for an import.
;; - Support for an extra database containing data all JDK interfaces
;; Revision: 0.9
;; - jtemplate uses the current package name if none is specified
;; - support a IMPORT data from the "extends" or "implements" response
;; - add MAIN tag (C-j m)
;; - add SEE tag
;; Revision: 0.8
;; - Reset the buffer's file name to the class name
;; - Add name space for tag : data & action
;; - Add indent & cursor action
;; Revision: 0.7.1
;; - Bug fixed for jtemplate-current-package
;; Revision: 0.7
;; - Dynamic & Static properties
;; - News TAGS : USER-MAIL, USER-NAM, TIME, IMPLEMENTS
;; - Plug-ins support for tags
;; - Add a jtemplate group for open-source header customization
;; Revision: 0.6
;; - Model extension
;; - Design change
;; - jtemplate keymap
;; Revision: 0.5
;; - Model with tag for class building
;; - Design change
;; Revision: 0.4
;; - Design change
;; - Opensource header
;; - Footer for file terminaision
;; Revision: 0.3
;; - Test for java-mode.
;; - Extract class-name and package from full-class-name
;; Revision: 0.2
;; - Support for jdok
;; Revision: 0.1
;; - Basic version

;;; Code:

(defconst jtemplate-version "Jtemplate 1.1 by Alexandre Brillant (http://www.djefer.com)")

;; Java mode name
(defconst jtemplate-java-mode-name "Java")
;; Regular expression for getting a class name
(defconst jtemplate-regexp-class-name "^\\(.*\\.\\)*\\([^.]+\\)")
;; Regular expression for getting a package name
(defconst jtemplate-regexp-package-name "^\\(.*\\.\\)*\\([^.]+\\)")
;; Regular expression for package declaration
(defconst jtemplate-regexp-package-expr "^package[ ]*\\(.*\\);$")
;; Regular expression for "extends" or "implements"
(defconst jtemplate-regexp-extends-implements "\\([^, ]*\\.\\)+\\([^, ]+\\)")
;; Regular expression for extracting an "extends" or "implements" class item
(defconst jtemplate-regexp-extends-implements-class "\\([^, ]*\\.\\)*\\([^, ]+\\)")
;; Regular expression for class or interface
(defconst jtemplate-regexp-class "class\\|interface[ ]*[.]*{")
;; Regular expression for tag
(defconst jtemplate-regexp-tag "<\\(data\\|action\\):\\([a-Z\-]*\\)>")
;; Regular expression for data tag
(defconst jtemplate-regexp-data-tag "<data:\\([a-Z\-]*\\)>")
;; Regular expression for action tag
(defconst jtemplate-regexp-action-tag "<action:\\([a-Z\-]*\\)>")

;; Default class name if no name is defined
(defconst jtemplate-default-class-name "MyClass")
;; Default package name if no package is defined
(defvar jtemplate-default-package-name "mypackage")
;; Enabled jtemplate to use the current buffer's package value as the default package
(defconst jtemplate-enabled-buffer-package-name t)

;; Line
(defconst RC "\n")

;; Error message for existing class
(defconst ERROR_MSG1 "This %s '%s' already exists !")
;; Default value for unknown tag
(defconst JTEMPLATE_TAG_DEFAULT_VALUE "")
(defconst JTEMPLATE_JAVA_METHOD_FORMAT " {\n}\n")

;; Opensource Header added
(defvar jtemplate-opensource-enabled nil)
;; Static properties list
(defvar jtemplate-static-properties-list nil
  "Static properties\nLook at `jtemplate-add-static-property'")

(defvar jtemplate-opensource-message "/* This program is free software; you can redistribute it and / or
   modify it under the terms of the GNU General Public License as
   published by the Free Software Foundation; either version 2, or 
   (at your option) any later version.
*/\n\n")

(defvar jtemplate-main-enabled nil)

(defgroup jtemplate nil
  "Java Helper for class building\nC-j c : Build a new class (use full class name)\n
C-j i : Build a new interface (use full interface name)
C-j p : Set a default package name
C-j o : Enabled/Disabled open source header
C-j m : Enabled/Disabled main method
C-j v : Show the jtemplate version\n"
  :group 'tools
  :prefix "jtemplate-")

;; Opensource header
(defcustom jtemplate-custom-opensource-message "//..."
  "Open source header"
  :group 'jtemplate
  :type 'string
  :initialize 'custom-initialize-default 
  :get '(lambda(sym)
 	  jtemplate-opensource-message)
  :set '(lambda(sym val)
	  (setq jtemplate-opensource-message val)))

;; Interface model
(defcustom jtemplate-custom-interface-model "//..."
  "Interface model"
  :group 'jtemplate
  :type 'string
  :initialize 'custom-initialize-default 
  :get '(lambda(sym)
 	  jtemplate-basic-model-rendering)
  :set '(lambda(sym val)
	  (setq jtemplate-basic-model-rendering val)))

;; Class model
(defcustom jtemplate-custom-class-model "//..."
  "Interface model"
  :group 'jtemplate
  :type 'string
  :initialize 'custom-initialize-default 
  :get '(lambda(sym)
 	  jtemplate-basic-model-class-rendering)
  :set '(lambda(sym val)
	  (setq jtemplate-basic-model-class-rendering val)))

;; Available tags for models :
;; MAIN
;; PACKAGE 
;; ITEM = interface | class
;; EXTENDS
;; IMPLEMENTS
;; USER-MAIL author mail
;; USER-NAME author name
;; TIME current date & time
(defvar jtemplate-basic-model-rendering "<data:OPENSOURCE>package <data:PACKAGE>;

<data:IMPORT>
/**
 * <b>Created <data:TIME></b>
 * <p>
 * Comments
 * </p>
 * @author <data:USER-NAME> (<data:USER-MAIL>)
 * @version 1.0<data:SEE>
 */
public <data:ITEM> <data:NAME> <data:EXTENDS>{
  <action:CURSOR>
  <action:INDENT>
}

// <data:NAME> ends here
")

;; Basic model for class rendering
(defvar jtemplate-basic-model-class-rendering "<data:OPENSOURCE>package <data:PACKAGE>;

<data:IMPORT>
/**
 * <b>Created <data:TIME></b>
 * <p>
 * Comments
 * </p>
 * @author <data:USER-NAME> (<data:USER-MAIL>)
 * @version 1.0<data:SEE>
 */
public <data:ITEM> <data:NAME> <data:EXTENDS><data:IMPLEMENTS>{
  public <data:NAME>() {
   super();   
  }
  <action:CURSOR>  <action:INDENT>
  <data:METHODS>
  <data:MAIN>
}

// <data:NAME> ends here
")

;; Key map 
(setq jtemplate-map (make-keymap))
(define-key jtemplate-map "c" 'jtemplate-make-class)
(define-key jtemplate-map "i" 'jtemplate-make-interface)
(define-key jtemplate-map "v" 'jtemplate-show-version)
(define-key jtemplate-map "p" 'jtemplate-set-default-package)
(define-key jtemplate-map "m" 'jtemplate-main)
(define-key jtemplate-map "o" 'jtemplate-opensource)
(define-key global-map "\C-ck" jtemplate-map)

;; Menu
(if (require 'easymenu nil t)
    (progn
      (easy-menu-add-item nil '("tools") "--")
      (easy-menu-add-item nil '("tools")
	  '("Java Template"
	   [ "Make class" jtemplate-make-class t ]
	   [ "Make interface" jtemplate-make-interface t ]
	   [ "Open source header" jtemplate-opensource t ]
	   [ "Main method" jtemplate-main t ]
	   [ "Default Package" jtemplate-set-default-package t ]
	   [ "Version" jtemplate-show-version t ]
	   ))))

;; Build an class with the basic-model-rendering
(defun jtemplate-basic-make-class(type package item-name extends implements constructor)
  "Make a buffer and set a public type"
  (let ((file-name (concat item-name ".java")))
    (if (jtemplate-checkForValidItem file-name)
	(let ((buffer (get-buffer-create file-name)) ) 
	  (set-buffer buffer)
	  (jtemplate-switch-to-java-mode)
	  (let* (
		 (all_extends extends)
		 (all_implements implements)
		 (properties (jtemplate-make-dynamic-properties-list package type item-name all_extends all_implements)))
	    (progn
	      (jtemplate-item-rendering properties (jtemplate-decideForModel type item-name))
	      (switch-to-buffer file-name)
	      (set-visited-file-name file-name)))))))

;; Build dynamic properties list depending on input data
(defun jtemplate-make-dynamic-properties-list(package type item extends implements)
  (jtemplate-start-plugin)
  (let ((dynamic-list jtemplate-static-properties-list))
    (setq dynamic-list (cons '("PACKAGE" package) dynamic-list))
    (setq dynamic-list (cons '("ITEM" type) dynamic-list))
    (setq dynamic-list (cons '("NAME" item) dynamic-list))
    (setq dynamic-list (cons '("EXTENDS" (jtemplate-extract-extends-class extends)) dynamic-list))
    (setq dynamic-list (cons '("IMPLEMENTS" (jtemplate-extract-implements-class implements)) dynamic-list))
    (setq dynamic-list (cons '("SEE" (jtemplate-get-see extends implements)) dynamic-list))
    (let* ((data-list (jtemplate-extract-methods implements))
	   (methods-list (nth 1 data-list))
	   (imports-list (nth 0 data-list))
	   (extra-data-list (jtemplate-extract-local-interface-methods implements type))
	   (extra-methods-list (nth 1 extra-data-list))
	   (extra-imports-list (nth 0 extra-data-list)))
      (if extra-methods-list
	  (if (not (string= "" extra-methods-list))
	      (setq methods-list (concat methods-list extra-methods-list))))
      (if extra-imports-list
	  (if (not (string= "" extra-imports-list))
	      (setq imports-list (concat imports-list extra-imports-list))))
      (setq dynamic-list (cons '("METHODS" methods-list) dynamic-list))
      (if (or (not (string= "" extends)) (not (string= "" implements)))
	  (setq dynamic-list (cons '("IMPORT" (jtemplate-extract-import extends implements imports-list)) dynamic-list)))
    (mapcar '(lambda(x) (cons (car x) (cons (eval(nth 1 x)) nil))) dynamic-list))))

;; Get all local methods and tied package matching each interface from the wizard
(defun jtemplate-extract-local-interface-methods(implements type)
  (if (string= "class" type)
      (let ((search-at 0) (all-method-import nil) (all-methods nil) (all-imports nil))
	(while (string-match jtemplate-regexp-extends-implements-class implements search-at)
	  (setq search-at (match-end 0))
	  (setq result (match-string 2 implements))
	  (let ( (temp (jtemplate-extract-local-interface-methods-content result)) ) 
	    (if temp 
		(let ( (all-import (nth 0 temp)) (all-method (nth 1 temp)) )
		  (setq all-imports (concat all-imports all-import))
		  (setq all-methods (concat all-methods all-method))))))
	(cons all-imports (cons all-methods nil)))
    nil))

;; Get methods for one interface
(defun jtemplate-extract-local-interface-methods-content(interface)
  (let ( (buffers-ok (buffer-list)) 
	 local-buffer 
	 interface-regexp 
	 (result-methods "") 
	 (result-imports "")
	 (interface-regexp (concat "interface[]+" interface "[ \n]*[^{]*{")))
    ;; Walk through available buffers
    (while buffers-ok
      (setq local-buffer (car buffers-ok))
      (setq buffers-ok (cdr buffers-ok))
      (set-buffer local-buffer)
      ;; Search for the interface
      (save-excursion
	(widen)
	(goto-char (point-min))
	(if (re-search-forward interface-regexp nil t)
	    ;; Seach for public methods 
	    (let ( (method-regexp "\\(public[ ]*[^;]+\\);") 
		   (import-regexp "import[ ]+\\([^;]+\\);")
		   (package-regexp "package[ ]+\\([^;]+\\);") )
	      (while (re-search-forward method-regexp nil t)
		(setq result-methods (concat (match-string 1) JTEMPLATE_JAVA_METHOD_FORMAT result-methods)))
	      ;; Search for Import
	      (goto-char (point-min))
	      (while (re-search-forward import-regexp nil t)
		(setq result-imports (concat "import " (match-string 1) ";\n" result-imports)))
	      ;; Search for Package
	      (goto-char (point-min))
	      (if (re-search-forward package-regexp nil t)
		  (setq result-imports (concat "import " (match-string 1) ".*;\n" result-imports)))))))
      (cons result-imports (cons result-methods nil))))

;; Build a list of "@see" tag from "extends" and "implements" expression
(defun jtemplate-get-see(extends implements)
  (let ((search-at 0) (result "") (pattern (concat extends " " implements)))
    (while (string-match jtemplate-regexp-extends-implements-class pattern search-at)
      (setq search-at (match-end 0))
      (setq result (concat result "\n * @see " (match-string 2 pattern))))
    result))

;; Get the package of the "extends" and the "implements" and build a list of import for the IMPORT tag
(defun jtemplate-extract-import(extends implements import-db)
  (let ((search-at 0) (import-class (concat extends " " implements " " import-db)) (result "") (temp-list nil))
    (while (string-match jtemplate-regexp-extends-implements import-class search-at)
      (setq search-at (match-end 0))
      (let ((import (match-string 1 import-class)))
	(if (null (member import temp-list))
	(setq result (concat result "import " import "*;\n")))
	(setq temp-list (cons import temp-list))))result))

;; Get the classes from the full classes name
(defun jtemplate-extract-extends-class(extends)
  (let ((search-at 0) (result ""))
    (while (string-match jtemplate-regexp-extends-implements-class extends search-at)
      (setq search-at (match-end 0))
      (setq result (concat result (if (not (string= "" result)) ",") (match-string 2 extends))))
    (if (string= result "") "" (concat "extends " result " "))))

;; Get the interfaces from the full interfaces name
(defun jtemplate-extract-implements-class(implements)
  (if (not (null implements))
  (let ((search-at 0) (result ""))
    (while (string-match jtemplate-regexp-extends-implements-class implements search-at)
      (setq search-at (match-end 0))
      (setq result (concat result (if (not (string= "" result)) ",") (match-string 2 implements))))
    (if (string= result "") "" (concat "implements " result " " )))))

;; Decide the model depending the type and the name
(defun jtemplate-decideForModel(type item-name)
  (if (string= "interface" type)
      (jtemplate-decideForInterfaceModel item-name)
    (jtemplate-decideForClassModel item-name)))

;; Decide the model depending of the current class name 
(defun jtemplate-decideForClassModel(item-name)
  jtemplate-basic-model-class-rendering)

;; Decide the model depending of the current interface name 
(defun jtemplate-decideForInterfaceModel(item-name)
  jtemplate-basic-model-rendering)

;; Check for valid item name. For the moment we control if the class name
;; exist in the buffer list, if true we don't authrorized user to make it.
(defun jtemplate-checkForValidItem(item-name)
  (if (get-buffer item-name)
      (progn
	(message ERROR_MSG1  type item-name )
	nil)
    t))

;; Set the java-mode if needed
(defun jtemplate-switch-to-java-mode()
  (if (not (string= mode-name jtemplate-java-mode-name))
      (java-mode)))

;; Render the model with value
;; we replace rendering-model tag with available
;; list-data value
(defun jtemplate-item-rendering( list-data rendering-model )
  "Item rendering in current buffer"
  (jtemplate-item-body-rendering list-data rendering-model))

;; Rendering for the body depending on the model
(defun jtemplate-item-body-rendering( list-data rendering-model ) 
  (insert (jtemplate-model-processing list-data rendering-model 0))
  (jtemplate-buffer-action-processing))

;; Search for all action
(defun jtemplate-buffer-action-processing()
  (goto-char (point-min))
  (while (re-search-forward jtemplate-regexp-action-tag nil t)
    (let ( (start (match-beginning 0))
	   (end (match-end 0))
	   (action (match-string 1)))
      (delete-region start end)
      (jtemplate-initialize-action action)
      (goto-char (1+ (point)))
      ))
  (jtemplate-terminate-actions))


;; Initialize action once
(defun jtemplate-initialize-action( action )
  (let ((action-name (downcase action)))
    (funcall (intern (concat "jtemplate-action-" action-name "-init")))))

;; Search for all data tag in the current model 'rendering-model'
;; Replace with a value from the 'list-data' else a default value is set
(defun jtemplate-model-processing( list-data rendering-model loc)
   ;; Search for the first tag from the rendering-mode
   (let* (
	  (start-tag (string-match jtemplate-regexp-data-tag rendering-model loc))
	  (result-model "")
	  (last-match 0))
     (while start-tag 
       (let* (
	     (end-tag (match-end 0))
	     (full-tag-name (match-string 0 rendering-model))
	     (tag-name (match-string 1 rendering-model))
	     (prev-tag-model (substring rendering-model 0 start-tag))
	     (tag-value (jtemplate-tag-value list-data tag-name))
	     (end-tag-model (substring rendering-model end-tag (length rendering-model))) )

	 (setq result-model (concat result-model (substring rendering-model last-match start-tag) tag-value))

	 (setq last-match end-tag)
	 (setq start-tag (string-match jtemplate-regexp-data-tag rendering-model end-tag))

	 (if (not start-tag)
	     (setq result-model (concat result-model end-tag-model))) ))
     result-model))


;; Search for a tag value in list-data depending on tag-name as key
;; If the key is not found a default value 'JTEMPLATE_TAG_DEFAULT_VALUE' is returned
(defun jtemplate-tag-value( list-data tag-name )
  (if (null list-data)	
      JTEMPLATE_TAG_DEFAULT_VALUE
    (let ((value (nth 1 (assoc tag-name list-data ))))
      (if (null value)
	  JTEMPLATE_TAG_DEFAULT_VALUE
	value))))

;; Rendering for footer
(defun jtemplate-item-footer-rendering())

;; Get the class name from a full name with package
(defun jtemplate-extract-class-name(full-name)
(if (string-match jtemplate-regexp-class-name full-name nil)
    (let ( (start (match-beginning 2)) (end (match-end 2)))
      (substring full-name start end))
    jtemplate-default-class-name))

;; Get the package from a full name
(defun jtemplate-extract-package-name(full-name)
(if (string-match jtemplate-regexp-package-name full-name nil)
    (if (match-end 1)
	(let ( (start (match-beginning 1)) (end (1- (match-end 1) )) )
	       (substring full-name start end))
      (jtemplate-default-package-name))
  (jtemplate-default-package-name)))

;; Return a default package name or the current buffer's package
(defun jtemplate-default-package-name()
  (let ( (package (jtemplate-extract-buffer-package-name)) )
    (if package package
      jtemplate-default-package-name)))

;; Search from the current package name
(defun jtemplate-extract-buffer-package-name()
  (save-excursion
    (save-restriction
      (save-match-data
	(widen)
	(goto-char (point-min))
	(if ( re-search-forward jtemplate-regexp-package-expr nil t) 
	    (match-string 1)
	  nil)))))

;; Extract methods for all implements from the jtemplate-db file
(defun jtemplate-extract-methods(implements)
  (if (or (null implements) (string= "" implements))
      (cons "" (cons "" nil))
    (let ( (result nil) )
      (if (require 'jtemplate-db nil t)	; Load the database if available
	  (let ((search-at 0) (result-method "") (result-import "") (implement))
	    (while (string-match jtemplate-regexp-extends-implements-class implements search-at)
	      (setq search-at (match-end 0))
	      (setq implement (match-string 2 implements))
	      (let ( (temp (jtemplate-extract-imports-methods-from-interface implement)) )
		(if temp 
		    (progn
		      (setq result-method (concat result-method (nth 1 temp )))
		      (setq result-import (concat result-import (nth 0 temp )))
		      (setq result (cons result-import (cons result-method nil)))
		  ))))) nil)
      result
     )))

;; Extract methods for one implement from the `jtemplate-db' file
(defun jtemplate-extract-imports-methods-from-interface(implement)
  (let ((assoc-item (assoc implement jtemplate-db)))
  (if assoc-item
      (let ((imports (jtemplate-extract-import-from-database-item assoc-item))
	    (methods (jtemplate-extract-method-from-database-item assoc-item)))
	(cons imports (cons methods nil)))
    nil)))

;; Extract each method import from an item of the `jtemplate-db' table
(defun jtemplate-extract-import-from-database-item(list)
  (let ((methods (nth 1 list)) (counter 0) (result ""))
    (while (<= counter (1- (length methods)))
      (setq result (concat result (nth counter methods) "," ))
      (setq counter (1+ counter))) result))

;; Extract each method line from an item of the `jtemplate-db' table
(defun jtemplate-extract-method-from-database-item(list)
  (let ((methods (nth 2 list)) (counter 0) (result ""))
    (while (<= counter (1- (length methods)))
      (setq result (concat result (nth counter methods) JTEMPLATE_JAVA_METHOD_FORMAT ))
      (setq counter (1+ counter))) result))

;; Default methods when implementation is not found in the `jtemplate-db' file
(defun jtemplate-default-methods-from-interface(implement)
  (concat "// " implement "\n"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Plug-ins section
;; This section contains extension for tags or models
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Static properties extension
;; Arguments : 
;; - property-name : a tag name
;; - property-value : any symbol that can be evaluated
(defun jtemplate-add-static-property(property-name property-value)
  (let ( (value JTEMPLATE_TAG_DEFAULT_VALUE) )
    (progn
      (if (null property-value)
	  (setq value JTEMPLATE_TAG_DEFAULT_VALUE)
	(setq value (eval property-value)))
      (let ( (list-item (cons property-name (cons value nil))))
	(if (null (assoc property-name jtemplate-static-properties-list))
	    (setq jtemplate-static-properties-list (cons list-item jtemplate-static-properties-list))
	  (let ((sublist (assoc property-name jtemplate-static-properties-list)))
	    (if sublist 
		(setcdr sublist (cons value nil)))))))))

;; Static properties remove
;; Arguments :
;; - property-name : a tag name
(defun jtemplate-remove-static-property(property-name)
  (let ( (sublist (assoc property-name jtemplate-static-properties-list)))
    (if sublist 
	(setq jtemplate-static-properties-list (jtemplate-remove-property property-name jtemplate-static-properties-list)))))

;; Tool for remove a (property value)
(defun jtemplate-remove-property(property-name list) 
  (let ( (first (car list)) (last (cdr list)) (property nil))
    (progn
      (setq property (car first))
      (if (string= property property-name)
	  last
	(cons first (jtemplate-remove-property property-name last))))))

;; Default plugIns
(defun jtemplate-start-plugin()
  (jtemplate-add-static-property "USER-MAIL" 'user-mail-address)
  (jtemplate-add-static-property "USER-NAME" 'user-full-name)
  (jtemplate-add-static-property "TIME" (current-time-string)))

;; Actions

;; Terminate all action
(defun jtemplate-terminate-actions()
  (cond
   ( (not (null jtemplate-action-cursor-data)) (goto-char jtemplate-action-cursor-data))))

;; Cursor action
(defvar jtemplate-action-cursor-data nil)
(defun jtemplate-action-cursor-init()
  (setq jtemplate-action-cursor-data (point)))
;; Indent action
(defun jtemplate-action-indent-init()
  (c-indent-defun))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Interactive section
;; This section contains all user interaction with jtemplate
;; mainly `jtemplate-make-class' and `jtemplate-make-interface'
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Build a class
(defun jtemplate-make-class(class-name extends implements &optional p)
  "Make a buffer with a public class"
  (interactive "sClass Name :\nsExtends :\nsImplements :\nP")
  (jtemplate-basic-make-class "class"
			      (jtemplate-extract-package-name class-name)
			      (jtemplate-extract-class-name class-name)
			      extends 
			      implements
			      p))

;; Build an interface
(defun jtemplate-make-interface(interface-name extends &optional p)
  "Make an buffer with an interface"
  (interactive "sInterface Name :\nsExtends :\nP" )
  (jtemplate-basic-make-class "interface"
			      (jtemplate-extract-package-name interface-name)
			      (jtemplate-extract-class-name interface-name)
			      extends
			      nil
			      p))

;; Set the default package name
(defun jtemplate-set-default-package(current-package)
  "Define the current package for item rendering"
  (interactive "sChoose a default package:\n" )
  (setq jtemplate-default-package-name current-package))

;; Enabled/Disabled the opensource header
(defun jtemplate-opensource()
  "Enabled the opensource header in classes"
  (interactive)
  (setq jtemplate-opensource-enabled (not jtemplate-opensource-enabled))
  (message "%s" (if jtemplate-opensource-enabled "Opensource header enabled" "Opensource header disabled"))
  (if jtemplate-opensource-enabled 
      (jtemplate-add-static-property "OPENSOURCE" jtemplate-opensource-message)
    (jtemplate-remove-static-property "OPENSOURCE")))

;; Enabled/Disabled the main method
(defun jtemplate-main()
  "Enabled a main method in classes"
  (interactive)
  (setq jtemplate-main-enabled (not jtemplate-main-enabled))
  (message "%s" (if jtemplate-main-enabled "Main method enabled" "Main method disabled"))
  (if jtemplate-main-enabled 
      (jtemplate-add-static-property "MAIN" "public static void main( String[] args ) {\n}")
    (jtemplate-remove-static-property "MAIN")))

;; Jtemplate version
(defun jtemplate-show-version()
  (interactive)
  (message jtemplate-version))

(provide 'jtemplate)

;;; jtemplate.el ends here
