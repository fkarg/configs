{ pkgs, ... }:

{
  programs.fish.enable = true;
  programs.neovim.enable = true;
  programs.evince.enable = true;
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    zlib # e.g. for numpy
    libgcc # e.g. for sqlalchemy
    # that's where the shared libs go, you can find which one you need using
    # nix-locate --top-level libstdc++.so.6  (replace this with your lib)
    # ^ this requires `nix-index` pkg
  ];

  environment.variables = {
    EDITOR = "nvim";
    BROWSER = "firefox";
    PAGER = "less -R";
    TZ = "Europe/Berlin";
    FZF_DEFAULT_COMMAND = "rg --files --no-ignore --hidden --follow --glob '!.git/*'";
  };
}