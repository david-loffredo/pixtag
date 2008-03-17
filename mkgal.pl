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

$columns = 6;
$title = "International STEP-NC Testing in Sweden";
$pixtag = "2008_sweden.pixtag";
$link_home = '<a href="index.html">Demostration Home</a>';

my @images = qw{
STEP-T24-group.jpg
20080311_124815_sandviken.jpg
20080311_125039_sandviken.jpg
20080311_125102_sandviken.jpg
20080311_125110_sandviken.jpg
20080311_125133_sandviken.jpg
20080311_144132_sandviken.jpg
20080311_152129_sandviken.jpg
20080311_152138_sandviken.jpg
20080311_152859_sandviken.jpg
20080312_094218_scania.jpg
20080312_094234_scania.jpg
20080312_094240_scania.jpg
20080312_110120_scania.jpg
20080312_113807_scania.jpg
20080312_113820_scania.jpg
20080312_113830_scania.jpg
20080312_114504_scania.jpg
20080312_114623_scania.jpg
20080312_114934_scania.jpg
20080312_115042_scania.jpg
20080312_115208_scania.jpg
20080312_115350_scania.jpg
20080312_115357_scania.jpg
20080312_115410_scania.jpg
20080312_120735_scania.jpg
20080312_121545_scania.jpg
20080312_151320_scania.jpg
20080312_155541_scania.jpg
20080312_160532_scania.jpg
20080312_164302_scania.jpg
20080312_182950_scania.jpg
20080312_191749_scania.jpg
20080312_191800_scania.jpg
20080312_203918_scania.jpg
20080312_203952_scania.jpg
};

sub main {
    my %files;
    my $last;

    open (DST, "> table.html");
    print DST expand ($html{header}, COLUMNS=> $Columns);

    my $count = 1;
    foreach $img (@images) {
	$files{$img} = { file=> sprintf ("photo_%03d.html", $count) };
	if ($last) {
	    $files{$img}->{prev} = $files{$last}->{file};
	    $files{$last}->{next} = $files{$img}->{file};
	}
	$last = $img;
	$count++;
    }

    # Process the filelist
    $count = 0;
    foreach $img (@images) {

	if (!($count % $columns)) {
	    print DST $html{tablerow_end} if $count;
	    print DST $html{tablerow_begin};
	}

	print DST expand ($html{link_image},
			  FILE => $files{$img}->{file},
			  PIC => $img);


	my $link_prev = "Previous Photo";
	my $link_next = "Next Photo";

	if (exists  $files{$img}->{prev}) {
	    $link_prev = qq{<A HREF="$files{$img}->{prev}">Previous Photo</A>}
	}
	if (exists  $files{$img}->{next}) {
	    $link_next = qq{<A HREF="$files{$img}->{next}">Next Photo</A>}
	}

	my $desc = "<p>" . `pix get $pixtag $img`;
	$desc =~ s/\n\n/<p>\n/g;

	open (DETAIL, "> $files{$img}->{file}");
	print DETAIL expand ($html{imghead},
			     TITLE => $title, PIC => $img,
			     LINK_PREV => $link_prev,
			     LINK_HOME => $link_home,
			     LINK_NEXT => $link_next);

	print DETAIL $desc, "\n";
	print DETAIL $html{imgtail};
	close (DETAIL);

	$count++;
    }

    print DST $html{tablerow_end};
    print DST $html{footer};

    close(DST);
}


sub expand {
    my $body = shift;
    while ($_[0]) {
	my $sub = shift;
	my $repl = shift;
	$body =~ s/%%$sub%%/$repl/g;
    }
    return $body;
}

$html{footer} = "</table>\n";
$html{header} = <<'PERL_EOF';
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
 <title>Photo Gallery</title>
 <link rel="stylesheet" href="/style.css" type="text/css">
<STYLE>
TABLE.gallery { 
	margin-top: 1em; 
	margin-bottom: 1em; 
	border: solid 1px #CCCCCC;
	border-collapse: collapse;
	}
TABLE.gallery IMG { border: none; } 
TABLE.gallery TD { 
	text-align: center;
	vertical-align: bottom; margin: 0px; padding: 5px; 
	} 
TABLE.gallery TH { 
	color: #CC0000; font-weight: bold; text-align: left;
	vertical-align: bottom; margin: 0px; padding: 5px; 
 	border-bottom: solid 1px #CCCCCC;
	} 
</STYLE>
</head>
<body>

<table class=gallery align=center>
<tr><th colspan=%%COLUMNS%%>Photo Gallery</th></tr>
PERL_EOF

$html{link_image} = <<'PERL_EOF';
<td><a href="%%FILE%%"><img src="thumb/%%PIC%%"></a></td>
PERL_EOF

$html{tablerow_begin}	= qq{<tr>\n};
$html{tablerow_end}	= qq{</tr>\n};

$html{imghead}  = <<'PERL_EOF';
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
 <title>%%TITLE%%</title>
 <link rel="stylesheet" href="/style.css" type="text/css">
</head>

<body>
<table class=sitehead><tr>
<td class=sitelogo>
<a href="/"><img src="/images/logo-site.gif" alt="STEP Tools, Inc."></a></td>
<td class=sitesearch>
 <form name="search_form" method="get" action="/search">
 <input type="hidden" name="method" value="and">
 <input type="text" name="words" size="15">
 <input type="submit" name="Submit" value="search">
 </form>
</td></tr>
</table>

<div class=sitenavtop>
<a href="/">Home</a>
 | <a href="/products/">Products</a>
 | <a href="/support/">Support</a>
 | <a href="/sc4/">SC4</a>
 | <a href="/pressroom/contactus.html">Contact Us</a>
 | <a href="/search.html">Search</a>
</div>

<div class=siteloc>
<a href="/">Home</a> &gt;
<a href="/library/">Library</a> &gt;
<a href="/library/stepnc/">STEP-NC Standard</a> &gt;
<a href="index.html">Sweden 2008</a> &gt;
Photos
</div>

<div style="text-align: center">

  %%LINK_PREV%% |
  %%LINK_HOME%% |
  %%LINK_NEXT%%

<p><img src="photo/%%PIC%%" border=0><br>
<a href="photo_orig/%%PIC%%">[Original Size]</a>

PERL_EOF

$html{imgtail}  = <<'PERL_EOF';
</div>

<div class="copyright">
Copyright &copy; 2008 STEP Tools Incorporated. All Rights Reserved<br>
<a href="/copyright.html">Legal notices and trademark attributions.</a>
</div>
</body>
</html>
PERL_EOF


main(@ARGV);
