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
# Totally fragile, trivial parser for pixtag files.  Someone could
# probably do a much better job with one of the SAX or DOM libraries
# out there, but this works for now.  Plus, I'm not planning to abuse
# this too much.
#

package pixtag_file;

use strict;
require Exporter;

our(@ISA, @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(load_tagfile save_tagfile %EVENT %PHOTO);

our %EVENT;
our %PHOTO;

sub load_tagfile($) {
    my ($tagfile) = @_;
    local ($_);
    local(*SRC);

    print "Loading photo notes from $tagfile\n";
    open (SRC, "$tagfile") or die "Could not open $tagfile";;

    while (<SRC>) {
	/<event\s+id\s*=\s*\"([\w\.]+)\"\s*>/i && do {
	    my $evname=$1;
	    my $rec=$_;
	    my $event;

	    # pull the entire photo record into string
	    while (not /<\/event>/i) {
		die ("WARNING: $evname event poorly formed") if eof SRC;
		$_ = <SRC>; $rec .= $_; 
	    }
	    $rec =~ s/\s+/ /g;

	    my ($desc) = $rec =~ /<desc>\s*(.*)\s*<\/desc>/i;
	    my ($title) = $rec =~ /<title>\s*(.*)\s*<\/title>/i;

	    $event = { id => $evname };
	    $event->{desc} = $desc if $desc;
	    $event->{title} = $title if $title;

	    $EVENT{$evname} = $event;
	};


	/<photo\s+(file|name)\s*=\s*\"([\w\.]+)\"\s*>/i && do {
	    my $pixfile=$2;
	    my $rec=$_;
	    my $photo;

	    # pull the entire photo record into string
	    while (not /<\/photo>/i) {
		die ("WARNING: $pixfile note poorly formed") if eof SRC;
		$_ = <SRC>; $rec .= $_; 
	    }
	    $rec =~ s/\s+/ /g;

	    my ($desc)  = $rec =~ /<desc>\s*(.*)\s*<\/desc>/i;
	    my ($stamp) = $rec =~ /<stamp>\s*(.*)<\/stamp>/i;
	    my ($event) = $rec =~ /<event\s+ref\s*=\s*\"([\w\.]+)\"/i;

	    # look for duplicates
	    warn ("WARNING: $pixfile duplicate entries! Overwriting.") 
		if exists $PHOTO{$pixfile};

	    $photo = { file => $pixfile };
	    $photo->{desc} = $desc if $desc;
	    $photo->{stamp} = $stamp if $stamp;
	    $photo->{event} = $event if $event; # make this a list

	    $PHOTO{$pixfile} = $photo;
	    # need entry to track notes file if multiple ones.
	}
    }
    close (SRC);
}

sub save_tagfile($) {
    my ($file) = @_;
    local ($_);
    local(*DST);

    print "Saving photo notes to $file\n";

#    unlink ("$file.tmp") or die "Could not remove $file.tmp";
#    open (DST, "> $file.tmp") or die "Could not open $file.tmp";

    print "<pixtag>\n\n";

    foreach (sort keys %EVENT) {
	my $note = $EVENT{$_};
	my $id = $note->{id};
	
	print "<event id=\"$id\">\n";
	print "<stamp>", $note->{stamp}, "</stamp>\n"
	    if exists $note->{stamp};
	print "<desc>", $note->{desc}, "</desc>\n"
	    if exists $note->{desc};
	print "</event>\n";
    }

    print "\n";

    foreach (sort keys %PHOTO) {
	my $note = $PHOTO{$_};
	my $photo = $note->{file};
	
	print "<photo name=\"$photo\">\n";
	print "<event ref=\"", $note->{event}, "\" />\n"
	    if exists $note->{event};
	print "<stamp>", $note->{stamp}, "</stamp>\n"
	    if exists $note->{stamp};
	print "<desc>", $note->{desc}, "</desc>\n"
	    if exists $note->{desc};
	print "</photo>\n";
    }

    print "\n</pixtag>\n";
#    close (DST);

#    rename ("$file.tmp", $file) or die "Could not remove rename to $file";
}



1
