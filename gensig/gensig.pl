#!/usr/bin/perl 
#
# gensig.pl - generate a random signature bottom line

# Copyright 1999, 2004 - Claudio Clemens

# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2, or (at your option) any later version.
 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
################################################################################  
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place - Suite 330, Boston, MA 02111-1307, USA.
# This script should create a .signature file, which can be used by every
# mail-client. The .signature should be split in to files: .sig-tag (the
# tagline database) and .sig-base (the base of the signature).  The
# script only reads the base signature and append a random line from the
# sig-tag-db and copy the result to .signature. 

# Read the signature base, and count the number of lines to generate the
# random line

$VERSION='0.1';

if ("$ARGV[0]" eq "-v" || "$ARGV[0]" eq "--version" ) {
    print "gensig.pl Version: $VERSION - (c) Claudio Clemens\n";
    print "gensig.pl comes with ABSOLUTELY NO WARRANTY; for details\n";
    print "see the file COPYING.  This is free software, and you are welcome\n";
    print "to redistribute it under certain conditions.\n";
    $EXIT=1;
    shift;
}

if ("$ARGV[0]" eq "-h" || "$ARGV[0]" eq "--help") {
    print "Usage: gensig.pl [-h|--help] [-v|--version].\n\n";
    print "	-h|--help	Shows this help screen\n";
    print "	-v|--version	Shows program version\n\n";
    print "Without options do the work and generate a new signature.\n";
    $EXIT=1;
    shift;
}

if ($EXIT) {
    exit 0;
}
open(ORG, "$ENV{'HOME'}/.sig-base") || die("No sig-base found!");
while(<ORG>) {
        $size1=$size1+1;
        push(@org, $_);
}
close(ORG);


# Read the taglines data-base
open(SPR, "$ENV{'HOME'}/.sig-tag") || die("No taglines data-base found!");
while(<SPR>) {
	$size=$size+1;
	push(@spr, $_);
}
close(SPR);


# Open the signature file and paste the components
open(SIG, ">$ENV{'HOME'}/.signature");

# Write sig-base
$h=0;
while($size1>$h){
	print(SIG $org[$h]);
	$h=$h+1;
}

# Chose a line 
$zahl=int(rand($size));

# Writes the tagline and close the signature
print(SIG $spr[$zahl]);
close(SIG);

# For a sample .sig-base you can cup and paste the folloing lines
#--------- begin .sig-base -------
# Your name	e-mail		URL	TEL
# Whereyou_live		FAX
# Somethingelse
#--------- end .sig-base ---------
# Follows the sig-tag file
#--------- begin .sig-tag --------
# Something IDIOT
# Another line
# Use my gensig.pl program,
# Linux rules
#--------- end .sig-tag ----------
#
# Note: The files here should be hiden (.file), but you can chance that
# for your needs
