# $RCSfile$
# $Revision$ $Date$
# Auth: Dave Loffredo (loffredo@steptools.com)
# 
# Copyright (c) 2003 by Dave Loffredo 
# All Rights Reserved.
# 
# This file is part of the PIXTAG software package
# 
# This file may be distributed and/or modified under the terms of 
# the GNU General Public License version 2 as published by the Free
# Software Foundation and appearing in the file LICENSE.GPL included
# with this file.
# 
# THIS FILE IS PROVIDED "AS IS" WITH NO WARRANTY OF ANY KIND,
# INCLUDING THE WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE.
# 
# 		----------------------------------------
# 

WINMAKEFILE	= win32.mak
WINMAKE		= $(MAKE) /nologo /X- /F$(WINMAKEFILE)
FORVAR		= %i

# libraries built and installed by this package
LIBRARY 	= stix.lib

# test harness application
TEST_EXEC	= snip.exe
TEST_LIBS 	= $(LIBRARY) $(CXX_SYSLIBS)


# Set these to the compiler flags and directives for all packages.
# These are used by the CXX_COMPILE and CX_LINK C++ compile and link
# macros.
#
CXX_CFLAGS 	= $(ROSE_CFLAGS) -Iclasses -Iexts 
CXX_LDFLAGS 	= $(ROSE_LDFLAGS)

# Explicit header files for the main part of the library.  Use
# wildcards for the class and header extension files.
#
INCLUDE_INSTDIR = $(ROSE_INCLUDE)\stix
INCLUDE_SOURCES = \
	StixNC.h \
	StixCursor.h \
	stix_imp.h \
	stix_utils.h \
	tolerance.h \
	xform.h \
	stix.h

# These object files are built using the default .cxx to .obj rules
# defined in the $ROSE_CONFIG file
#
OBJECTS = \
	StixNC$o \
	StixCursor$o \
	component$o \
	feature$o \
	geometry$o \
	measure$o \
	project$o \
	report$o \
	schema$o \
	tool$o \
	tolerance$o \
	utils$o \
	workplan$o \
	workpiece$o \
	xform$o

#========================================
# Standard Symbolic Targets
#
default: $(LIBRARY) $(TEST_EXEC)
install: $(LIBRARY) "$(LIBRARY_INSTDIR)" install-includes
	-$(RM) "$(LIBRARY_INSTDIR)"\$(LIBRARY)
	$(MV) $(LIBRARY) "$(LIBRARY_INSTDIR)"

install-includes: $(INCLUDE_SOURCES) "$(INCLUDE_INSTDIR)"
	-$(RM) "$(INCLUDE_INSTDIR)"\*.h
	-$(RM) "$(INCLUDE_INSTDIR)"\*.hi
	-$(RM) "$(INCLUDE_INSTDIR)"\*.hx
	$(CP) classes\*.h "$(INCLUDE_INSTDIR)"
	$(CP) exts\*.hi   "$(INCLUDE_INSTDIR)"
	$(CP) exts\*.hx   "$(INCLUDE_INSTDIR)"
	-for $(FORVAR) in ($(INCLUDE_SOURCES)) do $(CP) $(FORVAR) "$(INCLUDE_INSTDIR)"


# NO LONGER NEEDED
# THIS ONLY NEEDS TO BE DONE FOR ST-DEVELOPER V9
#
# Install the AP-238 compiled schema (integrated_cnc_schema.rose)
# into the ST-Developer schemas directory.  This is needed for any
# AP-238 program to function properly.
#
# This only needs to be done once per machine.
#
install-support-stdev-v9:
	echo NO LONGER NEEDED
	echo THIS ONLY NEEDS TO BE DONE FOR ST-DEVELOPER V9
	-$(RM) "$(EXPRESS_ROSEDIR)"\integrated_cnc_schema.rose
	$(CP) exp\integrated_cnc_schema.rose  "$(EXPRESS_ROSEDIR)"


clean: 
	- $(RM) *.obj
	- $(RM) *.exe
	- $(RM) *.lib

very-clean: clean
	- cd "$(MAKEDIR)"\classes
	- $(WINMAKE) clean
	- cd "$(MAKEDIR)"

spotless: very-clean
	- $(RMDIR) classes


# Generate class library from EXPRESS.  Create a makefile using the
# mkmakefile tool.  If any class extension files are in the "exts"
# directory, the extall tool will patch them into the appropriate
# generated class.
## extall broken, fix later 'extall -Iexts classes'
#
generated:
	expfront -classes -writenone -ws $(EXPRESS_WS) $(EXPRESS_SRC)
	$(CP) Makefile.cls 	classes\Makefile
	$(CP) win32.cls 	classes\win32.mak
	- cd "$(MAKEDIR)"\classes
	extclass -hi -hx -cx action_method
	extclass -hi -hx -cx action_resource
	extclass -hi -hx -cx machining_feature_process
	extclass -hi -hx -cx machining_operation
	extclass -hi -hx -cx machining_touch_probing
	extclass -hi -hx -cx machining_workingstep
	extclass -hi -hx -cx machining_workplan
	extclass -hi -hx -cx material_designation
	extclass -hi -hx -cx product
	extclass -hi -hx -cx product_definition
	extclass -hi -hx -cx shape_aspect
	extclass -hi -hx -cx dimensional_size
	extclass -hi -hx -cx dimensional_location
	extclass -hx -cx action_property_representation
	extclass -hx -cx geometric_tolerance
	extclass -hx -cx machining_process_executable
	extclass -hx -cx machining_tool
	extclass -hx -cx plus_minus_tolerance
	extclass -hx -cx product_definition_relationship
	extclass -hx -cx property_definition_representation
	extclass -hx -cx resource_property_representation
	extclass -hx -cx dimensional_characteristic_representation
	- cd "$(MAKEDIR)"


# mkmakefile only on unix
generate-makefile:
	cd classes; mkmakefile -stdev -nodeps \
		-includes '-I../exts -I$$(ROSE_INCLUDE)'
	cd classes; mkmakefile -win32 -nodeps \
		-includes '-I../exts -I$$(ROSE_INCLUDE)'


#========================================
# Test Harness
#
$(TEST_EXEC): $(LIBRARY) main$o
	$(CXX_LINK) /out:$@ main$o $(TEST_LIBS)



#========================================
# Stix Library
#
# We need to combine all of the class files as well as the core
# functional files into one library.  The easiest way to do this is
# just to build the class lib and then add the rest in a separate
# operation.  This is easy on Windows since lib32 will concatenate
# libraries.
#
$(CLASSLIB): 
	cd "$(MAKEDIR)"\classes
	$(WINMAKE) CFLAGS=$(CFLAGS) OPTFLAGS=$(OPTFLAGS)
	cd "$(MAKEDIR)"


$(LIBRARY): $(CLASSLIB) $(OBJECTS)
	- $(RM) $@
	$(LIB32) -out:$@ @<<
	$(LIB32_SYSFLAGS) $(CLASSLIB) $(OBJECTS)
<<


# Visual Age NMAKE does not handle directory existance well, so
# put in a test.  No need to quote the @ var, since the target is
# already quoted.
#
"$(INCLUDE_INSTDIR)":	; if not exist $@\$(NULL) $(MKDIR) $@
"$(LIBRARY_INSTDIR)": 	; if not exist $@\$(NULL) $(MKDIR) $@

