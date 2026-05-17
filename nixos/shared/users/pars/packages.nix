{ pkgs, ... }:

{
  users.users.pars.packages = [
    # util
    pkgs.fish
    pkgs.todo-txt-cli

    # dev
    pkgs.postgresql

    # minio client
    pkgs.minio-client

    # global python
    pkgs.python313Packages.ipython
    pkgs.python313Packages.uv
    pkgs.python313Packages.setuptools
    pkgs.python313
    # pkgs.poetry
    # Temporarily disabled on current nixpkgs: pdm-2.26.6 declares
    # installer<0.8 but nixpkgs provides installer 1.0.0, which fails the
    # Python runtime dependency check and blocks system builds.
    # pkgs.pdm
    pkgs.ansible

    # beancount ecosystem
    pkgs.beancount
    pkgs.beanquery
    pkgs.fava

    # rust
    pkgs.gcc
    pkgs.rustup

    # haskell
    pkgs.ghc
    pkgs.cabal-install

    # JS
    pkgs.nodejs
    pkgs.pnpm

    # tex
    pkgs.typst
    pkgs.tinymist

    # fun
    pkgs.cowsay
    pkgs.fortune
    pkgs.sl
    pkgs.doge
    pkgs.opencode
    pkgs.gemini-cli

    pkgs.xdg-user-dirs
  ];
}
