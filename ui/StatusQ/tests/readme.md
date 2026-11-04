# Readme

## Developer instructions

CMake

```sh
cd ./tests/
cmake -B ./build/ -S .
cmake --build ./build/
ctest --test-dir ./build/
```

QtCreator

- Open the `./tests/CMakeLists.txt`
- Choose a QT kit to run the tests
- Set `%{sourceDir}/tests` as Working Directory for the TestStatusQ target
- In the *Test Results* panel choose Run All Tests or just run the *TestStatusQ* target

### Spell-check tests and login benchmark

With StatusQ configured using `STATUSQ_BUILD_TESTS=ON`, build and run the focused tests:

```sh
cmake --build <build-dir> --target TestLanguageService TestSpellChecker
ctest --test-dir <build-dir> -R '^(TestLanguageService|TestSpellChecker)$' --output-on-failure
<build-dir>/bin/TestLanguageService benchmarkLogin -iterations 10000 -median 5
```

`benchmarkLogin` measures a fresh `LanguageService` plus setting `userUID`, including
language discovery and settings loading. Run the same benchmark before and after a
change; it intentionally excludes asynchronous first-use dictionary extraction and
Hunspell loading. The worker tests cover lazy extraction, cached pairs shared by
editors, filesystem dictionaries, and extraction failures. Ensure the executable
loads the build-tree StatusQ library, not an installed copy (on Linux, set
`LD_LIBRARY_PATH=<build-dir>/lib` if necessary).

## TODO

- [ ] TestHelpers library
- [ ] Consolidate and integrate with https://github.com/status-im/desktop-ui-tests
- [ ] Separate projects per scope: TestControls, TestComponents
