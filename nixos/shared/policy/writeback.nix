{ ... }:

{
  # Cap dirty page cache in bytes instead of the default 10%/20% of RAM. On
  # jolly's 92 GiB that let ~18 GiB pile up, and fsync-heavy workloads (local
  # Postgres under the backend-core test suite) then stalled the whole desktop
  # in multi-GB writeback bursts. Setting the *_bytes knobs zeroes the *_ratio
  # ones.
  boot.kernel.sysctl = {
    "vm.dirty_bytes" = 268435456; # 256 MiB: writers block beyond this
    "vm.dirty_background_bytes" = 67108864; # 64 MiB: background flush starts
  };
}
