# # put here:
# modify config for i3status-rs (no battery, network)
# adapt fish/config (greet on desktop)
# add /HDD and /HDD3 to fstab
# add nvidia drivers
#
# modify startup script:
# - setting background
# - second screen config
{ config, pkgs, ... }:
{
  boot.loader.grub.device = "/dev/sdc"; # or "nodev" for efi only
  boot.kernelParams = [ "mitigations=off" ];

  networking.hostName = "home";

  networking.interfaces.enp2s0.useDHCP = true;
  # networking.interfaces.wlp0s18f2u1u1.useDHCP = true;
  networking.interfaces.wlp0s19f2u4.useDHCP = true;

  # included in lower
  # environment.systemPackages = [
  #   lxd
  # ];
  virtualisation.lxd.enable = true;


  fileSystems."/HDD3/" =
    { device = "/dev/disk/by-uuid/304e2387-e801-465d-b75e-3c54ba33b814";
      fsType = "ext4";
    };

  fileSystems."/HDD/" =
    { device = "/dev/disk/by-uuid/adde52d0-a40b-4889-973a-7d2b032d9052";
      fsType = "ext4";
    };

    # steam
  environment.systemPackages = with pkgs; [
    # (steam.override { extraPkgs = pkgs: [ mono gtk3 gtk3-x11 libgdiplus zlib ]; nativeOnly = true; }).run
    (steam.override { extraPkgs = pkgs: [ mono gtk3 gtk3-x11 libgdiplus zlib ]; }).run
    lxd
  ];

  hardware.opengl.driSupport32Bit = true;
  hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
  hardware.pulseaudio.support32Bit = true;


    # steam end

  services.xserver.videoDrivers = [ "nvidia" ];
}
