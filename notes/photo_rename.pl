#!/usr/bin/perl
# $RCSfile$
# $Revision$ $Date$
# Auth: Dave Loffredo (loffredo@steptools.com)

## $usage = "Usage: $0 <prefix> <number> <files>";
$usage = "Usage: $0 <oldprefix> <newprefix> <files>";
$count=0;

# Process the command line arguments
for (@ARGV) {
    $file = $_;
    $count++;
    $newfile = sprintf "20030101_s%05d_dd.jpg", $count;

    next unless -f $file;
    next if $file eq $newfile;

    #is it a regular file?
    print "converting $file to $newfile\n";
    rename $file, $newfile;
}
