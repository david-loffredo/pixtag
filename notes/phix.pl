#!/usr/bin/perl
# $RCSfile$
# $Revision$ $Date$
# Auth: Dave Loffredo (loffredo@steptools.com)
# 

use strict;
use File::Find;

my $photo_dir = "c:\\dave\\pictures";
my $notes_dir = "c:\\dave\\pictures";
my %NOTES;

#my $master = "c:\\dave\\pictures\\loffredo.phix";
my $master = "test.phix";


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


    load_notes_file ($master);
    dump_notes();

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


# Notes file written in an HTML/XML-like tagged format as follows
# should we keep newlines or force them to be tagged with <br>?
#
#<photo name=20030101_000001_dtl.jpg>
#<stamp>2003-05-15T14:56:24</stamp>
#<desc>
#</desc>
#</photo>

sub load_notes_file($) {
    my ($file) = @_;
    local ($_);
    local(*SRC);

    print "Loading photo notes from $file\n";
    open (SRC, "$file") or die "Could not open $file";;

    while (<SRC>) {
	/<photo\s+name=([\w\.]+)\s*>/ && do {
	    my $photo=$1;
	    my $rec=$_;
	    my $note;

	    # pull the entire photo record into string
	    while (not /<\/photo>/) {
		$_ = <SRC>; $rec .= $_; 
		warn ("WARNING: $photo note poorly formed") if eof SRC;
	    }

	    # now parse out the function names
	    my ($stamp) = $rec =~ /<stamp>\s*(.*)<\/stamp>/s;
	    my ($desc)  = $rec =~ /<desc>\s*(.*)<\/desc>/s;

	    # look for open photo
	    # look for duplicates
	    warn ("WARNING: $photo duplicate entries! Overwriting.") 
		if exists $NOTES{$photo};

	    $note = { file => $photo };
	    $note->{desc} = $desc if $desc;
	    $note->{stamp} = $stamp if $stamp;

	    $NOTES{$photo} = $note;
	    # need entry to track notes file if multiple ones.
	}
    }
    close (SRC);
}


sub save_notes_file($) {
    my ($file) = @_;
    local ($_);
    local(*DST);

    print "Saving photo notes to $file\n";

    unlink ("$file.tmp") or die "Could not remove $file.tmp";
    open (DST, "> $file.tmp") or die "Could not open $file.tmp";

    foreach (sort keys %NOTES) {
	my $note = $NOTES{$_};
	my $photo = $note->{file};
	
	print "<photo name=\"$photo\">\n";
	print "<stamp>", $note->{stamp}, "</stamp>\n"
	    if exists $note->{stamp};
	print "<desc>", $note->{desc}, "</desc>\n"
	    if exists $note->{desc};
    }
    close (DST);

    rename ("$file.tmp", $file) or die "Could not remove rename to $file";
}



sub dump_notes() {
    local ($_);
    local(*DST);

    print "PHOTO NOTES ------\n";

    foreach (sort keys %NOTES) {
	my $note = $NOTES{$_};
	my $photo = $note->{file};
	
	print "PHOTO $photo\n";
	print "   stamp=$note->{stamp}\n" if exists $note->{stamp};
	print "   desc=$note->{desc}\n"   if exists $note->{desc};
    }

    print "DONE ------\n";
}

