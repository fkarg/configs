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
    pkgs.python313Packages.pygments
    pkgs.python313Packages.virtualenv
    pkgs.python313Packages.uv
    pkgs.python313Packages.setuptools
    pkgs.python313
    pkgs.poetry
    pkgs.pdm
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