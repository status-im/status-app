{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation rec {
  pname = "fileicon";
  version = "0.3.5";

  src = fetchFromGitHub {
    owner = "mklement0";
    repo = "fileicon";
    rev = "v${version}";
    hash = "sha256-dFyQYJA/eVgnlfOhD4u/R0HnQieKadW1noY88ve5AAM=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/fileicon $out/bin/fileicon
    install -Dm644 man/fileicon.1 $out/share/man/man1/fileicon.1

    runHook postInstall
  '';

  meta = {
    description = "macOS CLI for managing custom icons for files and folders";
    homepage = "https://github.com/mklement0/fileicon";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    mainProgram = "fileicon";
  };
}
