{
  description = "Fastlane environment for iOS signing";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux" "aarch64-linux"
        "x86_64-darwin" "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
      pkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor.${system};
          # Pin Ruby 3.1 for fastlane
          ruby = pkgs.ruby_3_1;
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              ruby
              pkgs.git
              pkgs.openssh
              pkgs.openssl
              pkgs.cacert
              pkgs.curl
              pkgs.pkg-config
              pkgs.libyaml
            ];

            shellHook = ''
              export GEM_HOME="$PWD/.gems"
              export GEM_PATH="$GEM_HOME"
              export PATH="$GEM_HOME/bin:$PATH"
              export LANG="en_US.UTF-8"

              unset BUNDLE_PATH
              unset BUNDLE_GEMFILE

              echo "Ruby $(ruby --version)"
              echo "Bundler $(bundle --version)"
              echo ""
              echo "Installing fastlane dependencies..."
              # Build native gem extensions against nix's apple-sdk, NOT host Xcode.
              # Host Xcode 26 SDK headers break Ruby 3.1's mkmf probes.
              ( unset DEVELOPER_DIR SDKROOT; bundle install )

              export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

              # fastlane resign needs xcode tools in shell
              XCODE_WRAPPER_DIR=$(mktemp -d)
              for tool in xcrun codesign security xcodebuild plutil; do
                ln -sf /usr/bin/$tool "$XCODE_WRAPPER_DIR/$tool" 2>/dev/null || true
              done
              export PATH="$XCODE_WRAPPER_DIR:$PATH"
            '';
          };
        }
      );
    };
}
