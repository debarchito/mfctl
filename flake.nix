{
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
    nixpkgs-lib.follows = "nixpkgs";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
    };
  };
  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      flake.nixosModules.default =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        let
          src = lib.cleanSource ./.;

          mfctl = pkgs.rustPlatform.buildRustPackage {
            pname = "mfctl";
            version = "0.1.0";
            inherit src;

            nativeBuildInputs = builtins.attrValues {
              inherit (pkgs) pkg-config;
            };
            buildInputs = builtins.attrValues {
              inherit (pkgs) libusb1 systemd;
            };

            cargoLock.lockFile = "${src}/Cargo.lock";
          };

          minifuse-kmod =
            { kernel, ... }:
            pkgs.stdenv.mkDerivation {
              pname = "minifuse-kmod";
              version = "0.1.0";
              inherit src;

              sourceRoot = "source/kmod";
              hardeningDisable = [ "pic" ];
              nativeBuildInputs =
                kernel.moduleBuildDependencies
                ++ builtins.attrValues {
                  inherit (pkgs.llvmPackages) llvm clang-unwrapped lld;
                };

              makeFlags = [
                "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
                "LLVM=1"
                "CC=${pkgs.llvmPackages.clang-unwrapped}/bin/clang"
                "HOSTCC=${pkgs.llvmPackages.clang-unwrapped}/bin/clang"
                "LD=${pkgs.llvmPackages.lld}/bin/ld.lld"
              ];

              installPhase = ''
                runHook preInstall
                install -D -m 755 minifuse.ko $out/lib/modules/${kernel.modDirVersion}/extra/minifuse.ko
                runHook postInstall
              '';
            };
        in
        {
          options.programs.mfctl.enable = lib.mkEnableOption "minifuse controller and kernel module";

          config = lib.mkIf config.programs.mfctl.enable {
            environment.systemPackages = [ mfctl ];

            boot = {
              extraModulePackages = [
                (config.boot.kernelPackages.callPackage minifuse-kmod { })
              ];
              kernelModules = [ "minifuse" ];
            };

            services.udev.extraRules = ''
              KERNEL=="minifuse", MODE="0666", TAG+="uaccess"
              # MiniFuse 1
              SUBSYSTEM=="usb", ATTR{idVendor}=="1c75", ATTR{idProduct}=="af80", MODE="0666", TAG+="uaccess"
              # MiniFuse 2
              SUBSYSTEM=="usb", ATTR{idVendor}=="1c75", ATTR{idProduct}=="af90", MODE="0666", TAG+="uaccess"
            '';
          };
        };
    };
}
