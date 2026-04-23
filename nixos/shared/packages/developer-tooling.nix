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

    # language and repository tooling
    ansible
    ansible-language-server
    ansible-lint
    beancount
    languagetool
    git-filter-repo
    tinymist
    gemini-cli
  ];
}