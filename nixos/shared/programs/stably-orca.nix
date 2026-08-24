{ config, lib, pkgs, ... }:

# Stably Orca, plus the timer that keeps its pin current without a manual bump.
#
# How the auto-update works, and why it is shaped this way:
#
# /etc/nixos/configs is a symlink into this checkout, so the live system
# evaluates straight out of the working tree. A version bump therefore only has
# to land in ../../pkgs/stably-orca/source.json — no push, no channel, no
# separate deployment step — and the next system.autoUpgrade run builds it.
#
# The alternative was fetching "latest" at eval time. Rejected: a hashless
# builtins.fetchurl makes evaluation impure, so identical git state stops
# producing identical systems, every rebuild re-checks a 160MB artifact, and
# flakes forbid it outright. It also would not have worked here anyway — the
# .deb asset URL embeds the version, so there is no stable "latest" URL for it.
#
# Instead the bump is a real commit. Eval stays pure, `git log` is the record of
# which version arrived when, and each generation pins the version it was built
# with — so rolling back to an older generation rolls Orca back with it, for as
# long as nix.gc keeps that generation (90d here).
let
  # Repo checkout that /etc/nixos/configs points into. Hardcoded rather than an
  # option because only jolly imports this; the day a second host wants it is
  # the day to make it configurable.
  repo = "/home/pars/configs";
  sourceJson = "nixos/pkgs/stably-orca/source.json";
in
{
  environment.systemPackages = [
    (pkgs.callPackage ../../pkgs/stably-orca/package.nix { })
  ];

  systemd.services.stably-orca-update = {
    description = "Bump the pinned Stably Orca release";

    path = with pkgs; [
      bash
      coreutils
      curl
      git
      gnugrep
      gnused
    ];

    serviceConfig = {
      Type = "oneshot";
      # Commit as the repo owner: keeps file ownership intact and picks up the
      # git identity from ~pars/.gitconfig rather than committing as root.
      User = "pars";
      # systemd sets $HOME from the User=, but git is unforgiving if it is
      # missing, and this unit is useless without a resolvable identity.
      Environment = "HOME=${config.users.users.pars.home}";
    };

    # Commit the single pinned path rather than whatever else is in the tree.
    # `git commit -- <path>` bypasses the index for that path, so this is safe
    # to run while a session has unrelated staged or dirty files, which on this
    # machine is the normal state rather than the exception.
    script = ''
      ${repo}/${builtins.dirOf sourceJson}/update.sh

      cd ${repo}
      if git diff --quiet -- ${sourceJson}; then
        exit 0
      fi
      version=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' ${sourceJson})
      git commit -q -m "nixos: stably-orca $version" -- ${sourceJson}
      echo "stably-orca: committed pin for $version"
    '';
  };

  # Run once per upgrade cycle, immediately before the build, instead of on a
  # timer of its own — that way a bump can never sit unbuilt for a day waiting
  # for the next window. `wants` and not `requires`: a network blip on the
  # release feed must not take the whole system upgrade down with it.
  systemd.services.nixos-upgrade = lib.mkIf config.system.autoUpgrade.enable {
    wants = [ "stably-orca-update.service" ];
    after = [ "stably-orca-update.service" ];
  };
}
