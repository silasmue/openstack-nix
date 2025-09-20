{
  lib,
  pkgs,
  python3Packages,

  # in-repo OpenStack libs (from packages/default.nix)
  castellan,
  cursive,
  futurist,
  keystoneauth1,
  keystonemiddleware,
  microversion-parse,
  openstacksdk,
  os-brick,
  os-resource-classes,
  os-traits,
  os-vif,
  oslo-cache,
  oslo-concurrency,
  oslo-config,
  oslo-context,
  oslo-db,
  oslo-i18n,
  oslo-limit,
  oslo-log,
  oslo-messaging,
  oslo-middleware,
  oslo-policy,
  oslo-privsep,
  oslo-reports,
  oslo-rootwrap,
  oslo-serialization,
  oslo-service,
  oslo-upgradecheck,
  oslo-utils,
  oslo-versionedobjects,
  oslo-vmware,
  osprofiler,
  os-win,
  oslotest,
  python-barbicanclient,
  python-glanceclient,
  python-neutronclient,
  sqlalchemy,
  taskflow,
  tooz,
}:

let
  inherit (python3Packages)
    setuptools
    wheel
    pbr
    decorator
    eventlet
    greenlet
    iso8601
    jsonschema
    lxml
    packaging
    paramiko
    paste
    pastedeploy
    pyparsing
    requests
    routes
    stevedore
    tabulate
    tenacity
    webob
    cryptography
    boto3
    distro
    tzdata
    httplib2
    netaddr
    ;

  # hyphenated names bound explicitly if needed later
  fetchPypi = python3Packages.fetchPypi;

  # py-zstd may vary by channel
  zstdPy =
    if python3Packages ? zstd then
      python3Packages.zstd
    else if python3Packages ? pyzstd then
      python3Packages.pyzstd
    else if python3Packages ? zstandard then
      python3Packages.zstandard
    else
      null;

in
python3Packages.buildPythonPackage rec {
  pname = "manila";
  version = "19.1.0"; # 2024.2 (Dalmatian) patch release
  # setuptools+pbr
  format = "setuptools";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-06qLcus+djXUBnag1w3Bs2cGG4hv7WRKOcLiEKL7ktU="; # build once to fill this
  };

  nativeBuildInputs = [
    setuptools
    wheel
    pbr
    pkgs.pkg-config
  ];

  # system libs for lxml/cryptography
  buildInputs = [
    pkgs.libxml2
    pkgs.libxslt
    pkgs.openssl
    pkgs.libffi
  ];

  propagatedBuildInputs = [
    # prefer in-repo OpenStack libs
    castellan
    cursive
    futurist
    keystoneauth1
    keystonemiddleware
    microversion-parse
    openstacksdk
    os-brick
    os-resource-classes
    os-traits
    os-vif
    oslo-cache
    oslo-concurrency
    oslo-config
    oslo-context
    oslo-db
    oslo-i18n
    oslo-limit
    oslo-log
    oslo-messaging
    oslo-middleware
    oslo-policy
    oslo-privsep
    oslo-reports
    oslo-rootwrap
    oslo-serialization
    oslo-service
    oslo-upgradecheck
    oslo-utils
    oslo-versionedobjects
    oslo-vmware
    osprofiler
    os-win
    oslotest
    python-barbicanclient
    python-glanceclient
    python-neutronclient
    sqlalchemy
    taskflow
    tooz

    # filled from nixpkgs python set
    decorator
    eventlet
    greenlet
    iso8601
    jsonschema
    lxml
    packaging
    paramiko
    paste
    pastedeploy
    pyparsing
    requests
    routes
    stevedore
    tabulate
    tenacity
    webob
    cryptography
    boto3
    distro
    tzdata
    httplib2
    netaddr
  ]
  ++ lib.optional (zstdPy != null) zstdPy;

  # Optional DB driver if you use MySQL:
  # propagatedBuildInputs = propagatedBuildInputs ++ [ python3Packages.pymysql ];

  doCheck = false;
  pythonImportsCheck = [ "manila" ];

  meta = with lib; {
    description = "OpenStack Shared File Systems (Manila)";
    homepage = "https://docs.openstack.org/manila/latest/";
    license = licenses.asl20;
    platforms = platforms.linux;
  };
}
