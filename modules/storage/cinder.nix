{ cinder }:
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.cinder;

  cinder_env = pkgs.python3.buildEnv.override {
    extraLibs = [ cfg.cinderPackage ];
  };

  utils_env = pkgs.buildEnv {
    name = "utils";
    paths = [ cinder_env ];
  };

  rootwrapConf = pkgs.callPackage ../../lib/rootwrap-conf.nix {
    package = cinder_env;
    filterPath = "/etc/cinder/rootwrap.d";
    inherit utils_env;
  };

  cinderConf = pkgs.writeText "cinder.conf" ''
    [DEFAULT]
    log_dir = /var/log/cinder
    state_path = /var/lib/cinder
    lock_path = /var/lib/cinder/tmp
    rootwrap_config = ${rootwrapConf}
    transport_url = rabbit://openstack:openstack@controller
    my_ip = 10.0.0.10
    enabled_backends = nvmet-lvm
    default_volume_type = nvmet-lvm
    glance_api_servers = http://controller:9292

    [api]
    auth_strategy = keystone

    [database]
    connection = sqlite:////var/lib/cinder/cinder.sqlite

    [keystone_authtoken]
    www_authenticate_uri = http://controller:5000/
    auth_url = http://controller:5000/
    memcached_servers = controller:11211
    auth_type = password
    project_domain_name = Default
    user_domain_name = Default
    project_name = service
    username = cinder
    password = cinder

    [oslo_concurrency]
    lock_path = /var/lib/cinder/tmp

    [nvmet-lvm]
    volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
    volume_group = cinder-volumes
    volume_backend_name = nvmet-lvm
    target_helper = nvmet
    # RDMA transport (use nvmet_tcp for TCP). :contentReference[oaicite:0]{index=0}
    target_protocol = nvmet_rdma
    # TODO: set this to the **storage/RDMA** IP on the Cinder node:
    target_ip_address = 10.0.0.10
    # NVMET knobs (safe defaults): :contentReference[oaicite:1]{index=1}
    nvmet_port_id = 1
    nvmet_ns_id = 10
  '';
in
{
  options.cinder = {
    enable = mkEnableOption "Enable OpenStack Cinder." // {
      default = true;
    };

    config = mkOption {
      default = cinderConf;
      description = "The Cinder config file path.";
    };

    cinderPackage = mkOption {
      default = cinder;
      type = types.package;
      description = "OpenStack Cinder package to use.";
    };

    extraPkgs = mkOption {
      default = [ ];
      type = types.listOf types.package;
      description = "Extra packages for cinder services PATH.";
    };
  };

  config = mkIf cfg.enable {
    users.extraUsers.cinder = {
      group = "cinder";
      isSystemUser = true;
    };
    users.groups.cinder = {
      name = "cinder";
      members = [ "cinder" ];
    };

    # dirs (match your nova style)
    systemd.tmpfiles.settings."10-cinder" = {
      "/var/log/cinder".D = {
        user = "cinder";
        group = "cinder";
        mode = "0755";
      };
      "/var/lib/cinder".D = {
        user = "cinder";
        group = "cinder";
        mode = "0755";
      };
      "/var/lib/cinder/tmp".D = {
        user = "cinder";
        group = "cinder";
        mode = "0755";
      };
      "/etc/cinder".D = {
        user = "cinder";
        group = "cinder";
        mode = "0755";
      };
    };

    # Open API port
    networking.firewall.allowedTCPPorts = [ 8776 ];

    # Run DB sync once before services (works with sqlite or external DB)
    systemd.services."cinder-dbsync" = {
      description = "Cinder DB Sync";
      wantedBy = [ "multi-user.target" ];
      before = [
        "cinder-api.service"
        "cinder-scheduler.service"
        "cinder-volume.service"
      ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "cinder";
        Group = "cinder";
        ExecStart = pkgs.writeShellScript "cinder-dbsync.sh" ''
          ${cfg.cinderPackage}/bin/cinder-manage --config-file=${cfg.config} db sync
        '';
      };
    };

    # Services (use same pattern as nova)
    systemd.services."cinder-api" = {
      description = "OpenStack Cinder API";
      after = [
        "network.target"
        "rabbitmq.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path =
        with pkgs;
        [
          sudo
          cinder_env
        ]
        ++ cfg.extraPkgs;
      environment.PYTHONPATH = "${cinder_env}/${pkgs.python3.sitePackages}";
      serviceConfig.ExecStart = pkgs.writeShellScript "cinder-api.sh" ''
        ${cfg.cinderPackage}/bin/cinder-api --config-file=${cfg.config}
      '';
    };

    systemd.services."cinder-scheduler" = {
      description = "OpenStack Cinder Scheduler";
      after = [ "cinder-api.service" ];
      wantedBy = [ "multi-user.target" ];
      path =
        with pkgs;
        [
          sudo
          cinder_env
        ]
        ++ cfg.extraPkgs;
      environment.PYTHONPATH = "${cinder_env}/${pkgs.python3.sitePackages}";
      serviceConfig.ExecStart = pkgs.writeShellScript "cinder-scheduler.sh" ''
        ${cfg.cinderPackage}/bin/cinder-scheduler --config-file=${cfg.config}
      '';
    };

    systemd.services."cinder-volume" = {
      description = "OpenStack Cinder Volume (LVM + NVMET)";
      after = [ "cinder-scheduler.service" ];
      wantedBy = [ "multi-user.target" ];
      path =
        with pkgs;
        [
          sudo
          cinder_env
          pkgs.lvm2
          pkgs.nvme-cli
          pkgs.nvmetcli
        ]
        ++ cfg.extraPkgs;
      environment.PYTHONPATH = "${cinder_env}/${pkgs.python3.sitePackages}";
      serviceConfig.ExecStart = pkgs.writeShellScript "cinder-volume.sh" ''
        ${cfg.cinderPackage}/bin/cinder-volume --config-file=${cfg.config}
      '';
    };
  };
}
