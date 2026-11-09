{ lib, stdenvNoCC, makeWrapper, quickshell, coreutils, procps, python3
, findutils, gnused, curl
}:

stdenvNoCC.mkDerivation {
  pname = "dsh-pet";
  version = "1.1.1";
  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/dsh-pet" "$out/bin" "$out/share/doc/dsh-pet"
    cp shell.qml run.sh model.sh "$out/share/dsh-pet/"
    mkdir -p "$out/share/dsh-pet/tools"
    cp tools/save-setting.py tools/current-lyric.py "$out/share/dsh-pet/tools/"
    cp -r assets "$out/share/dsh-pet/"
    cp LICENSE LICENSE-ARTWORK.md THIRD_PARTY_NOTICES.md "$out/share/doc/dsh-pet/"
    cp -r licenses "$out/share/doc/dsh-pet/"
    for command in run model; do
      makeWrapper "$out/share/dsh-pet/$command.sh" "$out/bin/dsh-pet-$command" \
        --prefix PATH : ${lib.makeBinPath [ quickshell coreutils procps python3 findutils gnused curl ]}
    done
    ln -s dsh-pet-run "$out/bin/dsh-pet"
    runHook postInstall
  '';

  meta = {
    description = "Wayland desktop pet built with Quickshell";
    homepage = "https://github.com/setsuna391/quickshell-whale-pet";
    # Code is MIT; bundled artwork has separate, noncommercial/restricted terms.
    license = lib.licenses.unfree;
    mainProgram = "dsh-pet";
    platforms = lib.platforms.linux;
  };
}
