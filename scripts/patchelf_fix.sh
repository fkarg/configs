
FIX=~/.conda/bin/*
# FIX=~/.conda/envs/*/bin/*

for exe in $FIX
do
    echo [$exe]
    patchelf --print-interpreter $exe
    patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $exe
done
