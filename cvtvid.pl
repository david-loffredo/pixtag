#!/usr/local/bin/perl

use Image::ExifTool qw(:Public);

## Usage: curepix -tag dtl *.mov

## Convert .mov file to mp4 using ffmpeg.  Copy over the exif tags to
## XML-exif ones, and add new things if needed.  Assume that mov files
## are from the canon camera.

## -tag [inits]   


# check filename if mov, convert movie 
# if mpg, convert mpeg2 and deinterlace
# transfer tags from original in any case.
# for original mpg files there are not many tags.  The File
# Modification Date/Time needs to go to [XMP] Date/Time Original
# Also manually set 
#[XMP]           Make                            : Canon
#[XMP]           Camera Model Name               : Canon camera make

# this could be robust under renaming
#[XMP]           Image Unique ID                 : c657795e9df2e3362ce15babbf0485
#[XMP]           File Source                     : Digital Camera

# my $cmd2 = "ffmpeg -hide_banner -loglevel warning -i $f  -c:v copy -movflags +faststart -map_metadata 0 -map_metadata:s:v 0:s:v -c:a aac -c:a aac -b:a 160k $newfile";


sub usage {
    print <<PERL_EOF;
Usage: $0 [command] <options>

Convert .mov file to mp4 using ffmpeg.  Copy over the exif tags to
XML-exif ones, and add new things if needed.  Assume that mov files
are from the canon camera.

-help		Print this usage message
-tag <inits>	Use inits when renaming the file
-rename		Rename file using original date


PERL_EOF
;
    exit(0);
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


sub fixtags_mp4 {
    my ($f, $opts) = @_;
    my $tmpfile = 'TEMP.mp4';
    my $newfile = 'NEWFILE.mp4';
    my $origdir = 'original_createdate';

    if (-f $tmpfile) {
	unlink $tmpfile or die "Could not remove TEMP file";
    }
    
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
    
    my ($createdate, $datesrc) = SetCreateDate($et, $et_orig, $f);
    if ($datesrc eq 'ContentCreateDate') {
	print " ==> has ContentCreateDate, SKIPPING\n";
	return;
    }
    die "COULD NOT GET CREATE DATE" if not $createdate;

    print " ==> date $createdate from $datesrc\n";
    print " ==> set ContentCreateDate\n";

    -f $newfile && do {
	unlink $tmpfile or die "Could not remove NEWFILE file";
    };

    # Make new MP4 container with the create date
    my $cmd = "ffmpeg -hide_banner -loglevel warning -i $f  -c:v copy -c:a copy -movflags +faststart -metadata date=$createdate $tmpfile";
    system ($cmd) == 0 or die "Problems in FFMPEG, halting";

    # Add the other XMP tags using exiftool
    # Note that WriteInfo returns nonzero on success, zero on error
    $et->WriteInfo($tmpfile, $newfile) == 0 and 
	die "PROBLEMS WRITING metadata to $newfile, halting\n";

    rename $f, "$origdir/$f" or die "Could not rename original";
    rename $newfile, $f or die "Could not rename replacement file";

    unlink $tmpfile or warn "Could not remove TEMP file";
}


sub transcode_canon_mov {
    my ($f, $opts) = @_;
    my $newfile = $f;
    my $tmpfile = 'TEMP.mp4';
    my $origdir = 'original_movies';
    $newfile =~ s/mov$/mp4/;

    if (-f $tmpfile) {
	unlink $tmpfile or die "Could not remove TEMP file";
    }
    
    if (not -d $origdir) {
	mkdir $origdir or die "Could not create backup dir";
    }
    
    my $et_orig = new Image::ExifTool;
    $et_orig->ExtractInfo($f);

    my $et = new Image::ExifTool;
    my $datesource;

    # Do not stomp on all of the quicktime data that is in there.
    $et->SetNewValuesFromFile($f);
    
    my ($createdate, $datesrc) = SetCreateDate($et, $et_orig, $f);
    die "COULD NOT GET CREATE DATE" if not $createdate;

    if ($opts->{rename}) {
	## expect iso format 2017-02-19T16:55:55
	my $val = $createdate;
	$val =~ tr/T:-/_/d;  # make T underscore, strip colons, dash
	$newfile = "${val}_$opts->{tag}.mp4";
    }

    -f $newfile && do {
	warn "FILE ALREADY EXISTS: $newfile, skipping\n";
	return;
    };

    # The canon camera shoots with a pixel format of yuvj420p, which
    # has full 0-255 range per channel, so keep that rather than the
    # yuv420p which has a smaller range.  No need for -map_metadata 0
    # because we are adding the tags afterwards.  Compress with a CRF
    # of 16 which is basically original quality.
    

    my $cmd = "ffmpeg -hide_banner -loglevel warning -i $f -c:v libx264 -preset veryslow -crf 16 -profile:v high -level 4.1 -pix_fmt yuvj420p -movflags +faststart -c:a aac -b:a 160k -metadata date=$createdate $tmpfile";
    
    print "Converting $f\n";
    system ($cmd) == 0 or die "Problems in FFMPEG, halting";

    my $origsz = (-s $f);
    my $newsz = (-s $tmpfile);
    my $ratio = 0;
    $ratio = $newsz / $origsz unless $origsz == 0;

    if ($ratio > 0.95) {
	# Certain high-motion video will not compress much and may
	# even be larger.  If we get less than 5% saving, redo with
	# compressed audio but the original video (no transcode)
	#
	$cmd = "ffmpeg -hide_banner -loglevel warning -i $f  -c:v copy -movflags +faststart -c:a aac -c:a aac -b:a 160k -metadata date=$createdate $tmpfile";

	print sprintf(" ==> minimal savings (%d%%), keeping original video\n", (1 - $ratio) * 100);

	unlink $tmpfile or die "Could not remove TEMP file";
	system ($cmd) == 0 or die "Problems in FFMPEG, halting";

	$newsz = (-s $tmpfile);
	$ratio = $newsz / $origsz unless $origsz == 0;
    }

    # Note that WriteInfo returns nonzero on success, zero on error
    $et->WriteInfo($tmpfile, $newfile) == 0 and 
	die "PROBLEMS WRITING metadata to $newfile, halting\n";

    unlink $tmpfile or warn "Could not remove TEMP file";

    print sprintf(" ==> $newfile [saved %d%%]\n", (1 - $ratio) * 100);

    # done, rename the original
    rename $f, "$origdir/$f" or die "Could not rename original";
}



sub main {
    my %opts = (tag=>'dtl', rename=>0);
    my @files;
 
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

        /^-/ && die "$0: unknown option: $_ (use -help for usage)\n";

        push @files, $_;  # tack on as just a plain file
        shift;
    }

    for $arg (@files) {
	foreach (sort glob $arg) {
	    /\.mov$/ && transcode_canon_mov($_, \%opts);
	}
    }
    return 0;
}

exit main(@ARGV);

