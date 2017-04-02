#!/usr/local/bin/perl
# 
# PixScribe Photo Annotation Tools
# Copyright (c) 2003-2017 by David Loffredo (dave@dave.org)
# All Rights Reserved
#

use File::Find;
use Image::ExifTool qw(:Public);
use XML::LibXML;
use XML::LibXML::PrettyPrint;
use strict;

my $pkg_version = "0.2";

sub usage {
    print <<PERL_EOF;
Usage: $0 [command] <options>

Rename files to date convention, convert video to known-good MP4
settings, embed metadata for plex, and manage pixtag xml files with
picture descriptions.

The following commands are available.  Call with -help for more
information, like \"pix tagmake -help\"

 help		Print this usage message

 tagmake	Update pixtag file with files in directory.
 tagcat		Combine pixtag files
 taginfo	Search pixtag files for a photo description

 mv		Rename file and entry in tag file (if any).
 renum		Renumber a group of files and update any associated 
		annotations 
PERL_EOF
;
    exit(0);
}


# check filename if mov, convert movie 
# if mpg, convert mpeg2 and deinterlace
# transfer tags from original in any case.
# for original mpg files there are not many tags.  The File
# Modification Date/Time needs to go to [XMP] Date/Time Original
# Also manually set 
#[XMP]           Make                            : Canon
#[XMP]           Camera Model Name               : Canon camera make

# The MPEG-2 video came from a Canon FS100
# The tape video came from a Sony Hi8 Handycam
# Short AVIs came from a Canon PowerShot S200

# this could be robust under renaming
#[XMP]           Image Unique ID                 : c657795e9df2e3362ce15babbf0485
#[XMP]           File Source                     : Digital Camera



# Convert .mov file to mp4 using ffmpeg.  Copy over the exif tags to
# XML-exif ones, and add new things if needed.  Assume that mov files
# are from the canon camera.

# -help		Print this usage message

# -cvt		Convert video to MP4 
# -rename		Rename file based on original date
# -tag <inits>	Use inits when renaming the file

# -import		Shorthand for -cvt -rename

# -fixtags	Set creation date, make, model on MP4s
# -setcam <type>	Set source camera tag if not set
# -forcecam <type> As above, but force tag 
# 		hi8 = Sony Hi8 Handycam (tapes)
# 		fs100 = Canon FS100 (MPEG-2)
# 		s200 = Canon S200 (AVIs)
my $origdir = 'd:/temp/BACKUP';
my %origfiles;
my %knowncams = (
    hi8 => {
	desc => 'Sony 8mm tape camcorder',
	Make => 'Sony',
	CameraModelName => 'Sony Hi8 Handycam'
    },
    fs100 => {
	desc => 'Canon early digital camcorder',
	Make => 'Canon',
	CameraModelName => 'Canon FS100'
    },
    s200 => {
	desc => 'Our original Canon digital camera',
	Make => 'Canon',
	CameraModelName => 'Canon PowerShot S200'
    },
    sd200 => {
	desc => 'Rudy/Judy original Canon digital camera',
	Make => 'Canon',
	CameraModelName => 'Canon PowerShot SD200'
    },
    s400 => {
	desc => 'Dads original Canon digital camera',
	Make => 'Canon',
	CameraModelName => 'Canon PowerShot S400'
    },
    dsc2100 => {
	desc => 'Judy new sony camera',
	Make => 'Sony',
	CameraModelName => 'Sony DSC-S2100'
    },

    moto => {
	desc => 'Kristas Motorola Phone',
	Make => 'Motorola',
	CameraModelName => 'Motorola Moto G XT1031'
    },
    c743 => {
	desc => 'Dads Kodak Camera',
	Make => 'Eastman Kodak Company',
	CameraModelName => 'Kodak C743 Zoom Digital Camera'
    },
    vtech => {
	desc => 'Kids Play Camera',
	Make => 'VTech',
	CameraModelName => 'VTech Kidizoom Digital Camera'
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
		    $f, desc=> $photo->findvalue('./desc')
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
		compact  => [qw/desc/],
		preserves_whitespace => [qw/desc/],
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
    return $_[0] =~ /\.(jpe?g|gif|png|bmp|mpg|mov|mp4|avi|wmv)$/i;
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

    # Make the Create and Origdate consistent.  Do not worry about the
    # QuickTime CreateDate and ModifyDate fields because they are UTC
    # and are the time the video finishes.
    if ($createdate ne $origdate) {
	print " ==> set DateTimeOriginal\n";
	$et-> SetNewValue('XMP:DateTimeOriginal',$createdate);
    }

    return ($createdate, $datesource);
}

sub SetMakeModel {
    my ($et, $et_orig, $opts, $f) = @_;

    my ($maketag, $modeltag);
    if (exists $opts->{findorig}) {
	my $base = $f;
	my $cam;
	$base =~ s/\.[^\.]+//;
	$cam = $origfiles{$base}->{src} if exists $origfiles{$base};

	$maketag = $knowncams{$cam}->{Make} if $cam;
	$modeltag = $knowncams{$cam}->{CameraModelName} if $cam;
    }

    # Look for motorola video
    if ((not defined $maketag) and 
	($et_orig-> GetValue('CompressorName') eq 'MOTO'))
    {
	$maketag = $knowncams{moto}->{Make};
	$modeltag = $knowncams{moto}->{CameraModelName};
    }

    if ((not defined $maketag) and 
	($et_orig-> GetValue('Information') =~ /KODAK C743/))
    {
	$maketag = $knowncams{c743}->{Make};
	$modeltag = $knowncams{c743}->{CameraModelName};
    }

    # Fall through defaults 
    $maketag = $opts->{Make} if 
	((not defined $maketag) and (exists $opts->{Make}));

    $modeltag = $opts->{CameraModelName} if 
	((not defined $modeltag) and (exists $opts->{CameraModelName}));

    

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
    	print " ==> set CameraModelName = $modeltag\n";
	$et-> SetNewValue('XMP-tiff:Model',$modeltag);
	$numset++;
    }
    return $numset;
}



sub transcode_canon_mov {
    my ($f, $opts) = @_;
    my $tmp1file = 'TEMP1.mp4';
    my $tmp2file = 'TEMP2.mp4';
    my $origdir = 'original_files';

    if (-f $tmp1file) { unlink $tmp1file or die "Could not remove $tmp1file"; }
    if (-f $tmp2file) { unlink $tmp2file or die "Could not remove $tmp2file"; }
    
    if (not -d $origdir) {
	mkdir $origdir or die "Could not create backup dir";
    }

    print "$f\n";
    
    my $et_orig = new Image::ExifTool;
    $et_orig->ExtractInfo($f);

    my $et = new Image::ExifTool;
    my $datesource;

    # Do not stomp on all of the quicktime data that is in there.
    $et->SetNewValuesFromFile($f);

    # Check the creation date and camera info.  This sets the exiftool
    my ($createdate, $datesrc) = SetCreateDate($et, $et_orig, $f);
    my $tagcount = SetMakeModel($et, $et_orig, $opts, $f);



    
    my ($createdate, $datesrc) = SetCreateDate($et, $et_orig, $f);
    die "COULD NOT GET CREATE DATE" if not $createdate;

    if ($opts->{rename}) {
	## expect iso format 2017-02-19T16:55:55
	my $val = $createdate;
	$val =~ tr/T:-/_/d;  # make T underscore, strip colons, dash
	$tmp2file = "${val}_$opts->{tag}.mp4";
    }

    my $tagcount = SetMakeModel($et, $et_orig, $opts, $f);

    -f $tmp2file && do {
	warn "FILE ALREADY EXISTS: $tmp2file, skipping\n";
	return;
    };

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
    my $cmd = "ffmpeg -hide_banner -loglevel warning -i $f -c:v libx264 -preset veryslow -crf 16 -profile:v high -level 4.1 -pix_fmt $pixfmt -movflags +faststart -c:a aac -b:a 160k -metadata date=$createdate $tmp1file";
    
    print "Converting $f\n";
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
	$cmd = "ffmpeg -hide_banner -loglevel warning -i $f  -c:v copy -movflags +faststart -c:a aac -c:a aac -b:a 160k -metadata date=$createdate $tmp1file";

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

sub scanorig {
    # only look at real files
    return if not -f;
    return if /\.(jpg|bmp|mkv)$/;
    return if $File::Find::name =~ /original_(createdate|movies)/;

    my $base = $_;
    $base =~ s/\.[^\.]+//;
    $origfiles{$base} = { file=>$File::Find::name };
    $origfiles{$base}->{src} = 's200' if /\.avi$/;
    $origfiles{$base}->{src} = 's400' if /_jcl\.avi$/;
    $origfiles{$base}->{src} = 'sd200' if /_rz\.avi$/;
    $origfiles{$base}->{src} = 'fs100' if /\.mpg$/;
    if (/_jz\.avi$/) {
	$origfiles{$base}->{src} = 'sd200';
	$origfiles{$base}->{src} = 'dsc2100' if /^2011/;
    }
    
#    print "$base, src=$origfiles{$base}->{src}, $origfiles{$base}->{file}\n";
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

 -inc <num>	 - Use increment when renumbering.  Default is 10. 

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
	    die "time format must be HHMM\n" if not $opts{base} =~ /^\d+$/;
	    $opts{base} = $opts{base} * 100; 
	    $opts{as_time}=1; next; 
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
# MAIN ======================================================
#============================================================



sub main {
    while ($_[0]) {
        $_ = $_[0];

        /^-?help$/  && do { return usage(); };
	/^tagmake$/ && do { shift; return tagmake(@_); };
	/^tagcat$/  && do { shift; return tagcat(@_); };
	/^taginfo$/  && do { shift; return taginfo(@_); };

	/^mv$/  && do { shift; return mv_file(@_); };
	/^renum$/  && do { shift; return renum_files(@_); };
	/^rename$/  && do { shift; return rename_exif(@_); };

	print "unknown option $_\n";
	return 1;
    }
}

sub oldmain {
    my %opts = (tag=>'dtl', rename=>0);
    my @files;
    my $fixtags = 0;

    while ($_[0]) {
        $_ = $_[0];

        /^-help$/ && &usage;
	/^-tag$/ && do {
            shift; $opts{tag} = shift;
            next;
        };
	/^-rename$/ && do {
            shift; $opts{rename} = 1;
            next;
        };

	/^-fixtags$/ && do {
            shift; $fixtags = 1;
            next;
        };
	/^-(set|force)cam$/ && do {
            shift; $fixtags = 1;
	    $opts{forcecam} = 1 if $1 eq 'force';

	    my $cam = shift;
	    # look up shorthands
	    if (exists $knowncams{$cam}) {
		print "Setting camera to $knowncams{$cam}->{desc}\n";
		$opts{Make} = $knowncams{$cam}->{Make};
		$opts{CameraModelName} = $knowncams{$cam}->{CameraModelName};
	    }
	    else {
		$opts{CameraModelName} = $cam;
	    }
            next;
        };

	/^-setmake$/ && do {
            shift; $fixtags = 1;
	    $opts{Make} = shift;
	    $opts{setcam} = 1;
            next;
        };

	/^-findorig$/ && do {
	    # match original camera
	    find(\&scanorig, $origdir);
	    $opts{findorig} = 1;
	    shift; next;
	};

        /^-/ && die "$0: unknown option: $_ (use -help for usage)\n";

        push @files, $_;  # tack on as just a plain file
        shift;
    }

    for my $arg (@files) {
	foreach (sort glob $arg) {
	    /\.mov$/ && transcode_canon_mov($_, \%opts);
	    /\.mp4$/ and $fixtags && fixtags_mp4($_, \%opts);
	}
    }
    return 0;
}



exit main(@ARGV);

