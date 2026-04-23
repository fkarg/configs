{ ... }:

{
  # Compatibility wrapper for the historic shared user import path.
  imports = [
    ./shared/users/pars/account.nix
    ./shared/users/pars/packages.nix
    ./shared/users/pars/session.nix
    ./shared/users/pars/maintenance.nix
  ];
}
