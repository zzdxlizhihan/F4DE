#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
  if 0;

#
# $Id$
#
# ValidateXTM
# Authors: Martial Michel
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. 
# 
# KWSEval is an experimental system.  
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

##########
# Check we have every module (perl wise)

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

  push @f4bv, ("$f4d/../../lib", "$f4d/../../../common/lib");
}
use lib (@f4bv);

sub eo2pe {
  my $oe = join(" ", @_);
  return( ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "");
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files.";
my $warn_msg = "";
sub _warn_add { $warn_msg .= "[Warning] " . join(" ", @_) ."\n"; }

# Part of this tool
foreach my $pn ("KWSecf", "KWSEvalSTM", "KWSEvalCTM", "MMisc") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "ValidateTM ($versionkey)";

# usualy part of the Perl Core
foreach my $pn ("Getopt::Long") {
  unless (eval "use $pn; 1") {
    &_warn_add("\"$pn\" is not available on your Perl installation. ", "Please look it up on CPAN [http://search.cpan.org/]\n");
    $have_everything = 0;
  }
}

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

Getopt::Long::Configure(qw( auto_abbrev no_ignore_case ));

my $usage = &set_usage();
MMisc::ok_quit($usage) if (scalar @ARGV == 0);

####################

my $ECFfile = "";
my $CTMfile = "";
my $STMfile = "";

GetOptions
  (
   'ECF=s'    => \$ECFfile,
   'STM=s'    => \$STMfile,
   'CTM=s'    => \$CTMfile,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::error_quit("$usage")
  if (MMisc::all_blank($ECFfile, $CTMfile, $STMfile));

my $ECF = undef;
if (! MMisc::is_blank($ECFfile)) {
  print "** Loading ECF: $ECFfile\n";
  my $err = MMisc::check_file_r($ECFfile);
  MMisc::error_quit("Problem with \'--ECF\' file ($ECFfile): $err")
      if (! MMisc::is_blank($err));
  $ECF = new KWSecf($ECFfile);
}

my $CTM = undef;
if (! MMisc::is_blank($CTMfile)) {
  print "** Loading CTM: $CTMfile\n";
  my $err = MMisc::check_file_r($CTMfile);
  MMisc::error_quit("Problem with \'--CTM\' file ($CTMfile): $err")
      if (! MMisc::is_blank($err));
  $CTM = new KWSEvalCTM($CTMfile, 1);
  MMisc::error_quit("Problem with CTM file: " . $CTM->get_errormsg())
      if ($CTM->error());
}

my $STM = undef;
if (! MMisc::is_blank($STMfile)) {
  print "** Loading STM: $STMfile\n";
  my $err = MMisc::check_file_r($STMfile);
  MMisc::error_quit("Problem with \'--STM\' file ($STMfile): $err")
      if (! MMisc::is_blank($err));
  $STM = new KWSEvalSTM($STMfile, 1);
  MMisc::error_quit("Problem with STM file: " . $STM->get_errormsg())
      if ($STM->error());
}

####################
my %all = ();

my @ctm_list = ();
my %ctm_hash = ();
if (defined $CTM) {
  print "** Obtaining CTM's entries\n";
  @ctm_list = $CTM->get_fulllist();
  MMisc::error_quit("Problem obtaining content list from CTM file: " . $CTM->get_errormsg())
      if ($CTM->error());
  for (my $i = 0; $i < scalar @ctm_list; $i++) {
    my ($file, $channel, $bt, $et) = @{$ctm_list[$i]};
    @{$ctm_hash{$file}{$channel}} = [$bt, $et];
    $all{$file}{$channel}++;
  }
}

my @stm_list = ();
my %stm_hash = ();
if (defined $STM) {
  print "** Obtaining STM's entries\n";
  @stm_list = $STM->get_fulllist();
  MMisc::error_quit("Problem obtaining content list from STM file: " . $STM->get_errormsg())
      if ($STM->error());
  for (my $i = 0; $i < scalar @stm_list; $i++) {
    my ($file, $channel, $bt, $et) = @{$stm_list[$i]};
    @{$stm_hash{$file}{$channel}} = [$bt, $et];
    $all{$file}{$channel}++;
  }
}

####################
my $errc = 0;

## CTM vs STM
if (defined $CTM && defined $STM) {
  print "** Checking CTM vs STM's File/Channel pairs\n";
  my %tmp = ();
  foreach my $file (keys %all) {
    foreach my $channel (keys %{$all{$file}}) {
      if (! MMisc::safe_exists(\%ctm_hash, $file, $channel)) {
        MMisc::warn_print("[File: $file / Channel: $channel] does not exist in CTM file");
        $errc++;
      }
      if (! MMisc::safe_exists(\%stm_hash, $file, $channel)) {
        MMisc::warn_print("[File: $file / Channel: $channel] does not exist in STM file");
        $errc++;
      }
    }
  }
}

# CTM vs ECF
if (defined $CTM && defined $ECF) {
  print "** Checking CTM vs ECF's entries\n";
  for (my $i = 0; $i < scalar @ctm_list; $i++) {
    my ($file, $channel, $bt, $et) = @{$ctm_list[$i]};
    if ($ECF->FilteringTime($file, $channel, $bt, $et) == 0) {
      MMisc::warn_print("CTM's Entry [File: $file / Channel: $channel / Begtime: $bt / Endtime: $et] is not withing ECF's boundaries");
      $errc++;
    }
  } 
}

# STM vs ECF
if (defined $STM && defined $ECF) {
  print "** Checking STM vs ECF's entries\n";
  for (my $i = 0; $i < scalar @stm_list; $i++) {
    my ($file, $channel, $bt, $et) = @{$stm_list[$i]};
    if ($ECF->FilteringTime($file, $channel, $bt, $et) == 0) {
      MMisc::warn_print("STM's Entry [File: $file / Channel: $channel / Begtime: $bt / Endtime: $et] is not withing ECF's boundaries");
      $errc++;
    }
  } 
}

MMisc::ok_quit("No problems detected, file(s) pass validation") if ($errc == 0);
MMisc::error_quit("Some problems were detected");


############################################################


sub set_usage {
  my $usage = "$0 [--ECF ecfile] [--STM stmfile] [--CTM ctmfile]\n";
  $usage .= "\n";
  $usage .= "Will validate the ECF, STM or CTM by themselves or against one another\n";
  $usage .= "At least one must be specified\n";
  $usage .= "\n";
  $usage .= "  --ECF       Path to the ECF file\n";
  $usage .= "  --STM       Path to the STM file\n";
  $usage .= "  --CTM       Path to the STM file\n";
  $usage .= "\n";
  
  return($usage);
}
