{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
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

        cargo-toml = pkgs.lib.importTOML ./crates/lovely-unix/Cargo.toml;

        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        rustPlatform = pkgs.makeRustPlatform {
          rustc = rustToolchain;
          cargo = rustToolchain;
        };

        drv = rustPlatform.buildRustPackage (finalAttrs: {
          env.RUSTC_BOOTSTRAP = 1;

          pname = cargo-toml.package.name;
          version = cargo-toml.package.version;
          src = pkgs.lib.cleanSourceWith {
            name = "${finalAttrs.pname}-${finalAttrs.version}-clean-src";
            src = ./.;
            filter = inputs.gitignore.lib.gitignoreFilterWith {
              basePath = ./.;
              extraRules = ''
                README.md
                LICENSE.md
                flake.*
                .git*
                rust-toolchain.toml
              '';
            };
          };

          useFetchCargoVendor = true;
          cargoLock.lockFile = ./Cargo.lock;
          cargoLock.outputHashes."retour-0.4.0-alpha.2" = "sha256-GtLTjErXJIYXQaOFLfMgXb8N+oyHNXGTBD0UeyvbjrA=";
          cargoBuildFlags = ["--package" "lovely-unix"];

          doCheck = false;
        });
      in {
        packages.default = inputs.self.packages.${system}.lovely-injector;
        packages.lovely-injector = drv;
        packages.rustToolchain = rustToolchain;

        devShell = pkgs.mkShell {
          inputsFrom = pkgs.lib.attrValues inputs.self.packages.${system};
          packages =
            (with pkgs; [love luajit])
            ++ [
              (rustToolchain.override {
                extensions =
                  ((pkgs.lib.importTOML ./rust-toolchain.toml).toolchain.components or [])
                  ++ ["rust-analyzer" "clippy"];
              })
            ];
        };
      }
    );
}
