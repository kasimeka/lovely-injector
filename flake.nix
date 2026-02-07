{
  nixConfig.bash-prompt-prefix = ''\[\e[0;31m\](lovely) \e[0m'';

  inputs = {
    # requires nix `>=v2.27`, determinate-nix `v3`, or lix `>=v2.94`
    self.submodules = true;

    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    systems.url = "github:nix-systems/default";

    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: let
    forAllSystems = f:
      inputs.nixpkgs.lib.genAttrs
      (import inputs.systems)
      (system:
        f (import inputs.nixpkgs {
          inherit system;
          overlays = [inputs.rust-overlay.overlays.default];
        })
        system);
  in {
    packages = forAllSystems (pkgs: _: let
      rust-toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
      naersk = pkgs.callPackage inputs.naersk {
        cargo = rust-toolchain;
        rustc = rust-toolchain;
      };

      pname = (pkgs.lib.importTOML ./crates/lovely-unix/Cargo.toml).package.name;
      version = (pkgs.lib.importTOML ./crates/lovely-core/Cargo.toml).package.version;
      src = pkgs.lib.cleanSourceWith {
        name = "${pname}-${version}-clean-src";
        src = ./.;
        filter = inputs.gitignore.lib.gitignoreFilterWith {
          basePath = ./.;
          extraRules =
            # gitignore
            ''
              flake.*
              LICENSE.md
              README.md
              .github
            '';
        };
      };

      drv = naersk.buildPackage {
        inherit src pname version;
        cargoBuildOptions = x: x ++ ["--package" "lovely-unix"];
        copyLibs = true;
        nativeBuildInputs = with pkgs; [cmake];
      };
    in {
      # `nix build git+https://github.com/ethangreen-dev/lovely-injector && ls result/lib`
      default = drv;
      lovely-injector = drv;
    });

    devShells = forAllSystems (pkgs: system: let
      rust-toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
    in {
      # `nix develop git+https://github.com/ethangreen-dev/lovely-injector`
      default = pkgs.mkShell {
        # grab all build dependencies of all exposed packages
        inputsFrom = pkgs.lib.attrValues inputs.self.packages.${system};
        shellHook = ''echo "with löve from wrd :)"'';
      };

      # `nix develop git+https://github.com/ethangreen-dev/lovely-injector#full`
      full = pkgs.mkShell {
        # inherit the base shell
        inputsFrom = [inputs.self.devShells.${system}.default];
        packages =
          (with pkgs; [luajit love])
          ++ [
            (rust-toolchain.override
              {extensions = ["rust-src" "rust-analyzer"];})
          ];
      };
    });
  };
}
