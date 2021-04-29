for exe in ~/.conda/bin/*
do
    patchelf --print-interpreter $exe
    # patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $exe
done
