# Building Storybook

For regular usage of **Storybook** it's enough to open `status-desktop/storybook/CMakeLists.txt` in QtCreator. Please **`do not use StoryBook.pro`** which is intended for WebAssembly builds. Please make sure that selected run target is `Storybook`.

Storybook may run in two modes (configurable by `-m`/`--mode` command line argument):
- **local** - in this mode local filesystem is observed directly and when change detected the page is unloaded, qml cache is cleaned and page is loaded again
- **remote** - in this mode the both change detection and qml files access is done via http server. It allows exposing local source code to remote devices

On desktop both modes work basically in the same way from the user perspective.

In order to run Storybook it's necessary to use remote mode:
- connect device
- start Storybook locally in remote mode
- set up reverse proxy (`adb reverse tcp:8080 tcp:8080`)
- run the Storybook on the device

For convenience the setup of reverse proxy can be easily added to the config
in QtCreator as a deployment step (`Custom Process Step`).

## Exercising desktop restart

Launch `Storybook ConfirmChangePasswordModal --mode local`. In the controls
panel, leave **Success in 2 seconds** enabled and disable **Fast password change
possible (DEK)** (or select the modal's rekey checkbox). Submit the password
change, wait for the simulated success, and click **Restart Status**.

This calls `SystemUtils.restartApplication(true)` without a backend and restarts
the Storybook executable, not an installed Status app. The positional page and
`--mode` arguments are preserved, so the replacement opens the same page.
Desktop restart is deferred until the application object is destroyed; application
owners must finish backend shutdown and release single-instance resources before
destroying that object. Logs record when the restart is scheduled and the
replacement process PID; launch failures are logged as critical errors.
The replacement's standard streams are redirected to the null device so closing
the launcher's output pipes (for example, Qt Creator's) cannot terminate it.
Replacement console output will not appear in the original run output.

## Benchmarks

`qmlTests/benchmarks/bench_*.qml` measure what N instances of a component
cost: GPU memory and RSS added, build time, and GPU and CPU time per frame
while the scene is redrawn, scrolled, resized or animating
(`Benchmark.BenchmarkRunner`). They are not part of the test run (their names
do not start with `tst_`). `run_benchmark.py` runs each variant in its own
`QmlTests` process in a real window, at several scale factors and repeatedly,
and prints a comparison table:

```
qmlTests/benchmarks/run_benchmark.py run qmlTests/benchmarks/bench_Foo.qml \
    --variant a --scales 1 2 --runs 3 --label before --out before.json
# ...change the component, rebuild if C++ changed...
qmlTests/benchmarks/run_benchmark.py run ... --label after --out after.json
qmlTests/benchmarks/run_benchmark.py table before.json after.json
```

GPU figures come from the DRM fdinfo (Linux, i915/xe/amdgpu and others);
elsewhere they read `n/a`. Keep the screen unlocked and awake: a run that
presents too few frames is marked invalid and retried.


# Building Storybook with Webassembly and Qt 5.14

> [!WARNING]
> Both support for Webassembly and the instruction below are not maintained and
> won't work out of the box. Please use the standard build/deploy method.

## Configuring the environment
### Install Emscripten v1.38.27
	

    # Get the emsdk repo
    git clone https://github.com/emscripten-core/emsdk.git
    
    #go to emsdk folder
    cd emsdk
    
    #install Emscripten v1.38.27
    ./emsdk install emscripten-1.38.27
    
    #activate emscripten-1.38.27
    ./emsdk activate emscripten-1.38.27
    
    #install Fastcomp backend
    ./emsdk install fastcomp-clang-tag-e1.38.27-64bit
    
    #activate Fastcomp backend
    ./emsdk activate fastcomp-clang-tag-e1.38.27-64bit
    
    #add emsdk tools to env variables
    #this can be done by following instructions received from previous activate command
    #there are two options:
    
    #1. Configure the env variables for the current shell only:
    source emsdk_env.sh
    
    #2. Configure the env variables using the shell startup script:
    echo 'source "[path to emsdk folder]/emsdk_env.sh"' >> $HOME/.zprofile
    
    #WARNING: this will configure the environment to use the emsdk compiler
    #Ex:"which clang" command will now point to the emscripten clang instead of the system clang
    #to disable the env configuration comment the source command added earlier in ~/.zprofile
    
    #check environment
    #python needs to be installed. The emsdk scripts state that it should work with pyton 2 and 3
    #make sure python command can be resolved
    which python
    em++ --version
    emcc --version
    #clang should point to fastcomp-clang-tag-e1.38.27-64bit
    which clang
    which clang++
More documentation: https://emscripten.org/docs/getting_started/downloads.html

### Configure QtCreator (optional)
Newer versions of QtCreator won't support Qt5.14 with Webassembly. Latest version found to support Qt5.14 with WebAssembly is 4.14.2
Download: https://download.qt.io/archive/qtcreator/4.14/

Adding the Emscripten compilers (emcc and em++)
Details here: https://doc.qt.io/qtcreator/creator-tool-chains.html

Adding Qt version 5.14:
https://doc.qt.io/qtcreator/creator-project-qmake.html

Adding Qt5.14 for Webassembly kit:
https://doc.qt.io/qtcreator/creator-targets.html

Open StoryBook.pro in Qt Creator and configure it using the new kit.

Qt creator might not set the env paths correctly. In this case manually set build environment variables (Projects -> 5.14.2 kit -> Build -> Build Environment -> Batch edit). Ex:

    EMSCRIPTEN=~/Repos/emsdk/emscripten/1.38.27
    EMSDK=~/Repos/emsdk
    EMSDK_NODE=~/Repos/emsdk/node/14.18.2_64bit/bin/node
    EMSDK_PYTHON=~/Repos/emsdk/python/3.9.2_64bit/bin/python3
    EM_CONFIG=~/Repos/emsdk/.emscripten
    LLVM_ROOT=~/Repos/emsdk/fastcomp-clang/tag-e1.38.27/build_tag-e1.38.27_64/bin
    PATH=[check echo $PATH]

### Running qmake (without qt Creator)

    #create build folder
    mkdir buildStoryBook
    
    #go to folder
    cd buildStoryBook
    
    #run qmake (add CONFIG+=debug CONFIG+=qml_debug to qmake command for debug build)
    ~/Qt/5.14.2/wasm_32/bin/qmake [path to StoryBook.pro] -spec wasm-emscripten && /usr/bin/make qmake_all
    
    #build (add -j[nb of cores] for parallel execution)
    make
    
    #run
    emrun StoryBook.html
