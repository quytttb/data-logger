; ============================================================
; pysidedeploy.spec — Cấu hình Nuitka cho pyside6-deploy
; Build command (chạy trên Raspberry Pi 4 ARM64):
;   source .venv/bin/activate
;   pyside6-deploy -c pysidedeploy.spec --verbose
; ============================================================

[app]
title = Data Logger
input_file = main.py
exec_directory = dist
icon = assets/app-icon.svg

[python]
; Các package thuần-Python cần include (Nuitka không tự detect dynamic import)
packages = asyncssh,cryptography,pymodbus,sqlmodel,sqlalchemy,serial,bcrypt

[qt]
; Tất cả file QML (đường dẫn tương đối từ main.py)
qml_files = ui/qml/Main.qml,ui/qml/TesterView.qml,ui/qml/DashboardView.qml,ui/qml/HistoryView.qml,ui/qml/HistoryTaskBar.qml,ui/qml/ModbusTesterTaskBar.qml,ui/qml/SettingsView.qml,ui/qml/TesterConnectionTab.qml,ui/qml/TesterOperationsTab.qml

; Module Qt thực sự dùng (giảm kích thước binary)
modules = Quick,QuickControls2,Core,Gui,Qml,Concurrent,Network

; Loại bỏ module không cần thiết
excluded_qml_plugins = QtWebEngine,QtSensors,QtTest,QtQuick3D,QtCharts,QtLocation,QtPositioning,QtWebSockets,QtBluetooth,QtNfc,QtPdf,QtVirtualKeyboard,Qt3D

; Plugin platform cần thiết cho ARM64 Linux (xcb = X11, eglfs = framebuffer)
plugins = platforms,imageformats,iconengines,xcbglintegrations,generic

[nuitka]
; standalone = thư mục dist/DataLogger.dist/ (không cần giải nén, path ổn định)
; onefile   = 1 file .bin duy nhất (chậm khởi động hơn do phải giải nén vào /tmp)
mode = standalone

extra_args = --noinclude-qt-translations
             --lto=yes
             --jobs=4
             --quiet
             --include-package=core
             --include-package=models
             --include-package=ui
             --include-package=workers
             --include-data-dir=ui/qml=ui/qml
             --include-data-dir=assets=assets
