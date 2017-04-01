# $RCSfile$
# $Revision$ $Date$
# Auth: David Loffredo (dave@dave.org)
# 
# PixScribe Photo Annotation Tools
# Copyright (c) 2003-2008 by David Loffredo
# All Rights Reserved
# 
# 		----------------------------------------
# 

!include win32.cfg

EXEC 	 	= pix.exe
LIBRARY  	= pixscribe.lib

INSTDIR		= $(HOME)/bats


EXPAT_INCLUDE	= -Ic:/build_tools/expat2/include
EXPAT_LIBS	= c:/build_tools/expat2/lib/libexpatMD.lib

INCLUDES 	= $(EXPAT_INCLUDE)

OBJECTS = \
	dirscan$o \
	pixstruct$o \
	support$o \
	xmlread$o \
	xmlwrite$o

#========================================
# Standard Symbolic Targets
#
default: $(EXEC)
library: $(LIBRARY)

install-scripts:
	$(CP) pix.bat $(INSTDIR)
	$(CP) pix.pl $(INSTDIR)


clean:
	- $(RM) *.obj
	- $(RM) *.lib
	- $(RM) *.exe

very-clean: clean
spotless: clean


#========================================
# File Targets 
#
$(LIBRARY): $(OBJECTS) 
	- $(RM) $@
	$(LIB32) -out:$@ $(LIB32_SYSFLAGS) $(OBJECTS) 


# Executable -- Checker and Test harness
# Linking setargv.obj file gives us wildcard expansion
#
$(EXEC): $(LIBRARY) main$o
	$(CXX_LINK) /out:$@ main$o $(LIBRARY) $(EXPAT_LIBS) setargv.obj

