{ ... }:

{
  # Shared maintenance baseline only. Host-specific update jobs belong in the
  # machine module so rollout policy is explicit per host.
  services.cron = {
    enable = true;
  };
}