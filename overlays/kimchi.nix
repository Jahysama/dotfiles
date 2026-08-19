final: prev: {
  kimchi = prev.stdenv.mkDerivation rec {
    pname = "kimchi";
    version = "0.1.94";

    src = prev.fetchurl {
      url = "https://github.com/getkimchi/kimchi/releases/download/v${version}/kimchi_linux_amd64.tar.gz";
      hash = "sha256-Wr4eLYs34l7qaLKMCgD/QJzZzYYpFWPKxYyKAsZ1G5o=";
    };

    nativeBuildInputs = [ prev.autoPatchelfHook ];
    buildInputs = [
      prev.stdenv.cc.cc.lib
      prev.openssl
      prev.zlib
    ];

    # Bun standalone binaries may link against musl or lttng which aren't needed
    autoPatchelfIgnoreMissingDeps = true;

    sourceRoot = ".";
    dontBuild = true;
    dontStrip = true;

    installPhase = ''
      mkdir -p $out/bin
      cp kimchi $out/bin/
      chmod +x $out/bin/kimchi
    '';

    meta = {
      mainProgram = "kimchi";
      description = "Terminal coding agent powered by Kimchi's multi-model orchestration";
      homepage = "https://kimchi.dev";
    };
  };
}
