{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [(import inputs.rust-overlay)];
        };

        rustPlatform = let
          rust-toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        in
          pkgs.makeRustPlatform {
            cargo = rust-toolchain;
            rustc = rust-toolchain;
          };

        drv = rustPlatform.buildRustPackage (let
          cargo-toml = pkgs.lib.importTOML ./crates/lovely-unix/Cargo.toml;
          pname = cargo-toml.package.name;
          version = cargo-toml.package.version;
        in {
          inherit pname version;

          src = pkgs.lib.cleanSourceWith {
            name = "${pname}-${version}-clean-src";
            src = ./.;
            filter = inputs.gitignore.lib.gitignoreFilterWith {
              basePath = ./.;
              extraRules = ''
                README.md
                LICENSE.md
                flake.*
                rust-toolchain.toml
                .gitignore
                .gitmodules
                .github
              '';
            };
          };
          doCheck = false;

          useFetchCargoVendor = true;
          cargoLock = {
            lockFile = ./Cargo.lock;
            outputHashes."retour-0.4.0-alpha.2" = "sha256-GtLTjErXJIYXQaOFLfMgXb8N+oyHNXGTBD0UeyvbjrA=";
          };
          cargoBuildFlags = ["--package" "lovely-unix"];

          nativeBuildInputs = with pkgs; [cmake];

          env = {
            RUSTC_BOOTSTRAP = 1; # nightly rust features
            RUST_BACKTRACE = 1;
          };
        });
      in {
        packages.default = drv;
        devShells.default = pkgs.mkShell {
          inputsFrom = pkgs.lib.attrValues inputs.self.packages.${system};
          packages = with pkgs; [luajit];
          shellHook = ''echo "with löve from wrd :)"'';
        };
      }
    );
}
