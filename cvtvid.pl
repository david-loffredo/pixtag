#!/usr/local/bin/perl

use Image::ExifTool qw(:Public);
use File::Find;

## Usage: curepix -tag dtl *.mov

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


sub usage {
    print <<PERL_EOF;
Usage: $0 [command] <options>

Convert .mov file to mp4 using ffmpeg.  Copy over the exif tags to
XML-exif ones, and add new things if needed.  Assume that mov files
are from the canon camera.

-help		Print this usage message

-cvt		Convert video to MP4 
-rename		Rename file based on original date
-tag <inits>	Use inits when renaming the file

-import		Shorthand for -cvt -rename

-fixtags	Set creation date, make, model on MP4s
-setcam <type>	Set source camera tag if not set
-forcecam <type> As above, but force tag 
		hi8 = Sony Hi8 Handycam (tapes)
		fs100 = Canon FS100 (MPEG-2)
		s200 = Canon S200 (AVIs)
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
    my $tagcount = SetMakeModel($et, $et_orig, $opts, $f);

    if ($tagcount == 0 and $datesrc eq 'ContentCreateDate') {
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

    my $tagcount = SetMakeModel($et, $et_orig, $opts, $f);

    -f $newfile && do {
	warn "FILE ALREADY EXISTS: $newfile, skipping\n";
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
    my $cmd = "ffmpeg -hide_banner -loglevel warning -i $f -c:v libx264 -preset veryslow -crf 16 -profile:v high -level 4.1 -pix_fmt $pixfmt -movflags +faststart -c:a aac -b:a 160k -metadata date=$createdate $tmpfile";
    
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


sub main {
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

    for $arg (@files) {
	foreach (sort glob $arg) {
	    /\.mov$/ && transcode_canon_mov($_, \%opts);
	    /\.mp4$/ and $fixtags && fixtags_mp4($_, \%opts);
	}
    }
    return 0;
}

exit main(@ARGV);

