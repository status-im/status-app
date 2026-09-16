{
  lib,
  stdenvNoCC,
  fetchurl,
}:
# nixpkgs at the flake's revision ships nimble 0.20.1; the upstream 0.24.1 release
# binary is packaged instead (it also materialises the pinned compiler itself).
let
  version = "0.24.1";
  assets = {
    x86_64-linux = {
      name = "nimble-linux_x64.tar.gz";
      hash = "sha256-W7zqKZn3m3pa/xQJ+ij/6tWVTlqkqHpQVaU1MNDWFd4=";
    };
    aarch64-linux = {
      name = "nimble-linux_aarch64.tar.gz";
      hash = "sha256-YBcSNYDBUSVs2CwBNVgMCeLuS7ujQCC+4AX1JVAh180=";
    };
    x86_64-darwin = {
      name = "nimble-macosx_x64.tar.gz";
      hash = "sha256-7ImEN4ylQJL76Oddb6MH65OID3HBe3cxPlioN6WmovQ=";
    };
    aarch64-darwin = {
      name = "nimble-macosx_aarch64.tar.gz";
      hash = "sha256-pLm0qY8Qn1uJFrvCrWfC3yIm//edKb29xRrLH8xY1BU=";
    };
  };
  system = stdenvNoCC.hostPlatform.system;
  asset =
    assets.${system}
      or (throw "nimble ${version}: no release asset for ${system}");
in
  stdenvNoCC.mkDerivation {
    pname = "nimble";
    inherit version;

    src = fetchurl {
      url = "https://github.com/nim-lang/nimble/releases/download/v${version}/${asset.name}";
      inherit (asset) hash;
    };

    # The tarball holds the bare binary, no top-level directory.
    sourceRoot = ".";
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      install -Dm755 nimble $out/bin/nimble

      runHook postInstall
    '';

    meta = {
      description = "Package manager for the Nim programming language";
      homepage = "https://github.com/nim-lang/nimble";
      license = lib.licenses.bsd3;
      platforms = builtins.attrNames assets;
      mainProgram = "nimble";
    };
  }
