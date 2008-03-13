#!/usr/bin/perl
# $RCSfile$
# $Revision$ $Date$
# Auth: Dave Loffredo (loffredo@steptools.com)
# 
# Copyright (c) 2003-2008 by Dave Loffredo 
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
# Generate a gallery from an image list
#

use pixtag_file;

$html{footer} = "</TABLE>\n</BODY>\n</HTML>\n";
$html{header} = <<'PERL_EOF';
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2//EN">
<HTML>
<HEAD>
   <TITLE>Gallery</TITLE>
</HEAD>
<BODY bgcolor=#ffffff>
<HR size=1 noshade>
<TABLE width=100% valign=top cellspacing=0 cellpadding=0 border=0>
PERL_EOF

$html{link_image} = <<'PERL_EOF';
<TD  VALIGN=middle><P align=center>
<A HREF="big/%%FILE%%"><IMG SRC="thumbs/%%FILE%%"></A><BR>
<A HREF="big/%%FILE%%">[big]</A>
<A HREF="huge/%%FILE%%">[huge]</A>
%%DESC%%
</TD>
PERL_EOF

$html{tablerow_begin}	= qq{<TR>\n};
$html{tablerow_end}	= qq{</TR>\n};

$count = 0;
#$columns = 4;
$columns = 3;

load_tagfile ("picnic.pixtag");

open (DST, "> gal.html");
print DST $html{header};

# Process the filelist
while (<STDIN>) {
 	next if /^#/; 	chop; 
	$img = $_;

	if (!($count % $columns)) {
		print DST $html{tablerow_end} if $count; 
		print DST $html{tablerow_begin};
	}

 	$linktxt =  $html{link_image};
 	$linktxt =~ s/%%FILE%%/$img/g;
 	$linktxt =~ s/%%DESC%%/<BR>$PHOTO{$img}->{desc}/g;

	my $note = $PHOTO{$img};
	print "$img ==> $note->{desc}\n";
	print DST $linktxt;
	++$count;
}

print DST $html{tablerow_end};
print DST $html{footer};

close(DST);
