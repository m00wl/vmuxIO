{ config, lib, pkgs, linux-firmware-pinned, 
extkern ? false, # whether to use externally, manually built kernel
... }:
lib.attrsets.recursiveUpdate ({
  #networking.useDHCP = false;
  #networking.interfaces.eth0.useDHCP = false;
  #networking.defaultGateway = "192.168.56.1";
  #networking.nameservers = [ "10.156.33.53" ];
  #networking.hostName = "host";
  #networking.domain = "gierens.de";
  #networking.bridges = {
  #  "br0" = {
  #    interfaces = [ "eth0" ];
  #  };
  #};
  #networking.interfaces.br0.useDHCP = false;
  #networking.interfaces.br0.ipv4.addresses = [ {
  #  address = "192.168.56.10";
  #  prefixLength = 24;
  #} ];

  imports = [
    ./gpio.nix # enable gpio sysfs
  ];

  services.sshd.enable = true;

  networking.firewall.enable = false;
  # networking.firewall.allowedTCPPorts = [22];

  users.users.root.password = "password";
  services.openssh.settings.permitRootLogin = lib.mkDefault "yes";
  users.users.root.openssh.authorizedKeys.keys = [
    (builtins.readFile ./ssh_key.pub)
  ];
  services.getty.autologinUser = lib.mkDefault "root";

  fileSystems."/mnt" = {
    device = "home";
    fsType = "9p";
    options = [ "trans=virtio" "nofail" "msize=104857600" ];
  };

  # mount host nix store, but use overlay fs to make it writeable
  fileSystems."/nix/.ro-store" = {
    device = "myNixStore";
    fsType = "9p";
    options = [ "ro" "trans=virtio" "nofail" "msize=104857600" ];
    neededForBoot = true;
  };
  fileSystems."/nix/store" = {
    device = "overlay";
    fsType = "overlay";
    options = [ 
      "lowerdir=/nix/.ro-store"
      "upperdir=/nix/.rw-store/store"
      "workdir=/nix/.rw-store/work"
    ];
    neededForBoot = true;
    depends = [ "/nix/.ro-store" ];
  };
  boot.initrd.availableKernelModules = [ "overlay" ];

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  system.activationScripts = {
    linkHome = {
      text = ''
        ln -s /mnt /home/gierens
      '';
      deps = [];
    };
  };

  system.stateVersion = "22.05";

  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
  nix.package = pkgs.nixFlakes;
  environment.systemPackages = with pkgs; [
    kmod
    git
    gnumake
    # pixman
    # glib
    # libepoxy
    # epoxy
    # snappy
    # spice
    # SDL2
    # virglrenderer
    # vde2
    # liburing
    # ninja
    # pkgconfig
    qemu
    htop
    tmux
    tunctl
    bridge-utils
    killall
    gdb
    iperf
    fio
    pciutils
    ioport # access port io (pio) via inb and outw commands
    busybox # for devmem to access physical memory
    (writeScriptBin "devmem" ''
      ${busybox}/bin/devmem $@
    '')
    ethtool
    bpftrace
  ];

  hardware.firmware = [ linux-firmware-pinned ];

  # this breaks make/insmod kmods though:
  #boot.extraModprobeConfig = ''
  #  blacklist ice
  #  blacklist ixgbe
  #'';
  boot.kernelPatches = [
    {
      name = "enable-debug-symbols";
      patch = null;
      extraConfig = ''
        DEBUG_INFO y
      '';
    }
    #{
    #  name = "ixgbe-use-vmux-capability-offset-instead-of-hardware";
    #  patch = ./0001-ixgbe-vmux-capa.patch;
    #}
  ];

  #boot.kernelPackages = let
  #  linux_ioregfd_pkg = { fetchurl, buildLinux, ... } @ args:

  #    buildLinux (args // rec {
  #      version = "5.12.14-ioregionfd";
  #      modDirVersion = "5.12.14";

  #      #src = ./linux;
  #      src = fetchurl {
  #        url = "https://github.com/vmuxIO/linux/archive/refs/tags/v5.12.14-ioregionfd.tar.gz";
  #        sha256 = "3fe587a240c8d29a1bae73d27ccfb7dc332f7bf716e48dbdbabffd05f090481c";
  #      };
  #      kernelPatches = [{
  #        name = "enable-debug-symbols";
  #        patch = null;
  #        extraConfig = ''
  #          DEBUG_INFO y
  #        '';
  #      } {
  #        name = "build-kvm-into-base-kernel";
  #        patch = null;
  #        extraConfig = ''
  #          KVM y
  #        '';
  #      } {
  #        name = "enable-kvm-ioregionfd";
  #        patch = null;
  #        extraConfig = ''
  #          KVM_IOREGION y
  #        '';
  #      # } {
  #      #   name = "remove-useless-stuff";
  #      #   patch = null;
  #      #   extraConfig = ''
  #      #     USB n
  #      #     WLAN n
  #      #   '';
  #      } ];

  #      extraMeta.branch = "5.12";
  #      ignoreConfigErrors = true;
  #    } // (args.argsOverride or {}));
  #  linux_ioregfd = pkgs.callPackage linux_ioregfd_pkg{};
  #in
  #  pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor linux_ioregfd);

  boot.kernelParams = [ 
    "nokaslr"
    "debug"
  ];

})
# merge the following with the previous. See recursiveUpdate above. 
( lib.optionalAttrs extkern {
  # incremental build section
  boot.loader.grub.enable = false;
  boot.initrd.enable = false;
  boot.isContainer = true;
  boot.loader.initScript.enable = true;
  systemd.services."serial-getty" = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStart = "${pkgs.util-linux}/sbin/agetty  --login-program ${pkgs.shadow}/bin/login --autologin root hvc0 --keep-baud vt100";
  };
  systemd.services."serial-getty@hvc0".enable = false;
})
