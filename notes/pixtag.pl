#!/usr/bin/perl
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

use strict;
use File::Find;
use pixtag_file;

my $photo_dir = "c:\\dave\\pictures";
my $notes_dir = "c:\\dave\\pictures";

#my $master = "c:\\dave\\pictures\\loffredo.phix";
my $master = "picnic.pixtag";


sub usage {
    print <<PERL_EOF;
Usage: phix [command] [options] [files]

The commands supported by phix are as follows:

 import    - Add records for new files, possibly renaming 
             camera files to a naming convention. 

 rename    - Transfer the record for a file to a new name
 push      - Copy data from the master into picture files
 pull      - Extract data from the files and update the master
             database with it.

 find      - Search for matches on a particular field
 note      - Add note to photo

PERL_EOF
    ;
    exit(0);
}

$_ = shift;

/^help$/   && &usage;
/^import$/ && do { phix_import(@ARGV);	exit; };
/^rename$/ && do { phix_rename(@ARGV);	exit; };
/^push$/   && do { phix_push(@ARGV);	exit; };
/^pull$/   && do { phix_pull(@ARGV);	exit; };
/^find$/   && do { phix_find(@ARGV);	exit; };
/^note$/   && do { phix_note(@ARGV);	exit; };

die "$0: unknown option: $_ (use -help for usage)\n";
exit;


# ------------------------------------------------------------
# Add records for new files, possibly renaming 
# camera files to a naming convention. 
sub phix_import() {
    my (@args) = @_;
    print "importing", @args, "\n"; 

    # Add new files to the database.
    # rename the files according to the exif data
    # jhead -n "%Y%m%d_%H%M%D_dtl"


    load_tagfile ($master);
    save_tagfile ("foo");

}

# ------------------------------------------------------------
# Transfer the record for a file to a new name
sub phix_rename() {
    my (@args) = @_;
    print "renaming", @args, "\n"; 
}

# ------------------------------------------------------------
# Copy data from the master into picture files
sub phix_push() {
    my (@args) = @_;
    print "pushing data to pictures ", @args, "\n"; 
}

# ------------------------------------------------------------
# Extract data from the files and update the master
# database with it.
sub phix_pull() {
    my (@args) = @_;
    print "pulling data from pictures", @args, "\n"; 
}

