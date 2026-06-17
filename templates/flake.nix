# zzcollab Nix backend (starting point).
#
# This flake pins the whole environment - R, packages, and system libraries -
# to one nixpkgs revision, reaching reproducibility level L2 without a
# container. `nix flake update` writes flake.lock (the exact pin, the analogue
# of renv.lock); `nix develop` enters the environment.
#
# This is a minimal starting point. For an environment that tracks the
# project's DESCRIPTION packages exactly, regenerate it with the rix package:
#   R -e 'rix::rix(r_ver = "latest", r_pkgs = c(...), project_path = ".")'
{
  description = "zzcollab reproducible R environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          rEnv = pkgs.rWrapper.override {
            packages = with pkgs.rPackages; [
              renv
              remotes
              languageserver
            ];
          };
        in {
          default = pkgs.mkShell {
            packages = [ rEnv pkgs.pandoc ];
            shellHook = ''
              echo "zzcollab Nix environment ($(R --version | head -1))"
            '';
          };
        });
    };
}
