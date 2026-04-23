# List all the programs here that I tend to have installed everywhere globally.
{ ... }:

{
        # Shared global software entry point.
        imports = [
                ./shared/packages/nixpkgs-policy.nix
                ./shared/packages/base-cli.nix
                ./shared/packages/desktop-apps.nix
                ./shared/packages/desktop-integration.nix
                ./shared/packages/developer-tooling.nix
                ./shared/packages/wayland-tools.nix
                ./shared/packages/system-fonts.nix
                ./shared/programs/ausweisapp.nix
        ];
}
