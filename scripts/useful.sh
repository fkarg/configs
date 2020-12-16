# compress pdf files considerably
# gs -sDEVICE=pdfwrite -dNOPAUSE -dQUIET -dBATCH -dPDFSETTINGS=/ebook -sOutputFile=out2.pdf out.pdf

# git ignore further changes in <filename>
# git update-index --skip-worktree <filename>

# journalctl --vacuum-size=200M

# jpgs to pdf
# convert /path/to/images/*.jpg new.pdf

# warnings of the type 
# W: Possible missing firmware /lib/firmware/<module>/<driver> for module <module>
# can be fixed by:
# # cd /lib/firmware/<module>
# # wget https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/<module>/<driver>
# # update-initramfs -u # update

# splitting pdf pages apart:
# nix-shell -p mupdf
# mutool poster -y 2 infile [outfile]
# -y <y decimation factor>
# -x <x decimation factor>
# ^ number of times it should be split apart in
