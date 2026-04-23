{ pkgs, ... }:

{
  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Zswap configuration
  boot.kernelParams = [ "zswap.enabled=1" "zswap.compressor=lz4" "zswap.max_pool_percent=25" ];
}