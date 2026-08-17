{
  description = "One-command system bootstrap: Nix + nix-darwin + home-manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, ... }:
    let
      # TODO: parametrize per-host/per-user once more machines are added
      user = "fixture";
    in
    {
      darwinConfigurations.default = nix-darwin.lib.darwinSystem {
        modules = [
          ./darwin/default.nix
          home-manager.darwinModules.home-manager
          {
            nixpkgs.hostPlatform = "aarch64-darwin";
            system.primaryUser = user;
            users.users.${user}.home = "/Users/${user}";
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${user} = import ./home/darwin.nix;
          }
        ];
      };

      homeConfigurations."${user}-linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./home/linux.nix
          {
            home.username = user;
            home.homeDirectory = "/home/${user}";
          }
        ];
      };
    };
}
