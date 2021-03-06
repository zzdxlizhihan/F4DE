#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
  if 0;

#
# $Id$
#
# VidAT_TrackingLog2Xml.pl
# Author: Jerome Ajot
# 
# This software was developed at the National Institute of Standards and Technology by employees of the Federal 
# Government in the course of their official duties.  Pursuant to Title 17 Section 105 of the United States Code this 
# software is not subject to copyright protection within the United States and is in the public domain. 
# 
# It is an experimental system.  
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY 
# MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;
use warnings;

my (@f4bv, $f4d);
BEGIN {
  if ( ($^V ge 5.18.0)
       && ( (! exists $ENV{PERL_HASH_SEED})
	    || ($ENV{PERL_HASH_SEED} != 0)
	    || (! exists $ENV{PERL_PERTURB_KEYS} )
	    || ($ENV{PERL_PERTURB_KEYS} != 0) )
     ) {
    print "You are using a version of perl above 5.16 ($^V); you need to run perl as:\nPERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl\n";
    exit 1;
  }

  use Cwd 'abs_path';
  use File::Basename 'dirname';
  $f4d = dirname(abs_path($0));

  push @f4bv, ($f4d);
}
use lib (@f4bv);

use VidAT_TrackingLog;

use Data::Dumper;
use Pod::Usage;

if(scalar(@ARGV) != 1)
{
	pod2usage(1);
}

my $inFile = "$ARGV[0]";

my $x = new VidAT_TrackingLog($inFile);

$x->addRefPolygon(4);
$x->addSysPolygon(4);
$x->addRefLabel();
$x->addSysLabel();
$x->addRefSnailTrail(3);
$x->addSysSnailTrail(3);
$x->addTimer();

print $x->XMLFile();

exit(0);

=head1 NAME

VidAT_TrackingLog2Xml -- Tracking log into XML file 

=head1 SYNOPSIS

B<VidAT_TrackingLog2Xml> F<log>

=head1 DESCRIPTION

The software converting tracking log file into XML. And output the XML file in the stdout.

=head1 OPTIONS

=over

=item F<log>

Input log file.

=back

=head1 ADDITIONAL TOOLS

Third part software need to be installed:

 FFmpeg <http://ffmpeg.org/>
 Ghostscript <http://pages.cs.wisc.edu/~ghost/>
 ImageMagick <http://www.imagemagick.org> with JPEG v6b support <ftp://ftp.uu.net/graphics/jpeg/>

=head1 BUGS

No known bugs.

=head1 NOTE

=head1 AUTHORS

 Jerome Ajot

=head1 VERSION

=head1 COPYRIGHT

This software was developed at the National Institute of Standards and Technology by employees of the Federal Government in the course of their official duties.  Pursuant to title 17 Section 105 of the United States Code this software is not subject to copyright protection and is in the public domain. VidAT is an experimental system.  NIST assumes no responsibility whatsoever for its use by other parties, and makes no guarantees, expressed or implied, about its quality, reliability, or any other characteristic.  We would appreciate acknowledgement if the software is used.

THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
