{
  description = "Status Desktop build tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems f;
    in {
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          jdk = pkgs.jdk; # keycard simulator precompile (USE_SIMULATED_KEYCARD packages)
        } // nixpkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
          dmgbuild = pkgs.python3Packages.dmgbuild.overrideAttrs (old: rec {
            version = "1.6.7";
            src = pkgs.fetchPypi {
              pname = "dmgbuild";
              inherit version;
              hash = "sha256-Z2sXrNRIiZ9tSoOyGE4GV0gEROy2rJxJIoie+tnl2/s=";
            };
          });
        }
      );
    };
}
