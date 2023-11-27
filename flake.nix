{
  description = "Dev environment for zigdoom";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    # 0.11.0
    zig_dep.url = "github:NixOS/nixpkgs/0bf3f5cf6a98b5d077cdcdb00a6d4b3d92bc78b5";
  };

  outputs = { self, flake-utils, zig_dep }@inputs :
    flake-utils.lib.eachDefaultSystem (system:
    let
      zig_dep = inputs.zig_dep.legacyPackages.${system};
    in
    {
      devShells.default = zig_dep.mkShell {
        packages = [
          zig_dep.zig
          zig_dep.xorg.libX11
          zig_dep.xorg.libXext
        ];

        shellHook = ''
          echo "zig" "$(zig version)"
        '';
      };
    });
}
