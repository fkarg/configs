{ ... }:

{
  # Enable cron service
  services.cron = {
    enable = true;
    systemCronJobs = [
      "0 * * * *      pars  /home/pars/passive_update.sh"
      "0 * * * *      pars  nix-channel --update"
    ];
  };
}