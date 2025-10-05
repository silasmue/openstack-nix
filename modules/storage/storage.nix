{ cinder }:
{
  imports = [
    ../generic/controller-host-entry.nix
    (import ./cinder.nix { inherit cinder; })
  ];
}
