{
  description = "Dev environment for zig-c-simple";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    # 0.11.0
    zig_dep.url = "github:NixOS/nixpkgs/46688f8eb5cd6f1298d873d4d2b9cf245e09e88e";

    x11_dep.url = "github:NixOS/nixpkgs/3a641defd170a4ef25ce8c7c64cb13f91f867fca";
  };

  outputs = { self, flake-utils, zig_dep, x11_dep }@inputs :
    flake-utils.lib.eachDefaultSystem (system:
    let
      zig_dep = inputs.zig_dep.legacyPackages.${system};
      x11_dep = inputs.x11_dep.legacyPackages.${system};
    in
    {
      devShells.default = zig_dep.mkShell {
        packages = [
          zig_dep.zig
          zig_dep.xorg.libXext
          x11_dep.x11
        ];

        shellHook = ''
          echo "zig" "$(zig version)"
        '';
      };
    });
}
