{pkgs}: let
  # NOTE: llvm19+ has an issue with zxing-cpp
  # FIXME: compiler-rt fails on nixpkgs 26.05, try newer llvm
  # https://github.com/NixOS/nixpkgs/pull/523142
  llvm = pkgs.llvmPackages_18;
  mkShellDarwin = pkgs.mkShell.override {
    inherit (llvm) stdenv;
  };
  mkShell =
    if pkgs.stdenv.isDarwin
    then mkShellDarwin
    else pkgs.mkShell;
  qt6-env = with pkgs.qt6;
    env "qt6-env" [
      # build
      qtbase
      qtdeclarative
      qtmultimedia
      qtsvg
      qttools
      qtwebchannel
      qtwebengine
      qtwebview
      # runtime
      qt5compat
      qtscxml
      # storybook
      qthttpserver
      qtwebsockets
      # statusq-tests
      qtpositioning
    ];
in
  mkShell {
    packages = with pkgs;
      [
        # FIXME: qt6 is broken in nixpkgs 26.05
        qt6-env       # 6.11.0
        cmake         # 4.1.2
        gcc14         # gcc11 in build image, but qt6 from cache requires gcc14
        git
        go-bindata
        go_1_26       # 1.26.3
        libglvnd
        mockgen       # v0.6.0
        nim           # 2.2.4
        openssl
        pcre
        pkg-config
        protobuf_21
        protoc-gen-go # v1.36.11
        which
        curl
        gnumake
        # system gmake can cause issues
        (pkgs.runCommand "gmake-compat" {} ''
          mkdir -p $out/bin
          ln -s ${pkgs.gnumake}/bin/make $out/bin/gmake
        '')
      ]
      ++ pkgs.lib.optionals pkgs.stdenv.isDarwin (with pkgs; [
        # TODO: pin apple-sdk version
        unstablePkgs.python313Packages.dmgbuild
        fileicon
      ])
      ++ pkgs.lib.optionals pkgs.stdenv.isLinux (with pkgs; [
        # Darwin requires system pcsclite for keycard-go
        pcsclite # version? need 2.2.3
        # nixGLIntel works in pure shell
        # auto.nixGLDefault requires impure shell
        nixgl.nixGLIntel
        libxkbcommon # Qt6GuiPrivate
      ]);

    shellHook = ''
      case "$OSTYPE" in
        darwin*)
          # nix stdenv adds find incompatible with macos build
          export PATH="/usr/bin:$PATH"
          ;;
      esac

      # Sanitizing env vars enforcing Go to use Nix provided toolchain
      # GOPATH, GOCACHE, GOMODCACHE will be used from user home (impure shell?)
      unset GOROOT
      export GOENV=off
      export GOTOOLCHAIN=local
    '';

    # NOTE: LD_LIBRARY_PATH is a last resort tool
    # Prefer binary RPATH, which is easy to fix with mkDerivation
    LD_LIBRARY_PATH = with pkgs;
      lib.makeLibraryPath [
        # NOTE: RPATH is missing it
        openssl
      ];

    # NOTE: smth incorrectly sets import path during build time, this is a workaround
    # QML_IMPORT_TRACE=1
    # qt.qml.import: addImportPath: "/nix/store/5q4mjar3r9v4drb7wv4rfrw2cgpdp8b4-qtbase-6.9.3/lib/qt-6/qml"
    QML_IMPORT_PATH = "${qt6-env}/lib/qt-6/qml";
  }
