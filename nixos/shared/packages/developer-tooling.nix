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
    jujutsu
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
    antigravity-cli
    opencode
    ccusage

    # devOps
    # ansible-core inside a Python env rather than the standalone `ansible`
    # app: the app only injects its deps into its own sys.path, so
    # `ansible_playbook_python` (sys.executable) is a bare interpreter and
    # localhost modules (community.docker -> requests) fail to import.
    # Link only ansible-*: the env's bin/ also carries python3 and every
    # dependency's scripts.
    (runCommand "ansible-env" { } ''
      mkdir -p $out/bin
      ln -s ${python3.withPackages (ps: [ ps.ansible-core ])}/bin/ansible* $out/bin/
    '')
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
    rclone
    rustup
    uv
  ];
}
