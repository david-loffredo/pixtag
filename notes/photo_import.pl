#!/usr/bin/perl
# $RCSfile$
# $Revision$ $Date$
# Auth: Dave Loffredo (loffredo@steptools.com)

## $usage = "Usage: $0 <prefix> <number> <files>";
$usage = "Usage: $0 <oldprefix> <newprefix> <files>";
$count=0;

# Process the command line arguments
print "<phix>\n";
for (@ARGV) {
    $file = $_;

    next unless -f $file;

    print "<photo name=\"$file\">\n";
    print "<desc>\n";
    print "New Years Day 2003.\n";
    print "STEP Tools Party at Hardwick's Cottage on Loon Lake.\n";
    print "</desc>\n";
    print "</photo>\n";
}
print "</phix>\n";
