{ pkgs, lib, configuration }:

import (pkgs.path + "/nixos/lib/make-disk-image.nix") {
  config = (import (pkgs.path + "/nixos/lib/eval-config.nix") {
    inherit (pkgs) system;
    modules = [{
      imports = [ configuration ];
    }];
  }).config;
  inherit pkgs;
  inherit (pkgs) lib;
  diskSize = 4096;
  partitionTableType = "none";
  # for a different format
  #format = "qcow2";
}
