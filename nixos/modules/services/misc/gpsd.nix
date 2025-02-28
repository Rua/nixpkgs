{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let

  uid = config.ids.uids.gpsd;
  gid = config.ids.gids.gpsd;
  cfg = config.services.gpsd;

in
{

  ###### interface

  imports = [
    (lib.mkRemovedOptionModule [ "services" "gpsd" "device" ] "Use `services.gpsd.devices` instead.")
  ];

  options = {

    services.gpsd = {

      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable `gpsd`, a GPS service daemon.
        '';
      };

      devices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "/dev/ttyUSB0" ];
        description = ''
          List of devices that `gpsd` should subscribe to.

          A device may be a local serial device for GPS input, or a
          URL of the form:
          `[{dgpsip|ntrip}://][user:passwd@]host[:port][/stream]` in
          which case it specifies an input source for DGPS or ntrip
          data.
        '';
      };

      readonly = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to enable the broken-device-safety, otherwise
          known as read-only mode.  Some popular bluetooth and USB
          receivers lock up or become totally inaccessible when
          probed or reconfigured.  This switch prevents gpsd from
          writing to a receiver.  This means that gpsd cannot
          configure the receiver for optimal performance, but it
          also means that gpsd cannot break the receiver.  A better
          solution would be for Bluetooth to not be so fragile.  A
          platform independent method to identify
          serial-over-Bluetooth devices would also be nice.
        '';
      };

      nowait = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          don't wait for client connects to poll GPS
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 2947;
        description = ''
          The port where to listen for TCP connections.
        '';
      };

      debugLevel = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = ''
          The debugging level.
        '';
      };

      listenany = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Listen on all addresses rather than just loopback.
        '';
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "-r"
          "-s"
          "19200"
        ];
        description = ''
          A list of extra command line arguments to pass to gpsd.
          Check {manpage}`gpsd(8)` mangpage for possible arguments.
        '';
      };

    };

  };

  ###### implementation

  config = lib.mkIf cfg.enable {

    users.users.gpsd = {
      inherit uid;
      group = "gpsd";
      description = "gpsd daemon user";
      home = "/var/empty";
    };

    users.groups.gpsd = { inherit gid; };

    systemd.services.gpsd = {
      description = "GPSD daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "forking";
        ExecStart =
          let
            devices = utils.escapeSystemdExecArgs cfg.devices;
            extraArgs = utils.escapeSystemdExecArgs cfg.extraArgs;
          in
          ''
            ${pkgs.gpsd}/sbin/gpsd -D "${toString cfg.debugLevel}"  \
              -S "${toString cfg.port}"                             \
              ${lib.optionalString cfg.readonly "-b"}                   \
              ${lib.optionalString cfg.nowait "-n"}                     \
              ${lib.optionalString cfg.listenany "-G"}                  \
              ${extraArgs}                                          \
              ${devices}
          '';
      };
    };

  };

}
