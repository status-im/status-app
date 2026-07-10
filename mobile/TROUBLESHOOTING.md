## Troubleshooting

### iOS Common Issues

1. **CMake Qt5 Error**
```
CMake Error at CMakeLists.txt:36 (find_package):
By not providing "FindQt6.cmake" in CMAKE_MODULE_PATH this project has
asked CMake to find a package configuration file provided by "Qt6", but
CMake did not find one.
```
**Fix**: Ensure `QTDIR` environment variable points to the Qt 6 installation folder.

2. **Python Interpreter Error**
```
ios/mkspecs/features/uikit/devices.py: /usr/bin/python: bad interpreter: No such file or directory
```
**Fix**: Update the Python path in `ios/mkspecs/features/uikit/devices.py`.

3. **Missing distutils**
```
ModuleNotFoundError: No module named 'distutils'
```
**Fix**: `pip install setuptools`

4. **Invalid CFBundleVersion**
```
Simulator device failed to install the application.
The application's Info.plist does not contain a valid CFBundleVersion.
```
**Fix**: Remove `bin/Status.app` and run `nim run status.nims` (the `make run`
targets were deleted in issue 0017 — the driver is the app's one front door)

5. **FBSOpenApplicationServiceErrorDomain**
```
Underlying error (domain=FBSOpenApplicationServiceErrorDomain, code=4):
```
**Fix**: In the simulator app, choose `Device -> Erase all content and settings`

### Android Common Issues

1.**PNG Rendering on macOS Emulator**
**Issue**: PNG files won't render on macOS emulator.
**Fix**: Add `setenv("QT_QUICK_BACKEND", "software", 1);` in main.cpp

2.**Gradle Crashes**
**Issue**: Gradle crashes during build.
**Fix**: Ensure sufficient RAM is available. A system restart may be needed.

3.**StatusQ Compilation Crashes**
**Issue**: Compiler crashes while compiling StatusQ.
**Fix**: Ensure at least 10GB of free RAM is available.

