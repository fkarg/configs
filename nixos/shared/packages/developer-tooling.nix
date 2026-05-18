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
    k3d
    kubectl
    kubecfg
    kustomize
    k9s
    docker
    docker-buildx
    lazydocker

    # general developer utilities
    lazygit
    graphviz
    iperf
    ncdu
    psutils
    qpdf
    typst

    # financial organization
    beancount
    beancount-language-server
    beanquery
    fava

    # agent harnesses
    claude-code
    codex
    gemini-cli
    opencode

    # devOps
    ansible
    ansible-language-server
    ansible-lint

    # package managers and misc
    bun
    cabal-install
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
