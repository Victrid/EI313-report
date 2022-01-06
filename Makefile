all: hugepage.pdf l2-forwarding.pdf libvirt.pdf networking.pdf

hugepage.pdf:
	cd hugepage && latexmk -pdfxe main.tex 
	cd hugepage && latexmk -pdfxe -c && rm main.xdv
	mv hugepage/main.pdf ./hugepage.pdf
	
l2-forwarding.pdf:
	cd l2-forwarding && latexmk -pdfxe main.tex 
	cd l2-forwarding && latexmk -pdfxe -c && rm main.xdv
	mv l2-forwarding/main.pdf ./l2-forwarding.pdf
	
networking.pdf:
	cd networking && latexmk -pdfxe main.tex 
	cd networking && latexmk -pdfxe -c && rm main.xdv
	mv networking/main.pdf ./networking.pdf
	
libvirt.pdf:
	cd libvirt && latexmk -pdfxe main.tex 
	cd libvirt && latexmk -pdfxe -c && rm main.xdv
	mv libvirt/main.pdf ./libvirt.pdf

clean:
	rm -f hugepage.pdf l2-forwarding.pdf libvirt.pdf networking.pdf
