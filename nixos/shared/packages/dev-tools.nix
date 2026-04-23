{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # build and compilation tools
    tokei
    gnumake
    docker-compose
    openvpn
    pkg-config
    dbus.dev
    binutils-unwrapped
    clang
    libclang
    cmake
    protobuf

    # kubernetes and containers
    k3d
    kubectl
    kubecfg
    kustomize
    k9s
    docker
    docker-buildx
    lazydocker

    # general development utilities
    lazygit
    graphviz
    iperf
    ncdu
    psutils
    qpdf
    typst

    # language tooling
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