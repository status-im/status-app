## The Qt application object of a test program. A process can have only one,
## and tests built into one program share it.

from seaqt/qcoreapplication import QCoreApplication, create, instance

var app: QCoreApplication  # owns the application until the program ends

proc ensureQtCoreApp*() =
  ## Creates the QCoreApplication unless the process already has one.
  if QCoreApplication.instance().h.isNil:
    app = QCoreApplication.create()
