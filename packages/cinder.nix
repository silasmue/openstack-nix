{
  lib,
  pkgs,
  fetchPypi,
  python3Packages,

  # In-repo OpenStack libs (wired from default.nix)
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
  python-barbicanclient,
  python-cinderclient,
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
    rtslib-fb
    stevedore
    tabulate
    tenacity
    webob
    google-api-python-client
    cryptography
    boto3
    distro
    tzdata
    httplib2 # pulled by google-api-python-client, but listing explicitly is harmless
    ;

  # py zstd can be named differently across channels
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
  pname = "cinder";
  version = "25.2.0"; # OpenStack 2024.2 (Dalmatian)

  # Cinder uses setuptools+pbr (not pyproject/PEP517 here)
  format = "setuptools";

  src = fetchPypi {
    inherit pname version;
    sha256 = "sha256-j1sQhCMKAKt85wlY4EzAb5aw+qmDpRab3BVlxkl0rww="; # run once to get the real SRI
  };

  nativeBuildInputs = [
    setuptools
    wheel
    pbr
    pkgs.pkg-config
  ];

  # C libs for lxml/cryptography, etc.
  buildInputs = [
    pkgs.libxml2
    pkgs.libxslt
    pkgs.openssl
    pkgs.libffi
  ];

  # Runtime Python deps: prefer your in-repo OpenStack libs + fill with nixpkgs
  propagatedBuildInputs = [
    # from your repo
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
    python-barbicanclient
    python-cinderclient
    python-glanceclient
    python-neutronclient
    sqlalchemy
    tooz
    taskflow

    # from python3Packages
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
    taskflow
    rtslib-fb
    stevedore
    tabulate
    tenacity
    webob
    google-api-python-client
    cryptography
    boto3
    distro
    tzdata
    httplib2
  ]
  ++ lib.optional (zstdPy != null) zstdPy;

  # Optional DB driver (enable if your DB URL is mysql+pymysql://...)
  # propagatedBuildInputs = propagatedBuildInputs ++ [ python3Packages.pymysql ];

  # OpenStack tests are heavy; skip during packaging
  doCheck = false;
  # If you want a smoke import:
  pythonImportsCheck = [ "cinder" ];

  meta = with lib; {
    description = "OpenStack Block Storage (Cinder)";
    homepage = "https://opendev.org/openstack/cinder";
    license = licenses.asl20;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
