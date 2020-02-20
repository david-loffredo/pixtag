# 
# PixTag Photo Annotation Tools
#

!include win32.cfg

INSTDIR		= $(HOME)\bats

#========================================
# Standard Symbolic Targets
#
default: 
install:
	$(CP) pix.bat $(INSTDIR)
	$(CP) pix.pl $(INSTDIR)

clean:
	- $(RM) *.obj
	- $(RM) *.lib
	- $(RM) *.exe

very-clean: clean
spotless: clean

