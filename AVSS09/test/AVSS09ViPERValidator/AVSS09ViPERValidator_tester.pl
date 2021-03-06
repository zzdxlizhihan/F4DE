#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#

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
}

use strict;
use F4DE_TestCore;
use MMisc;

my ($tool, $mode, @rest) = @ARGV;
MMisc::error_quit("ERROR: Tool ($tool) empty or not an executable\n")
  if ((MMisc::is_blank($tool)) || (! MMisc::is_file_x($tool)));
$tool .= " " . join(" ", @rest)
  if (scalar @rest > 0);


print "** Running AVSS09ViPERValidator tests:\n";

my $totest = 0;
my $testr = 0;
my $tn = ""; # Test name

my $t0 = F4DE_TestCore::get_currenttime();

##
$tn = "test1";
$testr += &do_simple_test($tn, "(GTF files check)", "$tool ../common/test_file?.clear.xml -g -w", "res_$tn.txt");

##
$tn = "test2";
$testr += &do_simple_test($tn, "(SYS files check)", "$tool ../common/test_file?.sys.xml ../common/test_file?.ss.xml -w", "res_$tn.txt");

##
$tn = "test3";
$testr += &do_simple_test($tn, "(DCR, DCF, Evaluate checks)", "./_special_test1.pl", "res_$tn.txt");

#####

my $elapsed = F4DE_TestCore::get_elapsedtime($t0);
my $add = "";
$add .= " [Elapsed: $elapsed seconds]" if (F4DE_TestCore::is_elapsedtime_on());

MMisc::ok_quit("All tests ok$add\n")
  if ($testr == $totest);

MMisc::error_quit("Not all test ok$add\n");

##########

sub do_simple_test {
  my ($testname, $subtype, $command, $res, $rev) = 
    MMisc::iuav(\@_, "", "", "", "", 0);

  $totest++;

  return(F4DE_TestCore::run_simpletest($testname, $subtype, $command, $res, $mode, $rev));
}
