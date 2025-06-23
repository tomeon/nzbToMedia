{
  lib,
  python3,
  stdenv,
  coreutils,
  ffmpeg,
  gnutar,
  p7zip,
  par2cmdline,
  unrar,
  unzip,
  nzbToMediaStateDir ? ".",
  nzbToMediaConfigFile ? "${nzbToMediaStateDir}/autoProcessMedia.cfg",
  nzbToMediaLogDir ? "/var/empty",
  nzbToMediaLogFile ? "/dev/stderr",
  nzbToMediaCategories ? {},
}: let
  propagatedBuildInputs = [
    coreutils
    ffmpeg
    gnutar
    p7zip
    par2cmdline
    unrar
    unzip
  ];

  replacements = let
    categoryReplacements =
      lib.flip lib.pipe [
        (lib.flip lib.genAttrs lib.id)
        (categories: categories // nzbToMediaCategories)
        (lib.mapAttrsToList (from: to: ["--replace-warn"] ++ (map (s: "[[${s}]]") [from to])))
        lib.concatLists
      ] [
        "ALL"
        "UNCAT"
        "books"
        "comics"
        "games"
        "movie" # singular, despite plural being used for most other categories
        "music"
        "tv"
      ];
  in
    categoryReplacements
    ++ [
      # Do not attempt to auto-update: Nix store paths are immutable.
      "--replace-quiet"
      "auto_update = 1"
      "auto_update = 0"

      # Belt-and-suspenders: make Git operations fail, preventing auto-update.
      "--replace-fail"
      "git_path ="
      "git_path = ${lib.getBin coreutils}/bin/false"

      # Ensure that nzbToMedia can find `ffmpeg` and friends.
      "--replace-fail"
      "ffmpeg_path ="
      "ffmpeg_path = ${builtins.dirOf (lib.getExe ffmpeg)}"

      # Ensure that nzbToMedia can find its other executable prerequisites.
      "--replace-fail"
      "sys_path ="
      "sys_path = ${lib.makeBinPath propagatedBuildInputs}"
    ];

  nzbToMediaConfigSpecFile = "$out/share/nzbToMedia/autoProcessMedia.cfg.spec";

  envDefault = {
    NZBTOMEDIA_CONFIG_FILE = nzbToMediaConfigFile;
    NZBTOMEDIA_CONFIG_SPEC_FILE = nzbToMediaConfigSpecFile;
    NZBTOMEDIA_LOG_DIR = nzbToMediaLogDir;
    NZBTOMEDIA_LOG_FILE = nzbToMediaLogFile;
    NZBTOMEDIA_STATE_DIR = nzbToMediaStateDir;
  };

  envMandatory = {
    NZBTOMEDIA_SKIP_CLEANUP = "yes";
    NZBTOMEDIA_TEST_FILE = "$out/share/nzbToMedia/test.mp4";
  };
in
  python3.pkgs.buildPythonApplication {
    inherit propagatedBuildInputs;

    pname = "nzbToMedia";
    version = "0.1.0";

    src = ./.;

    pyproject = true;
    build-system = with python3.pkgs; [setuptools];

    makeWrapperArgs =
      (lib.mapAttrsToList (name: value: ["--set-default" name value]) envDefault)
      ++ (lib.mapAttrsToList (name: value: ["--set" name value]) envMandatory);

    dependencies = lib.pipe ./libs/requirements-common.txt [
      builtins.readFile
      (lib.splitString "\n")
      (lib.filter (s: s != ""))
      (lib.filter (s: s != "transmissionrpc")) # unmaintained
      (map (s:
        if s == "requests_oauthlib"
        then "requests-oauthlib"
        else s))
      (lib.filter (lib.flip lib.hasAttr python3.pkgs))
      (map (lib.flip lib.getAttr python3.pkgs))
    ];

    preFixup = ''
      mkdir -p $out/bin
      find . -maxdepth 1 -name '*.py' -executable -exec cp -t $out/bin '{}' '+'
      rm -f $out/bin/nzbToMedia.py
      install -Dm0644 license.txt $out/share/doc/nzbToMedia/license.txt
      install -Dm0644 tests/test.mp4 $out/share/nzbToMedia/test.mp4
      (
        umask 0133
        substitute autoProcessMedia.cfg.spec ${nzbToMediaConfigSpecFile} ${lib.escapeShellArgs replacements}
      )
    '';

    nativeCheckInputs = with python3.pkgs; [pytestCheckHook];
    enabledTestPaths = ["tests"];
    pytestFlags = ["--doctest-modules"];
    preCheck = lib.pipe (envDefault // envMandatory) [
      (lib.mapAttrsToList (name: value: ''export ${name}="${value}"''))
      (lib.concatStringsSep "\n")
    ];

    meta = {
      homepage = "https://github.com/clinton-hall/nzbToMedia";
      description = "Provides NZB and Torrent postprocessing To CouchPotatoServer, SickBeard/SickRage, HeadPhones, Mylar and Gamez";
      license = lib.licenses.gpl3Only;
    };
  }
