
# Windows --> jhead -n%%Y%%m%%d_%%H%%M%%S_dtl  file.jpg    
# Unix    --> jhead -n%Y%m%d_%H%M%S_dtl  file.jpg    

sub pixtag_make_empty_tagfile {
    my (@args) = @_;
    local ($_);
    my($event_ref);
    my($event_def);

    # take a list of files, make an empty tagfile, possibly tagged
    # with an event

    $_ = shift @args;

    /^-event$/ && do {
	# get event id, generate an empty event description for it
	$event_id = shift @args;

	$event_ref .= " <event ref=\"$event_id\" />\n";
	$event_def .= "<event id=\"$event_id\">\n <desc></desc>\n</event>\n\n";
    };

    /^-$/ && do {
	die "unknown option";
    };

    print "<pixtag>\n\n";
    print $event_def;

    foreach (@args) {
	foreach (glob $_) {   # windows globbing
	    print "<photo file=\"$_\">\n";
	    print $event_ref;
	    print " <desc></desc>\n";
	    print "</photo>\n\n";
	}
    }
    print "</pixtag>\n";
    
}

pixtag_make_empty_tagfile (@ARGV);

