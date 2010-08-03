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
# Generate a gallery from an image list.  This expects three
# directories of photos:
#
#    photo_orig  == untouched
#    photo       == sized to 800x600
#    thumb       == sized to 72x53
#

$columns = 7;
$title = "International STEP-NC Demonstration - NIST 2010";
$event = "NIST 2010";
$pixtag = "nist.pixtag";
$link_home = '<a href="index.html">Demostration Home</a>';

my @images = qw{
20100616_114522_T24.jpg
20100602_145520_do.jpg
20100604_140313_do.jpg
20100605_072256_do.jpg
20100606_145502_do.jpg
20100606_150002_do.jpg
20100616_073612_jf.jpg
20100616_080305_jf.jpg
20100616_080430_jf.jpg
20100616_080840_jf.jpg
20100616_093501_jf.jpg
20100616_094502_jf.jpg
20100616_094638_jf.jpg
20100616_094728_jf.jpg
20100616_094753_jf.jpg
20100616_095544_jf.jpg
20100616_100228_jf.jpg
20100616_100543_jf.jpg
20100616_100759_jf.jpg
20100616_104834_jf.jpg
20100616_113314_jf.jpg
20100616_113419_jf.jpg
20100616_113426_jf.jpg
20100616_113435_jf.jpg
20100616_113627_jf.jpg
20100616_113642_jf.jpg
20100616_113658_jf.jpg
20100616_113722_jf.jpg
20100616_113750_jf.jpg
20100616_113853_jf.jpg
20100616_114159_jf.jpg
20100616_131101_jf.jpg
20100616_144547_jf.jpg
20100616_153744_jf.jpg
20100616_154731_jf.jpg
20100616_194146_jf.jpg
20100616_194157_jf.jpg
20100616_194204_jf.jpg
20100617_103655_jf.jpg
20100617_104832_jf.jpg
20100617_134005_jf.jpg
20100617_134308_jf.jpg
20100617_143703_jf.jpg
20100617_143715_jf.jpg
20100617_175313_jf.jpg
20100617_175424_jf.jpg
20100618_082416_jf.jpg
20100618_084503_jf.jpg
20100618_084523_jf.jpg
20100618_095603_jf.jpg
20100618_103157_jf.jpg
20100618_103232_jf.jpg
};

sub main {
    my %files;
    my $last;

    open (DST, "> table.html");
    print DST expand ($html{header}, COLUMNS=> $columns);

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
			     EVENT => $event,
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

<table class="gal-photo gallery" align=center>
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
<table class=stban><tr>
<td class=stlogo><a href=/><span class=stred>STEP</span> Tools, Inc.</a></td>
<td class=stnav>
<form name="search_form" method="get" action="/search">
<a href="/">Home</a> 
 | <a href="/products/">Products</a> 
 | <a href="/support/">Support</a>
 | <a href="/sc4/">SC4</a> 
 | <a class=stnavlast href="/pressroom/contactus.html">Contact Us</a>
<input type="hidden" name="method" value="and">
<input type="text" name="words" size="15">
<input type="submit" name="Submit" value="search">
</form>
</td></tr>
</table>
<div class=stloc>
<a href="/">Home</a> &gt;
<a href="/library/">Library</a> &gt;
<a href="/library/stepnc/">STEP-NC Standard</a> &gt;
<a href="index.html">%%EVENT%%</a> &gt;
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
Copyright &copy; 2010 STEP Tools Incorporated. All Rights Reserved<br>
<a href="/copyright.html">Legal notices and trademark attributions.</a>
</div>
</body>
</html>
PERL_EOF


main(@ARGV);
