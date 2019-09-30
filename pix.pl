#!/usr/local/bin/perl
# 
# PixScribe Photo Annotation Tools
# Copyright (c) 2003-2019 by David Loffredo (dave@dave.org)
# All Rights Reserved
#

# ffmpeg uses mp4 v1 containers, to use the newer one do -brand mp42


use File::Find;
use Image::ExifTool qw(:Public);
use XML::LibXML;
use XML::LibXML::PrettyPrint;
use strict;

my $pkg_version = "0.2";
my $ffmpeg = "ffmpeg -hide_banner -loglevel warning";

sub usage {
    print <<PERL_EOF;
Usage: $0 [command] <options>

Rename files to date convention, convert video to known-good MP4
settings, embed metadata for plex, and manage *.pixtag xml photo
description files.

The following commands are available.  Call with -help for more
information, like \"pix tagmake -help\"

 help		Print this usage message

 tagcat		Combine photo description files
 tagevent	Add an event to the description for photo
 taginfo	Find and print photo description 
 tagmake	Update pixtag file with files in directory.

 mv		Rename file and entry in tag file (if any).
 mvdir		Move file file and associated tags to new directory.
 renum		Renumber files and update any associated annotations.
 rename		Rename to canonical date format based on exif data. 

 cvt		Convert video to normal form
 setdate	Set the date tags in JPG or MP4 video

STILL UNDER DEVELOPMENT
 rotate		Automatically rotate and strip orientation tags (needs jhead)
PERL_EOF
;
    exit(0);
}


my %camdefs = (
    'canon-elph110' => {
	desc => 'Our 2012-2019 Canon camera (.mov)',
	Make => 'Canon',
	Model => 'Canon PowerShot ELPH110',
	cvtfn => \&transcode_canon_elph110
    },
    'canon-fs100' => {
	desc => 'Our Canon early digital SD camcorder (MPEG-2)',
	Make => 'Canon',
	Model => 'Canon FS100',
	cvtfn => \&transcode_canon_sd
    },
    'canon-s200' => {
	desc => 'Our 2002-2012 Canon camera (.avi)',
	Make => 'Canon',
	Model => 'Canon PowerShot S200',
	cvtfn => \&transcode_canon_avi
    },
    'canon-s400' => {
	desc => 'Dads original Canon digital camera (.avi)',
	Make => 'Canon',
	Model => 'Canon PowerShot S400',
	cvtfn => \&transcode_canon_avi
    },
    'canon-sd200' => {
	desc => 'Rudy/Judy original Canon digital camera (.avi)',
	Make => 'Canon',
	Model => 'Canon PowerShot SD200',
	cvtfn => \&transcode_canon_avi
    },
    'iphone-se' => {
	desc => 'Dave iPhone (.mov)',
	Make => 'Apple',
	Model => 'iPhone SE',
	cvtfn => \&transcode_iphone_se
    },
    'kodak-c743' => {
	desc => 'Dads Kodak Camera',
	Make => 'Eastman Kodak Company',
	Model => 'Kodak C743 Zoom Digital Camera'
    },
    'moto-g6' => {
	desc => 'Krista/Emma Motorola Phone',
	Make => 'Motorola',
	Model => 'Motorola Moto G6 Play XT1922'
    },
    'moto-g' => {
	desc => 'Kristas Motorola Phone',
	Make => 'Motorola',
	Model => 'Motorola Moto G XT1031'
    },
    'sony-dsc2100' => {
	desc => 'Judy new sony camera',
	Make => 'Sony',
	Model => 'Sony DSC-S2100'
    },
    'sony-dscw5' => {
	desc => 'Erik and Emilys old Sony camera',
	Make => 'Sony',
	Model => 'Sony DSC-W5',
	cvtfn => \&transcode_sony_mpeg1
    },
    'sony-hi8' => {
	desc => 'Sony 8mm camcorder (tapes)',
	Make => 'Sony',
	Model => 'Sony Hi8 Handycam'
    },
    vtech => {
	desc => 'Kids Play Camera',
	Make => 'VTech',
	Model => 'VTech Kidizoom Digital Camera'
    },
    );

#============================================================
# TAG FILE CLASS ============================================
#============================================================

## Quickie Class to handle the photo and event data
##
{
    package PixTags;

    sub new { bless { photos=> {}, events=> {} }, $_[0] }
    sub GetPhoto { return $_[0]->{photos}->{lc $_[1]}; }
    sub GetEvent { return $_[0]->{events}->{lc $_[1]}; }

    sub IsEmpty { 
	return 
	    (not scalar %{$_[0]->{events}}) and
	    (not scalar %{$_[0]->{photos}});
    }

    sub PutPhoto { 
	my $n = lc $_[1]->{file}; 
	$_[0]->{photos}->{lc $n} = $_[1]; 
    }
    sub PutEvent { 
	my $n = lc $_[1]->{id}; 
	$_[0]->{events}->{lc $n} = $_[1]; 
    }

    sub MakePhoto { 
	my ($o, $n, @args) = @_; 
	my $p = { file=>$n, events=> [], @args };
	$o->PutPhoto($p);  
	return $p;
    }
    sub MakeEvent { 
	my ($o, $n, @args) = @_; 
	my $e = { id=>$n, @args };
	$o->PutEvent($e);  
	return $e;
    }
    sub DeletePhoto { return delete $_[0]->{photos}->{lc $_[1]}; }
    sub DeleteEvent { return delete $_[0]->{events}->{lc $_[1]}; }

    # renames in hash, returns photo if present and changed.
    sub RenamePhoto {
	my ($o, $src, $dst) = @_;
	my $p = DeletePhoto($o, $src);
	if ($p) { $p->{file} = $dst; PutPhoto($o, $p); } 
	return $p;
    }
    sub RenameEvent {
	my ($o, $src, $dst) = @_;
	my $e = DeleteEvent($o, $src);
	if ($e) { $e->{id} = $dst; PutEvent($o, $e); } 
	return $e;
    }

    sub ReadXML {
	my $cls = shift;
	my $tags = $cls->new();
	foreach (@_) {
	    my $tagfile = $_;
	    my $doc = XML::LibXML->load_xml(location => $_);
	    my ($root) = $doc->findnodes('/pixscribe');

	    # old files used a different element
	    ($root) = $doc->findnodes('/pixtag') if not $root;

	    print $_, ": reading tags file\n"; 
	    foreach my $photo ($root->findnodes('./photo')) 
	    {
		my $f = $photo->findvalue('./@file');
		print $tagfile, ": duplicate photo $f\n" if $tags->GetPhoto($f);

		my $p = $tags->MakePhoto(
		    $f, 
		    desc=> $photo->findvalue('./desc'),
		    creator=> $photo->findvalue('./creator')
		    );
		
		foreach my $event ($photo->findnodes('./event')) {
		    push $p->{events}, $event->findvalue('./@ref');
		}
	    }

	    foreach my $event ($root->findnodes('./event')) {
		my $id = $event->findvalue('./@id');
		print $tagfile, ": duplicate event $id\n" if $tags->GetEvent($id);

		$tags->MakeEvent(
		    $id, desc=> $event->findvalue('./desc')
		    );
	    }
	}
	return $tags;
    }
    
    sub WriteXML {
	my ($tags, $filename) = @_;
	my $doc = XML::LibXML::Document->new();
	my $pp = XML::LibXML::PrettyPrint->new(
	    indent_string => "  ", 
	    element => {
		block    => [qw/pixscribe photo event/],
		compact  => [qw/desc creator/],
		preserves_whitespace => [qw/desc creator/],
	    }
	    );

	# undocumented: do not <desc></desc> to <desc/>
	# but also writes event refs large.
	#local $XML::LibXML::setTagCompression = 1;

	## Write each element formatted but separate by blank lines to
	## make it easier to edit by hand.
	## 
	my $root = $doc->createElement("pixscribe");
	$doc->setDocumentElement($root);

	foreach my $id (sort keys %{$tags->{events}}) {
	    my $e = $tags->{events}->{$id};

	    my $enode = $doc->createElement("event");
	    my $dnode = $doc->createElement("desc");
	    $dnode-> appendTextNode($e->{desc});

	    $enode->setAttribute('id'=> $e->{id});
	    $enode->appendChild($dnode);
	    $pp->pretty_print($enode); # modified in-place

	    $root->appendTextNode("\n\n");
	    $root->appendChild($enode);
	}

	foreach my $f (sort keys %{$tags->{photos}}) {
	    my $p = $tags->{photos}->{$f};

	    my $pnode = $doc->createElement("photo");

	    foreach my $id (@{$p->{events}}) {
		my $enode = $doc->createElement("event");
		$enode->setAttribute('ref'=> $id);
		$pnode->appendChild($enode);
	    }

	    my $dnode = $doc->createElement("desc");
	    $dnode-> appendTextNode($p->{desc});

	    
	    $pnode->setAttribute('file'=> $p->{file});
	    $pnode->appendChild($dnode);

	    if (defined $p->{creator} and $p->{creator} ne '' ) {
		my $cn = $doc->createElement("creator");
		$cn-> appendTextNode($p->{creator});
		$pnode->appendChild($cn);
	    }

	    $pp->pretty_print($pnode); # modified in-place
	    $root->appendTextNode("\n\n");

	    if ($p->{status} eq 'missing') {
		my $comment = $doc->createComment( " MISSING PHOTO " );
		$root->appendChild($comment);
		$root->appendTextNode("\n");
	    }
	    $root->appendChild($pnode);
	}

	$root->appendTextNode("\n");
	print $filename, ": saving updated file\n";

	if (defined $filename) {
	    $doc->toFile($filename);
	}
	else {
	    $doc->toFH(\*STDOUT);
	}
    }
}


sub IsMediaFile {
    return $_[0] =~ /\.(jpe?g|gif|png|bmp|mpg|mov|mod|mp4|avi|wmv)$/i;
}

sub RenameMediaFiles {
    my ($dst, $tags) = @_;

    # Move everything to a backup then to the final, so that we can
    # handle overlapping names.
    my $tagschanged;
    foreach my $f (sort keys %{$dst}) {
	my $bakfile = $dst->{$f}.'BAK';
	next if $f eq $dst->{$f};

	if (-f $bakfile) { 
	    print "$bakfile ALREADY EXISTS!\n"; 
	    delete $dst->{$f};  # strange do not try to move
	    next; 
	}
	rename $f, $bakfile;
	$tagschanged = 1 if $tags->RenamePhoto($f,$bakfile);
    }

    foreach my $f (sort keys %{$dst}) {
	my $bakfile = $dst->{$f}.'BAK';
	next if $f eq $dst->{$f};

	if (-f $dst->{$f}) {
	    print "$dst->{$f} ALREADY EXISTS!\n"; 
	    next;
	}
	rename $bakfile, $dst->{$f};
	$tagschanged = 1 if $tags->RenamePhoto($bakfile,$dst->{$f});
    }
    return $tagschanged;
}




# Exiftool refuses to set the quicktime tags used by Plex.  I suspect
# that this is just an attempt to promote XMP rather than a technical
# barrier.

# The way around this is to embed QT tags with ffmpeg, using copy
# codecs to rebuild the mp4 container.  In particular, we set the
# (c)day tag, which is used by plex to order the videos.  Next, we
# copy tags that ffmpeg strips (like XMP) using exiftool.

# Use exif lib to extract all of the metadata from the original, then
# translate the quicktime-specific tags to equivalent XMP ones and
# embed in the new file.

# Figure out the creation date, set related new tags, and return the
# creation date value as an ISO string along with the source.

sub NormalizeDate {
    my ($date) = @_;
    $date =~ s/^(\d{4}):(\d\d):(\d\d) /${1}-${2}-${3}T/;
    return $date;
}

sub GetCreateDate {
    my ($et, $filename) = @_;
    ## Find creation date from embedded metadata, may need to look in
    ## several places
    ## format is iso 2017-02-19T16:55:55
    my $date = $et-> GetValue('DateTimeOriginal');
    return (NormalizeDate($date), 'DateTimeOriginal') if $date;

    $date = $et-> GetValue('ContentCreateDate', 'Raw');
    return (NormalizeDate($date), 'ContentCreateDate') if $date;

    # We could also look at 'QuickTime:CreateDate' and ModifyDate but
    # these are done in UTC when coming off of Kristas camera so we
    # just bag it and use the VID_2017... filename encoded date.

    # Use the filename first because we might have manually set it
    # from the AVI file date or some other source.  Note that the
    # files coming from Krista's phone encode the start time for the
    # video rather than the end date.

    $date = "${1}-${2}-${3}T${4}:${5}:${6}" if 
	$filename =~ /(\d\d\d\d)(\d\d)(\d\d)_(\d\d)(\d\d)(\d\d)/;
    return ($date, 'filename') if $date;

    ## This is a 32bit UTC value, and at least with Kristas phone is
    ## the time the video finished.  Prefer the start time if possible
    my $qttime =   $et-> GetValue('CreateDate','Raw');
    if ($qttime) {
	my ($sec,$min,$hour,$mday,$mon,$year) = localtime($qttime);	
	$date = sprintf ("%04d-%02d-%02dT%02d:%02d:%02d", 
			 $year+1900,$mon+1,$mday,$hour,$min,$sec);
	return ($date, 'QT::CreateDate (UTC)');
    }

    # No proper data, make sure it is a media file
    return () unless IsMediaFile($filename);

    # Old Canon MPG files do not have any data
    $date = $et-> GetValue('FileModifyDate');
    return (NormalizeDate($date), 'FileModifyDate') if $date;

    return ();
}


sub SetCreateDate {
    my ($et, $et_orig, $filename) = @_;

    my $createdate = $et_orig-> GetValue('ContentCreateDate', 'Raw');
    my $datesource;

    $datesource = 'ContentCreateDate' if $createdate;

    # We could also look at 'QuickTime:CreateDate' and ModifyDate but
    # these are done in UTC when coming off of Kristas camera so we
    # just bag it and use the VID_2017... filename encoded date.

    # Use the filename first because we might have manually set it
    # from the AVI file date or some other source.  Note that the
    # files coming from Krista's phone encode the start time for the
    # video rather than the end date.

    if (not $createdate) {
	$createdate = "${1}-${2}-${3}T${4}:${5}:${6}" if 
	    $filename =~ /(\d\d\d\d)(\d\d)(\d\d)_(\d\d)(\d\d)(\d\d)/;
	
	$datesource = 'filename' if $createdate;
    }

    if (not $createdate) {
	# watch for manually created filenames.  Treat as noon
	$createdate = "${1}-${2}-${3}T120000" if 
	    $filename =~ /^(\d\d\d\d)(\d\d)(\d\d)_s\d+/;
	
	$datesource = 'filename' if $createdate;
    }

    ## Fall back to the embedded metadata if needed
    ## format is iso 2017-02-19T16:55:55
    my $origdate = $et-> GetNewValue('XMP:DateTimeOriginal');
    if ($origdate and not $createdate) {
	$createdate = $origdate;
	$datesource = 'XMP::DateTimeOriginal';
    }

    ## This is a 32bit UTC value, and at least with Kristas phone is
    ## the time the video finished.  Prefer the start time if possible
    my $qttime =   $et_orig-> GetValue('CreateDate','Raw');
    if ($qttime and not $createdate) {
	my ($sec,$min,$hour,$mday,$mon,$year) = localtime($qttime);	
	$createdate = sprintf ("%04d-%02d-%02dT%02d:%02d:%02d", 
			       $year+1900,$mon+1,$mday,$hour,$min,$sec);
	$datesource = 'QT::CreateDate (UTC)';
    }

    # Old Canon MPG files do not have any data
    my $moddate = $et_orig-> GetValue('FileModifyDate');
    if ($moddate and not $createdate) {
	$createdate = NormalizeDate($moddate);
	$datesource = 'FileModifyDate';
    }


    # MOVE THIS OUT INTO SET VIDEO DATES
    # Make the Create and Origdate consistent.  Do not worry about the
    # QuickTime CreateDate and ModifyDate fields because they are UTC
    # and are the time the video finishes.
    if ($createdate ne $origdate) {
	print " ==> set DateTimeOriginal ($datesource)\n";
	$et-> SetNewValue('XMP:DateTimeOriginal',$createdate);
    }

    return ($createdate, $datesource);
}

sub SetPictureDates {
    my ($et, $createdate, $datesrc) = @_;
    $et-> SetNewValue('EXIF:DateTimeOriginal',$createdate);
    $et-> SetNewValue('EXIF:CreateDate',$createdate);
    $et-> SetNewValue('EXIF:ModifyDate',$createdate);
    $et-> SetNewValue('XMP:DateAcquired',$createdate);
    $et-> SetNewValue('XMP:DateTimeOriginal',$createdate);

    print " ==> Create Date: $createdate ($datesrc)\n";
}

sub SetVideoDates {
    my ($et, $createdate, $datesrc) = @_;
    $et-> SetNewValue('XMP:DateTimeOriginal',$createdate);
    $et-> SetNewValue('XMP:CreateDate',$createdate);
    $et-> SetNewValue('XMP:ModifyDate',$createdate);
    $et-> SetNewValue('XMP:DateAcquired',$createdate);
    $et-> SetNewValue('MediaCreateDate',$createdate);
    $et-> SetNewValue('MediaModifyDate',$createdate);
    $et-> SetNewValue('TrackCreateDate',$createdate);
    $et-> SetNewValue('TrackModifyDate',$createdate);

    # FileModifyDate does not really work
    print " ==> Create Date: $createdate ($datesrc)\n";
}
sub SetVideoMake {
    my ($et, $make) = @_;
    if (defined $make) {
	$et-> SetNewValue('XMP-tiff:Make',$make);
	print " ==> Make: $make\n";
    }
}
sub SetVideoModel {
    my ($et, $model) = @_;
    if (defined $model) {
	$et-> SetNewValue('XMP-tiff:Model',$model);
	print " ==> Model: $model\n";
    }
}


sub MakeTempFile {
    my ($f, $ext) = @_;
    my $tmp = $f;
    $tmp =~ s/\.[^\.]+$/$ext/;
    die "Could not generate temp $ext name for $f" if ($tmp eq $f);
    if (-f $tmp) { unlink $tmp or die "Could not remove $tmp"; }
    return $tmp;
}



sub SetMakeModel {
    my ($et, $et_orig, $opts, $f) = @_;

    my $maketag = $opts->{Make};
    my $modeltag = $opts->{Model};

    if (defined $opts->{forcecam})
    {
	$maketag = $camdefs{$opts->{forcecam}}->{Make};
	$modeltag = $camdefs{$opts->{forcecam}}->{Model};
    }
    
    # Look for motorola video
    if ((not defined $modeltag) and 
	($et_orig-> GetValue('CompressorName') eq 'MOTO'))
    {
	$maketag = $camdefs{'moto-g'}->{Make};
	$modeltag = $camdefs{'moto-g'}->{Model};
    }

    if ((not defined $modeltag) and 
	($et_orig-> GetValue('Information') =~ /KODAK C743/))
    {
	$maketag = $camdefs{'kodak-c743'}->{Make};
	$modeltag = $camdefs{'kodak-c743'}->{Model};
    }

    my $numset = 0;
    if (defined $maketag and 
	($opts->{forcecam} or not $et-> GetNewValue('XMP-tiff:Make')))
    {
	print " ==> set Make = $maketag\n";
	$et-> SetNewValue('XMP-tiff:Make',$maketag);
	$numset++;
    }
    if (defined $modeltag and
	($opts->{forcecam} or not $et-> GetNewValue('XMP-tiff:Model')))
    {
    	print " ==> set Model = $modeltag\n";
	$et-> SetNewValue('XMP-tiff:Model',$modeltag);
	$numset++;
    }
    return $numset;
}





#============================================================
# TAG MAKE ==================================================
#============================================================

sub tagmake {
    my $usage = <<PERL_EOF;
Usage: pix tagmake [options] [<dir>]

Create a description file for all picture and video files in a
directory.  Reads all existing .pixtag files in the directory and
writes a single combined one with entries for any new media files.
Missing files are marked with XML comments.

Options are:

 -help           - print this help message.
 -clean		 - Do not read any existing .pixtag descriptions.
 -desc <msg>     - Use description <msg> for all new entries.
 -event <id>     - Add an event <id> to all new entries.  May be 
		   specified multiple times.

 -n              - Report changes, but do not write new file.

 -o <file>       - Save the updated pixtag file as <file>.  By default 
		   results are saved to the same file if there is only 
		   one input or otherwise output goes to NEWTAGS.pixtag.

 -tags <file>	 - Read existing descriptions from <file>. By default 
		   reads all .pixtag files in the directory.  This may
		   be specified multiple times.
PERL_EOF
;
    my ($dstpt, $readonly, $clean);
    my $dflt = { desc=>' ', events=>[] };
    my @srctags;
    
    while ($_[0]) {
        $_ = $_[0];

        /^-?help$/  && do { print $usage; return 0; };
	/^-desc$/ && do { shift; $dflt->{desc} = shift; next; };
	/^-clean$/ && do { shift; $clean=1; next; };
	/^-event$/ && do { shift; push @{$dflt->{events}}, shift; next; };
	/^-tags$/ && do { shift; push @srctags, shift; next; };
	/^-n$/ && do { shift; $readonly = 1; next; };
	/^-o$/ && do { shift; $dstpt = shift; next; };
	/^-/ && die "unknown option $_\n";
	last;
    }

    @srctags = <*.pixtag> if (not $clean) and (not scalar @srctags);
    $dstpt = $srctags[0] if (not $dstpt) and (scalar @srctags) == 1;
    $dstpt = 'NEWTAGS.pixtag' if (not $dstpt);
    
    my $tags = PixTags->ReadXML(@srctags);

    ## Add the events if they are not already there
    foreach my $id (@{$dflt->{events}}) {
	$tags->MakeEvent($id, desc=>' ') if not $tags->GetEvent($id);
    }
    
    ## Scan the directories and create entries if needed
    push @_, '.' if not $_[0];
    foreach my $dir (@_) {
	opendir(D, ".") || die "Can't open directory: $!\n";
	while (my $f = readdir(D)) {
	    next if not -f $f;
	    next if not IsMediaFile($f);
	    
	    my $p = $tags->GetPhoto($f);
	    $p = $tags->MakePhoto($f, status=> 'new', %{$dflt}) unless $p;
	    $p->{status} = 'ok' if not $p->{status};
	}
	closedir(D);
    }

    ## Print some info about the changes
    foreach my $f (sort keys %{$tags->{photos}}) {
	my $p = $tags->{photos}->{$f};
	$p->{status} = 'missing' if not $p->{status};
	
	print $p->{file}, ": NEW\n" if $p->{status} eq 'new';
	print $p->{file}, ": MISSING\n" if $p->{status} eq 'missing';
    }
    
    $tags->WriteXML($dstpt) if not $readonly;
}


#============================================================
# TAG CAT ===================================================
#============================================================

sub tagcat {
    my $usage = <<PERL_EOF;
Usage: pix tagcat [options] <tagfiles> ...

Combine several tag files and print the result.  
Options are:

 -help           - print this help message.
 -o <file>       - Save the updated pixtag file as <file>.  By default 
		   results are printed to STDOUT.
PERL_EOF
;
    my $dstpt;

    while ($_[0]) {
        $_ = $_[0];

        /^-?help$/  && do { print $usage; return 0; };
	/^-o$/ && do { shift; $dstpt = shift; next; };
	/^-/ && die "unknown option $_\n";
	last;
    }

    return 0 if not $_[0];
    my $tags = PixTags->ReadXML(@_);
    $tags->WriteXML($dstpt);
}

#============================================================
# TAG INFO ==================================================
#============================================================

sub taginfo {
    my $usage = <<PERL_EOF;
Usage: pix taginfo [options] <media-file> ...

Print descriptions for media files.  
Options are:

 -help		- print this help message.

 -o <file>      - Save the updated pixtag file as <file>.  By default 
		  results are saved to the same file if there is only 
		  one input or otherwise output goes to NEWTAGS.pixtag.

 -tags <file>	- Search descriptions in <file>. By default, this 
		  searches all .pixtag files in the directory.  This
		  may be specified multiple times.
PERL_EOF
;
    my @srctags;
    
    while ($_[0]) {
        $_ = $_[0];

        /^-?help$/  && do { print $usage; return 0; };
	/^-tags$/ && do { shift; push @srctags, shift; next; };
	/^-/ && die "unknown option $_\n";
	last;
    }

    @srctags = <*.pixtag> if not (scalar @srctags);
    my $tags = PixTags->ReadXML(@srctags);
    foreach my $f (@_) {
	my $p = $tags->GetPhoto($f);
	if (not $p) {
	    print $f, ": NOT FOUND\n";
	}
	print $f, "\n";
	print $p->{desc}, "\n";
	foreach my $ref (@{$p->{events}}) {
	    my $e = $tags->GetEvent($ref);
	    print $ref, "\n" if not $e;
	    print "\n", $e->{desc}, "\n" if $e;
	}
    }
}





#============================================================
# TAG EVENT  ================================================
#============================================================

sub tagevent {
    my $usage = <<PERL_EOF;
Usage: pix tagevent [options] <eventid> <media-files> ...

Add an event reference to the descriptions of media files.  
Options are:

 -help		- print this help message.

 -tags <file>	- Search descriptions in <file>. By default, this 
		  searches all .pixtag files in the directory.  This
		  may be specified multiple times.
PERL_EOF
;
    my ($dstpt);
    my @srctags;
    
    while ($_[0]) {
        $_ = $_[0];

        /^-?help$/  && do { print $usage; return 0; };
	/^-tags$/ && do { shift; push @srctags, shift; next; };
	/^-o$/ && do { shift; $dstpt = shift; next; };
	/^-/ && die "unknown option $_\n";
	last;
    }
    my $change;
    my $event = shift;
    die "must specify an event id" if not $event;

    my @files;
    for my $arg (@_) { push @files, (sort glob $arg); }

    # read any existing tags files
    @srctags = <*.pixtag> if (not scalar @srctags);
    $dstpt = $srctags[0] if (not $dstpt) and (scalar @srctags) == 1;
    $dstpt = 'NEWTAGS.pixtag' if (not $dstpt);

    my $tags = PixTags->ReadXML(@srctags);
    
    ## Add the event if not already there
    $tags->MakeEvent($event, desc=>' ') if not $tags->GetEvent($event);

    foreach my $f (@files) {
	next if not -f $f;
	next if not IsMediaFile($f);
	    
	my $p = $tags->GetPhoto($f);
	$p = $tags->MakePhoto($f, desc=>' ') unless $p;

	if (not grep /^$event$/, @{$p->{events}}) {
	    push @{$p->{events}}, $event;
	    print "$p->{file}: added event\n";
	    $change++;
	}
    }
    
    $tags->WriteXML($dstpt) if $change;
}


#============================================================
# MOVE FILE =================================================
#============================================================

sub mv_file {
    my $usage = <<PERL_EOF;
Usage: pix mv [options] <srcname> <dstname>

Renames a file and transfers the tag information to the new name.

Options are:

 -help           - print this help message.
 -o <file>       - Save the updated pixtag file as <file>.  By default 
		   results are saved to the same file if there is only 
		   one input or otherwise output goes to NEWTAGS.pixtag.

 -tags <file>	 - Read existing descriptions from <file>. By default 
		   reads all .pixtag files in the directory.  This may
		   be specified multiple times.
PERL_EOF
;
    my ($dstpt);
    my @srctags;
    
    while ($_[0]) {
        $_ = $_[0];

        /^-?help$/  && do { print $usage; return 0; };
	/^-tags$/ && do { shift; push @srctags, shift; next; };
	/^-o$/ && do { shift; $dstpt = shift; next; };
	/^-/ && die "unknown option $_\n";
	last;
    }

    my ($src, $dst) = @_;
    die "$src does not exist\n" if (not -e $src) or (not -f $src);
    die "no destination given\n" if not $dst;

    @srctags = <*.pixtag> if (not scalar @srctags);
    $dstpt = $srctags[0] if (not $dstpt) and (scalar @srctags) == 1;
    $dstpt = 'NEWTAGS.pixtag' if (not $dstpt);

    my $tags = PixTags->ReadXML(@srctags);

    rename $src,$dst or die "could not rename $src to $dst\n";
    $tags->WriteXML($dstpt) if $tags->RenamePhoto($src,$dst);
}



#============================================================
# MOVE FILE =================================================
#============================================================

sub mv_filedir {
    my $usage = <<PERL_EOF;
Usage: pix mvdir [options] <src ... > <dstdir>

Moves files from the current directory to a different one and
transfers the tag information to the new directory.

Options are:

 -help           - print this help message.
 -o <file>       - Save the updated pixtag file as <file>.  A full path 
		   to the file should be given.  By default results
		   are saved to the same file if there is only one
		   input or otherwise output goes to NEWTAGS.pixtag.

 -tags <file>	 - Read existing descriptions from <file>. By default 
		   reads all .pixtag files in the directory.  This may
		   be specified multiple times.
PERL_EOF
;
    my ($dstpt,$srcpt,$changed);
    while ($_[0]) {
        $_ = $_[0];

        /^-?help$/  && do { print $usage; return 0; };
	/^-o$/ && do { shift; $dstpt = shift; next; };
	/^-tags$/ && do { shift; $srcpt = shift; next; };

	/^-/ && die "unknown option $_\n";
	last;
    }

    my @files;
    for my $arg (@_) { push @files, (sort glob $arg); }

    my $dstdir = pop @files;
    die "$dstdir directory does not exist\n" 
	if (not -e $dstdir) or (not -d $dstdir);

    $dstdir =~ s#\\#/#g;
    ($srcpt) = <*.pixtag> if not defined $srcpt;
    ($dstpt) = <$dstdir/*.pixtag> if not defined $dstpt;
    $dstpt = "$dstdir/NEWTAGS.pixtag" if not defined $dstpt;

    my $srctags = PixTags->ReadXML($srcpt);
    my $dsttags = PixTags->ReadXML($dstpt);

    foreach my $f (@files) {
	if ((not -e $f) or (not -f $f)) {
	    warn "$f not a file or does not exist\n";
	    next;
	}

	my $p = $srctags-> DeletePhoto($f);
	if ($p) { $dsttags-> PutPhoto($p); } 

	die "$dstdir/$f exists" if -e "$dstdir/$f";

	print "$f --> $dstdir/$f\n";
	rename $f,"$dstdir/$f" or die "could not move $f to $dstdir\n";
	$changed = 1;
    }    
    $srctags->WriteXML($srcpt) if $changed;
    $dsttags->WriteXML($dstpt) if $changed;
}


#============================================================
# RENUMBER FILES ============================================
#============================================================

sub renum_files {
    my $usage = <<PERL_EOF;
Usage: pix renum [options] <files>

Renumbers files and transfers the tag information to the new name.
The file are named in the form 20171225_s0010_id.jpg, where the first
part is a date and the second part is a sequence that increments by
ten.  Use the -time option to name like 20171225_120010_id.jpg

Options are:

 -help           - print this help message.

 -date <yyyymmdd> - Renumber all files with given date.  By default,
		   tries to get the existing date from the filename.

 -force		 - Overwrite time-formatted files with sequence. 
 -forceusr <inits> - Like -usr but overwrite existing User IDs.

 -inc <num>	 - Use increment.  Default is 10 for seq, 100 for time. 

 -n		 - Print what would change but do not move.
 -o <file>       - Save the updated pixtag file as <file>.  By default 
		   results are saved to the same file if there is only 
		   one input or otherwise output goes to NEWTAGS.pixtag.

 -seq <nnnn>	 - Base for sequence numbers.  Default is zero.  The
                   photo are at base+1*inc, base+2*inc, etc.

 -tags <file>	 - Read existing descriptions from <file>. By default 
		   reads all .pixtag files in the directory.  This may
		   be specified multiple times.

 -time <hhmm>    - Use time as sequence for for renumbering.  By
		   default renumbers with a 's1234' sequence rather
		   than a time.  Time names usually start at 1200.

 -usr <inits>	 - Trailing User ID for new filenames.   Default 'dtl'.
		   Will preserve existing IDs on files.
PERL_EOF
;
    my %opts = (
	usr=>'dtl', base=>0, 
	as_time=>0, inc=>10, date=>undef, 
	force=>0, force_usr=>0, dryrun=>0);

    my $dstpt;
    my @srctags;
    
    while ($_[0]) {
        $_ = $_[0];

        /^-?help$/  && do { print $usage; return 0; };
	/^-tags$/ && do { shift; push @srctags, shift; next; };
	/^-o$/ && do { shift; $dstpt = shift; next; };

	/^-n$/ && do { shift; $opts{dryrun} = 1; next; };
	/^-force$/ && do { shift; $opts{force} = 1; next; };
	/^-forceusr$/ && do { 
	    shift; $opts{usr} = shift; $opts{force_usr} = 1; next; 
	};

	/^-usr$/ && do { shift; $opts{usr} = shift; next; };
	/^-inc$/ && do { shift; $opts{inc} = shift; next; };
	/^-seq$/ && do { shift; $opts{base} = shift; $opts{as_time}=0; next; };
	/^-time$/ && do { 
	    shift; $opts{base} = shift; 
	    if ($opts{base} =~ /^\d{4}$/) {
		$opts{base} = $opts{base} * 100; 
	    }
	    elsif ($opts{base} =~ /^\d{2}$/) {
		$opts{base} = $opts{base} * 10000; 
	    }
	    else {
		die "time format must be HH or HHMM\n";
	    }
 
	    $opts{inc}=100; 
	    $opts{as_time}=1; 
	    next; 
	};
	/^-date$/ && do { 
	    shift; $opts{date} = shift; 
	    die "date format must be YYYYMMDD\n" if not $opts{date} =~ /\d{8}$/;
	    next; 
	};
	/^-/ && die "unknown option $_\n";

	last;
    }
    my $fmt = "_s%04d_";
    $fmt = "_%06d_" if $opts{as_time};

    my @files;
    my (%bucket, %src, %dst);
    for my $arg (@_) { push @files, (sort glob $arg); }

    # sort all files into date buckets
    foreach my $f (@files) {
	next if not -f $f;

	my $date = $opts{date};
	($date) = $f =~/(\d{8})_/ if not $date;

	next if (not $date) and (not IsMediaFile($f));
	$date = 'nodate' if not $date;

	if (exists $dst{$f}) {
	    warn "$f specified multiple times"; 
	    next;
	}

	if ((not $opts{force}) and
	    (not $opts{as_time}) and
	    $f =~ /\d{8}_\d{6}/) 
	{
	    die "$f: use -force to overwrite time with sequence\n";
	}

	$dst{$f} = undef;
	$bucket{$date} = [] if not exists $bucket{$date};
	push @{$bucket{$date}}, $f;
    }

    die "Could not determine date for: \n", join "\n", @{$bucket{nodate}} if
	(exists $bucket{nodate});

    # read any existing tags files
    @srctags = <*.pixtag> if (not scalar @srctags);
    $dstpt = $srctags[0] if (not $dstpt) and (scalar @srctags) == 1;
    $dstpt = 'NEWTAGS.pixtag' if (not $dstpt);

    my $tags = PixTags->ReadXML(@srctags);

    # compute the destination names for all files
    foreach my $d (sort keys %bucket) {
	my $seq = $opts{base};
	foreach my $f (@{$bucket{$d}}) {
	    my ($ext) = $f =~ /(\.[^\.]+)$/;
	    my ($usr) = $f =~ /^\d{8}_s?\d+_([a-z]+)\./i;
	    $usr = $opts{usr} if not $usr;
	    $usr = $opts{usr} if $opts{force_usr};

	    $seq += $opts{inc};
	    my $name = $d . sprintf($fmt, $seq) . $usr . $ext;

	    die "$src{$name} and $f would both map to $name\n" if  
		exists $src{$name};

	    $dst{$f} = $name;
	    $src{$name} = $f;
	    print "$f --> $name\n" if $f ne $name;
	}
    }

    return if $opts{dryrun};
    # Move everything to a backup then to the final, so that we can
    # handle overlapping names.
    $tags->WriteXML($dstpt) if RenameMediaFiles(\%dst, $tags);
}




#============================================================
# RENAME FILES BASED ON DATE ================================
#============================================================

sub rename_exif {
    my $usage = <<PERL_EOF;
Usage: pix rename [options] <files>

Rename files using the YYYYMMMDD_HHMMSS_usr naming convention.  The
creation date is extracted from the EXIF or other metadata and any
pixtag description are preserved.

Options are:

 -help           - print this help message.

 -n		 - Print what would change but do not move.
 -o <file>       - Save the updated pixtag file as <file>.  By default 
		   results are saved to the same file if there is only 
		   one input or otherwise output goes to NEWTAGS.pixtag.

 -tags <file>	 - Read existing descriptions from <file>. By default 
		   reads all .pixtag files in the directory.  This may
		   be specified multiple times.

 -usr <inits>	 - Trailing User ID for new filenames.   Default 'dtl'.
		   Will preserve existing IDs on files.
PERL_EOF
;
    my %opts = ( usr=>'dtl', dryrun=>0 );

    my $dstpt;
    my @srctags;
    
    while ($_[0]) {
        $_ = $_[0];

        /^-?help$/  && do { print $usage; return 0; };
	/^-tags$/ && do { shift; push @srctags, shift; next; };
	/^-o$/ && do { shift; $dstpt = shift; next; };

	/^-n$/ && do { shift; $opts{dryrun} = 1; next; };
	/^-usr$/ && do { shift; $opts{usr} = shift; next; };
	/^-forceusr$/ && do { 
	    shift; $opts{usr} = shift; $opts{force_usr} = 1; next; 
	};
	/^-/ && die "unknown option $_\n";

	last;
    }
    my @files;
    my (%src, %dst);
    for my $arg (@_) { push @files, (sort glob $arg); }

    # read any existing tags files
    @srctags = <*.pixtag> if (not scalar @srctags);
    $dstpt = $srctags[0] if (not $dstpt) and (scalar @srctags) == 1;
    $dstpt = 'NEWTAGS.pixtag' if (not $dstpt);

    my $tags = PixTags->ReadXML(@srctags);
    my $et = new Image::ExifTool;

    foreach my $f (@files) {
	next if not -f $f;

	$et->ExtractInfo($f);

	my ($date,$loc) = GetCreateDate($et,$f);
	do {print "$f --> unchanged\n"; next; } unless $date;

	my ($ext) = $f =~ /(\.[^\.]+)$/;
	my ($usr) = $f =~ /^\d{8}_\d{6}_([a-z]+)\./i;
	$usr = $opts{usr} if not $usr;
	$usr = $opts{usr} if $opts{force_usr};
	$ext = lc $ext; 

	$date =~ tr/T:-/_/d;  # make T underscore, strip colons, dash
	$date =~ s/^(\d{8}_\d{6}).*$/$1/;  # drop any extra timezone

	my $name = "${date}_$usr$ext";
	
	my $seq;
	while (exists $src{$name}) {
	    warn "$name already use for $src{$name}\n";
	    $seq++;
	    $name = "${date}_$usr$seq$ext";
	}
	print "$f --> $name ($loc)\n";

	$src{$name} = $f;
	$dst{$f} = $name;
    }

    return if $opts{dryrun};
    # Move everything to a backup then to the final, so that we can
    # handle overlapping names.
    $tags->WriteXML($dstpt) if RenameMediaFiles(\%dst, $tags);
}

#============================================================
# FIX EXIF TAGS
#============================================================
sub setdate_tags {
    my $usage = <<PERL_EOF;
Usage: pix setdate [options] <mp4files>

Change embedded creation dates in a JPG or MP4 file.  By default, this
takes the date from the filename.

Options are:

 -help           - print this help message.

 -cam <name>	 - set camera make/model tags to predefined value.  See 
		   cvt for valid camera names.
 -make <val>	 - set make tag to given string.
 -model <val>	 - set model tag to given string.

PERL_EOF
;
    my %opts = (tag=>'dtl', rename=>0);
    my @files;

    while ($_[0]) {
        $_ = $_[0];
        /^-?help$/  && do { print $usage; return 0; };

	/^-cam$/ && do {
            shift; 
	    my $cam = shift;
	    if (exists $camdefs{$cam}) {
		print "Setting camera to $camdefs{$cam}->{desc}\n";
		$opts{make} = $camdefs{$cam}->{Make};
		$opts{model} = $camdefs{$cam}->{Model};
	    }
	    else {
		die "unknown camera $cam";
	    }
            next;
        };
	/^-make$/ && do {
            shift; 
	    $opts{make} = shift;
            next;
        };
	/^-model$/ && do {
            shift; 
	    $opts{model} = shift;
            next;
        };
	last;
    }

    my @files;
    my (%src, %dst);
    for my $arg (@_) { push @files, (sort glob $arg); }

    for my $f (@files) {
	if ($f =~ /\.jpg$/i) {
	    setdate_jpg($f, \%opts);
	}
	else {
	    setdate_mp4($f, \%opts);
	}
    }
}

sub setdate_mp4 {
    my ($f, $opts) = @_;

    print "$f\n";
    my $origdir = 'original_dates';
    my $tmp1file = $f;    $tmp1file =~ s/\.mp4$/_s1.mp4/i;
    my $tmp2file = $f;    $tmp2file =~ s/\.mp4$/_s2.mp4/i;

    die "Could not generate temp1 name for $f" if ($tmp1file eq $f);
    die "Could not generate temp2 name for $f" if ($tmp2file eq $f);
    
    if (-f $tmp1file) { unlink $tmp1file or die "Could not remove $tmp1file"; }
    if (-f $tmp2file) { unlink $tmp2file or die "Could not remove $tmp2file"; }
    if (not -d $origdir) {
	mkdir $origdir or die "Could not create backup dir";
    }
    
    my $et_orig = new Image::ExifTool;
    $et_orig->ExtractInfo($f);

    # Do not stomp on all of the quicktime data that is in there.
    my $et = new Image::ExifTool;
    $et->SetNewValuesFromFile($f);

    # Check the creation date and camera info.  This sets the exiftool
    my ($createdate, $datesrc);
    $createdate = "${1}-${2}-${3}T${4}:${5}:${6}" if 
	    $f =~ /(\d\d\d\d)(\d\d)(\d\d)_(\d\d)(\d\d)(\d\d)/;
	
    $datesrc = 'filename' if $createdate;
    if (not $createdate) {
	print " ==> no date found, skipping\n";
	return;
    }

    SetVideoDates($et, $createdate, $datesrc);
    SetVideoMake($et, $opts->{make});
    SetVideoMake($et, $opts->{model});

    # Make new MP4 container with ContentCreateDate
    my $cmd = "$ffmpeg -i $f  -c:v copy -c:a copy -movflags +faststart -metadata date=$createdate $tmp1file";
    system ($cmd) == 0 or die "Problems in FFMPEG, halting";

    # Note that WriteInfo returns nonzero on success, zero on error
    $et->WriteInfo($tmp1file, $tmp2file) == 0 and 
	die "PROBLEMS WRITING metadata to $tmp2file, halting\n";

    unlink $tmp1file or warn "Could not remove TEMP file";

    # done, rename the original
    rename $f, "$origdir/$f" or die "Could not rename original";
    rename $tmp2file, $f or die "Could not rename $tmp2file";
}

sub setdate_jpg {
    my ($f, $opts) = @_;
    print "$f\n";

    # Check the creation date and camera info.  This sets the exiftool
    my ($createdate, $datesrc);
    $createdate = "${1}-${2}-${3}T${4}:${5}:${6}" if 
	    $f =~ /(\d\d\d\d)(\d\d)(\d\d)_(\d\d)(\d\d)(\d\d)/;
	
    $datesrc = 'filename' if $createdate;
    if (not $createdate) {
	print " ==> no date found, skipping\n";
	return;
    }

    my $et = new Image::ExifTool;
    SetPictureDates($et, $createdate, $datesrc);

    # Note that WriteInfo returns nonzero on success, zero on error
    $et->WriteInfo($f) == 0 and 
	die "PROBLEMS WRITING metadata to $f, halting\n";
}



#============================================================
# CONVERT VIDEO FORMATS
#============================================================
sub convert_video {
    my $usage = <<PERL_EOF;
Usage: pix cvt [options] <srctype> <files>

Convert video from the given camera source to normalized mp4 using
ffmpeg.  Copy exif tags to XML-exif ones, and add new things if
needed.  The conversion varies depending on the source type.

Options are:

 -help           - print this help message.

PERL_EOF
;
    my %opts = ( usr=>'dtl', dryrun=>0 );

    while ($_[0]) {
        $_ = $_[0];

        /^-?help$/  && do { 
	    print $usage; 
	    print "Known cameras:\n\n";
	    foreach my $n (sort keys %camdefs) {
		print "  $n\n\t$camdefs{$n}->{Model}, $camdefs{$n}->{desc}\n";
	    }
	    return 0; 

	};
	/^-/ && die "unknown option $_\n";

	last;
    }

    my $srctype = shift;
    die "Unknown source type $srctype" if not exists $camdefs{$srctype}; 
    $opts{make} = $camdefs{$srctype}->{Make};
    $opts{model} = $camdefs{$srctype}->{Model};

    my @files;
    my (%src, %dst);
    for my $arg (@_) { push @files, (sort glob $arg); }

    if (exists $camdefs{$srctype}->{cvtfn}) {
	my $cvtfn = $camdefs{$srctype}->{cvtfn};
	for my $f (@files) {
	    $cvtfn->($f, \%opts);
	}
	return 0;
    }

    if (exists $camdefs{$srctype}->{cvtclass}) {
	$camdefs{$srctype}->{cvtclass}->(\@files, \%opts);
	return 0;
    }

    print "No conversion routine known for $srctype\n";
    return 0;
}


sub transcode_canon_elph110 {
    my ($f, $opts) = @_;

    print "$f\n";
    my $origdir = 'original_files';
    my $tmp1file = $f;    $tmp1file =~ s/\.(mov)$/_s1.mp4/i;
    my $tmp2file = $f;    $tmp2file =~ s/\.(mov)$/.mp4/i;

    die "Could not generate temp1 name for $f" if ($tmp1file eq $f);
    die "Could not generate temp2 name for $f" if ($tmp2file eq $f);
    
    if (-f $tmp1file) { unlink $tmp1file or die "Could not remove $tmp1file"; }
    if (-f $tmp2file) { unlink $tmp2file or die "Could not remove $tmp2file"; }
    
    if (not -d $origdir) {
	mkdir $origdir or die "Could not create backup dir";
    }

    my $et_orig = new Image::ExifTool;
    $et_orig->ExtractInfo($f);

    # Do not stomp on all of the quicktime data that is in there.
    my $et = new Image::ExifTool;
    $et->SetNewValuesFromFile($f);

    # Check the creation date and camera info.  This sets the exiftool
    my ($createdate, $datesrc) = SetCreateDate($et, $et_orig, $f);

    SetVideoDates($et, $createdate, $datesrc);
    SetVideoMake($et, $opts->{make});
    SetVideoModel($et, $opts->{model});

    # Use the same pixel format as the input data (+).  The canon
    # camera shoots with a pixel format of yuvj420p, which has full
    # 0-255 range per channel, so keep that rather than the yuv420p
    # which has a smaller range.
    #
    # The + will work for the canon too, but explicitly specify to
    # suppress a warning about the unusual format.
    my $pixfmt = '+';
    $pixfmt = 'yuvj420p' if 
	$et-> GetNewValue('XMP-tiff:Model') =~ /PowerShot ELPH 110/;

    # Compress with a CRF of 16 which is basically original quality.
    # Always convert the audio to AAC.  No need for -map_metadata 0
    # because we are adding the tags afterwards.
    my $cmd = "$ffmpeg -i $f ".
	'-c:v libx264 -preset veryslow -crf 16 -profile:v high -level 4.1 '.
	"-pix_fmt $pixfmt -movflags +faststart ".
	'-c:a aac -b:a 160k '.
	"-metadata date=$createdate $tmp1file";

    print " ==> convert audio, reencode\n";
    system ($cmd) == 0 or die "Problems in FFMPEG, halting";

    my $origsz = (-s $f);
    my $newsz = (-s $tmp1file);
    my $ratio = 0;
    $ratio = $newsz / $origsz unless $origsz == 0;

    if ($ratio > 0.95) {
	# Certain high-motion video will not compress much and may
	# even be larger.  If we get less than 5% saving, redo with
	# compressed audio but the original video (no transcode)
	#
	$cmd = "$ffmpeg -i $f  -c:v copy -movflags +faststart -c:a aac -c:a aac -b:a 160k -metadata date=$createdate $tmp1file";

	print sprintf(" ==> minimal savings (%d%%), keeping original video\n", (1 - $ratio) * 100);

	unlink $tmp1file or die "Could not remove TEMP file";
	system ($cmd) == 0 or die "Problems in FFMPEG, halting";

	$newsz = (-s $tmp1file);
	$ratio = $newsz / $origsz unless $origsz == 0;
    }

    # Note that WriteInfo returns nonzero on success, zero on error
    $et->WriteInfo($tmp1file, $tmp2file) == 0 and 
	die "PROBLEMS WRITING metadata to $tmp2file, halting\n";

    unlink $tmp1file or warn "Could not remove TEMP file";

    print sprintf(" ==> $tmp2file [saved %d%%]\n", (1 - $ratio) * 100);

    # done, rename the original
    rename $f, "$origdir/$f" or die "Could not rename original";
}


sub transcode_canon_sd {
    # Canon FS100 SD digital camcorder.  Shoots interlaced MPEG-2
    # video as .MOD files.
    # Video: mpeg2video (Main), yuv420p(tv, top first), 720x480
    #  [SAR 32:27 DAR 16:9], 29.97 fps, 29.97 tbr, 90k tbn, 59.94 tbc
    # Audio: ac3, 48000 Hz, stereo, fltp, 256 kb/s

    # Deinterlace using bwdif - Bob Weaver Deinterlacing Filter.
    # Based on yadif/w3fdif, a bit slower but pretty produces nice
    # results.  Denoise with vaguedenoiser, which does a nice job.  I
    # originally tried hqdn3d, but that produced some artifacts on
    # really noisy low light video.

    # Yadif was fast, but not very good.  Kerndeint - Donald Graft
    # adaptive kernel deinterling was not noticably better than yadif.
    # Tried nnedi but could not grok the syntax to pass a filename for
    # the weights
    my ($f, $opts) = @_;

    print "$f\n";
    my $origdir = 'original_files';
    my $tmp1file = $f;    $tmp1file =~ s/\.(mod|mpg|mkv)$/_s1.mp4/i;
    my $tmp2file = $f;    $tmp2file =~ s/\.(mod|mpg|mkv)$/.mp4/i;

    die "Could not generate temp1 name for $f" if ($tmp1file eq $f);
    die "Could not generate temp2 name for $f" if ($tmp2file eq $f);
    
    if (-f $tmp1file) { unlink $tmp1file or die "Could not remove $tmp1file"; }
    if (-f $tmp2file) { unlink $tmp2file or die "Could not remove $tmp2file"; }
    
    if (not -d $origdir) {
	mkdir $origdir or die "Could not create backup dir";
    }
    
    my $et_orig = new Image::ExifTool;
    $et_orig->ExtractInfo($f);

    # Do not stomp on all of the quicktime data that is in there.
    my $et = new Image::ExifTool;
    $et->SetNewValuesFromFile($f);

    # Check the creation date and camera info.  This sets the exiftool
    my ($createdate, $datesrc) = SetCreateDate($et, $et_orig, $f);

    SetVideoDates($et, $createdate, $datesrc);
    SetVideoMake($et, $opts->{make});
    SetVideoModel($et, $opts->{model});

    my $cmd = "$ffmpeg -i $f ".
	'-vf "bwdif,vaguedenoiser" '.
	'-c:v libx264 -preset veryslow -crf 16 -profile:v high -level 4.1 '.
	'-pix_fmt yuv420p -movflags +faststart '.
	'-c:a aac -b:a 160k '.
	"-metadata date=$createdate $tmp1file";

    print " ==> convert mpeg2, deinterlace\n";
    system ($cmd) == 0 or die "Problems in FFMPEG, halting";


    # Note that WriteInfo returns nonzero on success, zero on error
    $et->WriteInfo($tmp1file, $tmp2file) == 0 and 
	die "PROBLEMS WRITING metadata to $tmp2file, halting\n";

    unlink $tmp1file or warn "Could not remove TEMP file";

    # done, rename the original
    rename $f, "$origdir/$f" or die "Could not rename original";
}



sub transcode_canon_avi {
    # Early Canon Powershot cameras make MJPG AVIs.  The early ones
    # use slow frame rates (15/20) at 320x240.  Later versions will
    # shoot VGA at 30fps.

    # Scale up to VGA, do motion interpolation to 60fps, some light
    # sharpening, then denoise with vaguedenoiser.
    my ($f, $opts) = @_;

    print "$f\n";
    my $origdir = 'original_files';
    my $tmp1file = $f;    $tmp1file =~ s/\.avi$/_s1.mp4/i;
    my $tmp2file = $f;    $tmp2file =~ s/\.avi$/.mp4/i;

    die "Could not generate temp1 name for $f" if ($tmp1file eq $f);
    die "Could not generate temp2 name for $f" if ($tmp2file eq $f);
    
    if (-f $tmp1file) { unlink $tmp1file or die "Could not remove $tmp1file"; }
    if (-f $tmp2file) { unlink $tmp2file or die "Could not remove $tmp2file"; }
    
    if (not -d $origdir) {
	mkdir $origdir or die "Could not create backup dir";
    }
    
    my $et_orig = new Image::ExifTool;
    $et_orig->ExtractInfo($f);

    # Do not stomp on all of the quicktime data that is in there.
    my $et = new Image::ExifTool;
    $et->SetNewValuesFromFile($f);

    # Check the creation date and camera info.  This sets the exiftool
    my ($createdate, $datesrc) = SetCreateDate($et, $et_orig, $f);

    SetVideoDates($et, $createdate, $datesrc);
    SetVideoMake($et, $opts->{make});
    SetVideoModel($et, $opts->{model});

    my $cmd = "$ffmpeg -i $f ".
	'-vf "scale=640:480:flags=lanczos,'.
	'minterpolate=\'mi_mode=mci:mc_mode=aobmc:vsbmc=1\','.
#	'smartblur=1.5:-0.35:-3.5:0.65:0.25:2.0,'.
	'vaguedenoiser" '.
	'-c:v libx264 -preset veryslow -crf 16 -profile:v high -level 4.1 '.
	'-pix_fmt yuv420p -movflags +faststart '.
	'-c:a aac -b:a 160k '.
	"-metadata date=$createdate $tmp1file";

    print " ==> convert mjpg, scale, motion interpolate\n";
    system ($cmd) == 0 or die "Problems in FFMPEG, halting";

    # Note that WriteInfo returns nonzero on success, zero on error
    $et->WriteInfo($tmp1file, $tmp2file) == 0 and 
	die "PROBLEMS WRITING metadata to $tmp2file, halting\n";

    unlink $tmp1file or warn "Could not remove TEMP file";

    # done, rename the original
    rename $f, "$origdir/$f" or die "Could not rename original";
}




sub transcode_sony_mpeg1 {
    # Early Sony shoot VGA mpeg1 @ 25fps. 
    # Video: mpeg1video, yuv420p(tv), 640x480 [SAR 1:1 DAR 4:3], 
    # 104857 kb/s, 25 fps, 25 tbr, 90k tbn, 25 tbc

    # Do motion interpolation to 60fps, then denoise with
    # vaguedenoiser.  Turn off scene change detection in the motion
    # interpolation because the camera only does single-scene clips.
    my ($f, $opts) = @_;

    print "$f\n";
    my $origdir = 'original_files';
    my $tmp1file = $f;    $tmp1file =~ s/\.mpg$/_s1.mp4/i;
    my $tmp2file = $f;    $tmp2file =~ s/\.mpg$/.mp4/i;

    die "Could not generate temp1 name for $f" if ($tmp1file eq $f);
    die "Could not generate temp2 name for $f" if ($tmp2file eq $f);
    
    if (-f $tmp1file) { unlink $tmp1file or die "Could not remove $tmp1file"; }
    if (-f $tmp2file) { unlink $tmp2file or die "Could not remove $tmp2file"; }
    
    if (not -d $origdir) {
	mkdir $origdir or die "Could not create backup dir";
    }
    
    my $et_orig = new Image::ExifTool;
    $et_orig->ExtractInfo($f);

    # Do not stomp on all of the quicktime data that is in there.
    my $et = new Image::ExifTool;
    $et->SetNewValuesFromFile($f);

    # Check the creation date and camera info.  This sets the exiftool
    my ($createdate, $datesrc) = SetCreateDate($et, $et_orig, $f);

    SetVideoDates($et, $createdate, $datesrc);
    SetVideoMake($et, $opts->{make});
    SetVideoModel($et, $opts->{model});

    my $cmd = "$ffmpeg -i $f ".
	'-vf "minterpolate=\'mi_mode=mci:mc_mode=aobmc:vsbmc=1:scd=none\','.
	'vaguedenoiser" '.
	'-c:v libx264 -preset veryslow -crf 16 -profile:v high -level 4.1 '.
	'-pix_fmt yuv420p -movflags +faststart '.
	'-c:a aac -b:a 160k '.
	"-metadata date=$createdate $tmp1file";

    print " ==> convert mpeg1, motion interpolate\n";
    system ($cmd) == 0 or die "Problems in FFMPEG, halting";

    # Note that WriteInfo returns nonzero on success, zero on error
    $et->WriteInfo($tmp1file, $tmp2file) == 0 and 
	die "PROBLEMS WRITING metadata to $tmp2file, halting\n";

    unlink $tmp1file or warn "Could not remove TEMP file";

    # done, rename the original
    rename $f, "$origdir/$f" or die "Could not rename original";
}

sub transcode_iphone_se {
    # iPhone SE video is H.264 video with aac audio in a .mov
    # container.  Normal video is 30fps, but the slow motion video is
    # shot at 240fps and played at varying speed by the phone.
    my ($f, $opts) = @_;

    print "$f\n";
    my $origdir = 'original_files';
    my $tmp1file = $f;    $tmp1file =~ s/\.mov$/_s1.mp4/i;
    my $tmp2file = $f;    $tmp2file =~ s/\.mov$/.mp4/i;

    die "Could not generate temp1 name for $f" if ($tmp1file eq $f);
    die "Could not generate temp2 name for $f" if ($tmp2file eq $f);
    
    if (-f $tmp1file) { unlink $tmp1file or die "Could not remove $tmp1file"; }
    if (-f $tmp2file) { unlink $tmp2file or die "Could not remove $tmp2file"; }
    
    if (not -d $origdir) {
	mkdir $origdir or die "Could not create backup dir";
    }
    
    my $et_orig = new Image::ExifTool;
    $et_orig->ExtractInfo($f);

    # Do not stomp on all of the quicktime data that is in there.
    my $et = new Image::ExifTool;
    $et->SetNewValuesFromFile($f);

    # Check the creation date and camera info.  This sets the exiftool
    my ($createdate, $datesrc) = SetCreateDate($et, $et_orig, $f);
    my $tagcount = SetMakeModel($et, $et_orig, $opts, $f);

    # $et-> GetNewValue('XMP-tiff:Model') =~ /iPhone SE/;

    if ($et_orig-> GetValue('VideoFrameRate') > 200) {
	# Is H264 but with 240fps frame rate.  In order to actually
	# see the slow motion, convert to 30fps and strech the audio.
	# Unfortunately, ffmpeg does a crap job of streching audio so
	# we export, use the rubberband program and then reintegrate.

        print "HIGH SPEED VIDEO - slowing to 30fps and streching audio\n";
	my $wavorig = $f;    $wavorig =~ s/\.mov$/_orig.wav/i;
	my $wavslow = $f;    $wavslow =~ s/\.mov$/_slow.wav/i;

	# ffmpeg -i my_video.mp4 output_audio.wav
	system ("$ffmpeg -i $f  $wavorig") == 0 or 
	    die "Problems extracting audio, halting";

	# rubberband -t8 keeps the same pitch and sounds like poltergeist
	# rubberband -t8 -f0.125  makes everything lower

	system ("rubberband -q -t8 -f0.125 $wavorig $wavslow") == 0 or 
	    die "Problems streching audio, need rubberband\n".
	    "see https://breakfastquay.com/rubberband/\n";

	# "setpts=8.0*PTS" slows video, merge with slowed audio
	my $cmd = "$ffmpeg -i $f -i $wavslow ". 
	    '-filter:v "setpts=8.0*PTS" -r 30 -crf 16 '.
	    '-map 0:v:0 -map 1:a:0 -c:a aac -b:a 96k '.
	    "-metadata date=$createdate $tmp1file";

	print "Converting $f\n";
	system ($cmd) == 0 or die "Problems in FFMPEG, halting";

	unlink $wavorig or warn "Could not remove TEMP file";
	unlink $wavslow or warn "Could not remove TEMP file";
    }
    else {
	# Everything is already H264 with reasonable parameters. Do
	# not transcode anything, just move from a quicktime to MP4
	# container.

	my $cmd = "$ffmpeg -i $f -vcodec copy -acodec copy ".
	    "-metadata date=$createdate $tmp1file";

	print "Converting $f\n";
	system ($cmd) == 0 or die "Problems in FFMPEG, halting";
    }

    # Note that WriteInfo returns nonzero on success, zero on error
    $et->WriteInfo($tmp1file, $tmp2file) == 0 and 
	die "PROBLEMS WRITING metadata to $tmp2file, halting\n";

    unlink $tmp1file or warn "Could not remove TEMP file";
    print " ==> $tmp2file\n";

    # done, rename the original
    rename $f, "$origdir/$f" or die "Could not rename original";
}


#============================================================
# MAIN ======================================================
#============================================================



sub main {
    while ($_[0]) {
        $_ = $_[0];

        /^-?help$/  && do { return usage(); };
	/^tagcat$/  && do { shift; return tagcat(@_); };
	/^tagevent$/  && do { shift; return tagevent(@_); };
	/^taginfo$/  && do { shift; return taginfo(@_); };
	/^(tagmake|maketag)$/ && do { shift; return tagmake(@_); };

	/^mv$/  && do { shift; return mv_file(@_); };
	/^mvdir$/  && do { shift; return mv_filedir(@_); };
	/^renum$/  && do { shift; return renum_files(@_); };
	/^rename$/  && do { shift; return rename_exif(@_); };

	/^setdate$/  && do { shift; return setdate_tags(@_); };
	/^cvt$/  && do { shift; return convert_video(@_); };

	print "unknown option $_\n";
	return 1;
    }
}

exit main(@ARGV);

