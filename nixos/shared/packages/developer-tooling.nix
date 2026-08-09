{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # build and compilation tools
    tokei
    gnumake
    pkg-config
    dbus.dev
    binutils-unwrapped
    clang
    libclang
    cmake
    protobuf

    # infrastructure and containers
    docker-compose
    openvpn
    xpipe
    k3d
    kubectl
    kubecfg
    kustomize
    k9s
    docker
    docker-buildx
    lazydocker

    # general developer utilities
    actionlint
    lazygit
    pre-commit
    graphviz
    svgbob
    iperf
    ncdu
    psutils
    qpdf
    ghostscript
    typst

    # financial organization
    beancount
    beancount-language-server
    beanquery
    fava

    # agent harnesses
    bubblewrap
    claude-code
    codex
    gemini-cli
    opencode
    ccusage

    # devOps
    ansible
    ansible-language-server
    ansible-lint
    yamllint

    # package managers and misc
    bun
    cabal-install
    cargo-update
    ghc
    git-filter-repo
    nodejs_24
    pnpm
    postgresql_17
    minio-client
    rustup
    uv
  ];
}
