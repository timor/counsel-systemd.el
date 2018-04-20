;;; counsel-systemd.el --- ivy-based interface to systemd units

;; unlicensed

;; Author: timor <timor.dd@googlemail.com>
;; Version: 0.1.1
;; Package-Requires: (counsel dbus)
;; URL: http://github.com/timor/counsel-systemd.el
;; Keywords: convenience

;;; Commentary:

;;; Code:
(require 'counsel)
(require 'dbus)

;;;###autoload
(defun counsel-journalctl (&optional user-mode)
  "Manage systemd units"
  (interactive "P")
  (counsel-require-program "systemctl")
  (let ((units
         (mapcar (lambda (x)
                   (let ((name (first x))
                         (state (fourth x)))
                     (cond ((string-equal state "failed")
                            (propertize name 'face 'error))
                           ((string-equal state "inactive")
                            (propertize name 'face 'shadow))
                           (t name))))
                 (sort (dbus-call-method (if user-mode :session :system) "org.freedesktop.systemd1" "/org/freedesktop/systemd1" "org.freedesktop.systemd1.Manager" "ListUnits")
                       (lambda (a b)
                         (let ((failed-a (string-equal (fourth a) "failed"))
                               (failed-b (string-equal (fourth b) "failed")))
                           (cond ((and failed-a failed-b)
                                  (string-lessp (first a) (first b)))
                                 (failed-a t)
                                 (failed-b nil)
                                 (t (string-lessp (first a) (first b))))))))))
    (ivy-read "Systemd Unit:" (remove-if-not (lambda (x)
                                               (member (car (last (split-string x "\\."))) '("service" "timer")))
                                             units)
              :caller 'counsel-journalctl
              :action (lambda (x)
                        (let* ((buffer-name (format "*journalctl %s*" x))
                               (buffer (get-buffer buffer-name)))
                          (if buffer
                              (pop-to-buffer buffer)
                            (let ((args `("--no-tail" "-f" "-b" "-u" ,x)))
                              (apply #'start-process (concat "journalctl-" x) (setq buffer (generate-new-buffer buffer-name)) "journalctl" (if user-mode (cons "--user" args) args))
                             (with-current-buffer buffer
                               (view-mode))
                             (pop-to-buffer buffer)))))

              :sort t
              :require-match t)))
