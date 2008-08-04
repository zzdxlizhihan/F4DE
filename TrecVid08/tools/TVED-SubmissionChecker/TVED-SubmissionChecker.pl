#!/usr/bin/env perl
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs

# TrecVid08 Event Detection Submission Checker
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "TrecVid08 Event Detection Submission Checker" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

# Note: Designed for UNIX style environments (ie use cygwin under Windows).

##########
# Version

# $Id$
my $version     = "0.1b";

if ($version =~ m/b$/) {
  (my $cvs_version = '$Revision$') =~ s/[^\d\.]//g;
  $version = "$version (CVS: $cvs_version)";
}

my $versionid = "TrecVid08 Event Detection Submission Checker Version: $version";

##########
# Check we have every module (perl wise)

## First insure that we add the proper values to @INC
my ($f4b, $f4bv, $tv08pl, $tv08plv, $f4depl, $f4deplv);
BEGIN {
  $f4b = "F4DE_BASE";
  $f4bv = $ENV{$f4b} . "/lib";
  $tv08pl = "TV08_PERL_LIB";
  $tv08plv = $ENV{$tv08pl} || "../../lib"; # Default is relative to this tool's default path
  $f4depl = "F4DE_PERL_LIB";
  $f4deplv = $ENV{$f4depl} || "../../../common/lib"; # Default is relative to this tool's default path
}
use lib ($tv08plv, $f4deplv, $f4bv);

sub eo2pe {
  my @a = @_;
  my $oe = join(" ", @a);
  my $pe = ($oe !~ m%^Can\'t\s+locate%) ? "\n----- Original Error:\n $oe\n-----" : "";
  return($pe);
}

## Then try to load everything
my $have_everything = 1;
my $partofthistool = "It should have been part of this tools' files. Please check your $f4b environment variable (if you did an install, otherwise your $tv08pl and $f4depl environment variables).";
my $warn_msg = "";

# MMisc (part of this tool)
unless (eval "use MMisc; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"MMisc\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# TrecVid08ViperFile (part of this tool)
unless (eval "use TrecVid08ViperFile; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"TrecVid08ViperFile\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# TrecVid08HelperFunctions (part of this tool)
unless (eval "use TrecVid08HelperFunctions; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"TrecVid08HelperFunctions\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# TrecVid08ECF (part of this tool)
unless (eval "use TrecVid08ECF; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"TrecVid08ECF\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# TrecVid08EventList (part of this tool)
unless (eval "use TrecVid08EventList; 1") {
  my $pe = &eo2pe($@);
  &_warn_add("\"TrecVid08EventList\" is not available in your Perl installation. ", $partofthistool, $pe);
  $have_everything = 0;
}

# Getopt::Long (usualy part of the Perl Core)
unless (eval "use Getopt::Long; 1") {
  &_warn_add
    (
     "\"Getopt::Long\" is not available on your Perl installation. ",
     "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n"
    );
  $have_everything = 0;
}

# Cwd (usualy part of the Perl Core)
unless (eval "use Cwd; 1") {
  &_warn_add
    (
     "\"Cwd\" is not available on your Perl installation. ",
     "Please see \"http://search.cpan.org/search?mode=module&query=getopt%3A%3Along\" for installation information\n"
    );
  $have_everything = 0;
}

# Something missing ? Abort
if (! $have_everything) {
  print "\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n";
  exit(1);
}

# Use the long mode of Getopt
Getopt::Long::Configure(qw(auto_abbrev no_ignore_case));

########################################
# Get some values from TrecVid08ViperFile
my $dummy = new TrecVid08ViperFile();
my @ok_events = $dummy->get_full_events_list();
my @xsdfilesl = $dummy->get_required_xsd_files_list();
# We will use the '$dummy' to do checks before processing files

# Get some values from TrecVid08ECF
my $ecfobj = new TrecVid08ECF();
my @ecf_xsdfilesl = $ecfobj->get_required_xsd_files_list();

########################################
# Options processing

my $xmllint_env = "TV08_XMLLINT";
my $xsdpath_env = "TV08_XSDPATH";
my $mancmd = "perldoc -F $0";
my $usage = &set_usage();

# Default values for variables
my $xmllint = MMisc::get_env_val($xmllint_env, "");
my $xsdpath = MMisc::get_env_val($xsdpath_env, "../../data");
$xsdpath = "$f4bv/data" 
  if (($f4bv ne "/lib") && ($xsdpath eq "../../data"));
my $fps = undef;
my $ecffile = "";
my $verb = 0;
my $rtmpdir = undef;
my $wid = undef;
my $skipval = 0;
my $memdump = undef;
my $dryrun = 0;

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:                    T VW      def h          s uvwx   #

my %opt = ();
GetOptions
  (
   \%opt,
   'help',
   'version',
   'man',
   'xmllint=s'       => \$xmllint,
   'TrecVid08xsd=s'  => \$xsdpath,
   'fps=s'           => \$fps,
   'ecf=s'           => \$ecffile,
   'Verbose'         => \$verb,
   'uncompress_dir=s' => \$rtmpdir,
   'work_in_dir=s'   => \$wid,
   'skip_validation' => \$skipval,
   'WriteMemDump=s'  => \$memdump,
   'dryrun_mode'     => \$dryrun,
  ) or MMisc::error_quit("Wrong option(s) on the command line, aborting\n\n$usage\n");

MMisc::ok_quit("\n$usage\n") if ($opt{'help'});
MMisc::ok_quit("$versionid\n") if ($opt{'version'});
if ($opt{'man'}) {
  my ($r, $o, $e) = MMisc::do_system_call($mancmd);
  MMisc::error_quit("Could not run \'$mancmd\'") if ($r);
  MMisc::ok_quit($o);
}

MMisc::error_quit("No arguments left on command line\n\n$usage\n")
  if (scalar @ARGV == 0);

if ($xmllint ne "") {
  MMisc::error_quit("While trying to set \'xmllint\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xmllint($xmllint));
}

if ($xsdpath ne "") {
  MMisc::error_quit("While trying to set \'TrecVid08xsd\' (" . $dummy->get_errormsg() . ")")
    if (! $dummy->set_xsdpath($xsdpath));
}

if (defined $rtmpdir) {
  my $de = MMisc::check_dir_w($rtmpdir);
  MMisc::error_quit("Problem with \'temdir\' ($rtmpdir): $de")
    if (! MMisc::is_blank($de));
  MMisc::error_quit("\'uncompress_dir\' can not be used at the same time as \'work_in_dir\'")
    if (defined $wid);
}

if (defined $wid) {
  MMisc::error_quit("\'work_in_dir\' argument is \'dir\'")
    if (MMisc::is_blank($wid));
 MMisc::error_quit("When using \'work_in_dir\', only one information (<SITE>) should be left on the command line")
   if (scalar @ARGV > 1);
}

if ($skipval) {
  MMisc::error_quit("Can not use \'ecf\' or \'WriteMemDump\' when \'skip_validation\' is selected")
    if ( (! MMisc::is_blank($ecffile)) || (defined $memdump) );
}

if (defined $memdump) {
  my $derr = MMisc::check_dir_w($memdump);
  MMisc::error_quit("Problem with \'WriteMemDump\' 's directory ($memdump) : $derr")
    if (! MMisc::is_blank($derr));
}

my $useECF = (MMisc::is_blank($ecffile)) ? 0 : 1;
MMisc::error_quit("\'fps\' must set in order to use \'ecf\'")
    if (($useECF) && (! defined $fps));

## Loading of the ECF file
if ($useECF) {
  print "\n* Loading the ECF file\n\n";
  my ($errmsg) = TrecVid08HelperFunctions::load_ECF($ecffile, $ecfobj, $xmllint, $xsdpath, $fps);
  MMisc::error_quit("Problem loading the ECF file: $errmsg")
    if (! MMisc::is_blank($errmsg));
}

########################################

# Expected values
my @expected_ext = ( "tgz", "tar", "tar.gz", "tar.bz2", "zip" ); # keep Order
my @expected_year = ( "2008" );
my @expected_task = ( "retroED" );
my @expected_data = ( "DEV08", "EVAL08" ); # keep Order
my @expected_lang = ( "ENG" );
my @expected_input = ( "s-camera" );
my @expected_sysid_beg = ( "p-", "c-" );

my @expected_dir_output = ( "output" );

my %expected_sffn = &_set_expected_sffn();
my %exp_ext_cmd = &_set_exp_ext_cmd();

my $todo = scalar @ARGV;
my $done = 0;
foreach my $sf (@ARGV) {
  my @warnings = ();
  my @notes = ();

  my $ok = 1;
  my $tmpdir = "";
  my $site = "";
  my $err = "";

  if (! defined $wid) {
    vprint(1, "Checking \'$sf\'");
    
    my ($err, $dir, $file, $ext) = MMisc::split_dir_file_ext($sf);
    if (! MMisc::is_blank($err)) {
      &valerr($sf, $err);
      next;
    }
    
    if (MMisc::is_blank($file)) {
      &valerr($sf, "No filename detected ?");
      next;
    }
    
    vprint(1, "Checking the file extension");
    $err = &check_archive_extension($ext);
    if (! MMisc::is_blank($err)) {
      &valerr($sf, $err);
      next;
    }
    
    vprint(1, "Get the SITE and SUB-NUM information");
    ($err, $site, my $subnum) = &check_archive_name($file);
    if (! MMisc::is_blank($err)) {
      &valerr($sf, $err);
      next;
    }
    vprint(2, "<SITE> = $site | <SUB-NUM> = $subnum");
    
    vprint(1, "Uncompress archive");
    ($err, $tmpdir) = &uncompress_archive($dir, $file, $ext, $rtmpdir);
    if (! MMisc::is_blank($err)) {
      &valerr($sf, $err);
      next;
    }
  } else {
    $site = $sf;
    $tmpdir = $wid;
    my $de = MMisc::check_dir_r($tmpdir);
    MMisc::error_quit("Problem with \'work_in_dir\' directory ($tmpdir): $de")
      if (! MMisc::is_blank($de));
    vprint(1, "\'work_in_dir\' path");
    vprint(2, "<SITE> = $site");
  }
  vprint(2, "Temporary directory: $tmpdir");

  vprint(1, "Check for the output directories");
  $err = &check_for_output_dir($tmpdir);
  if (! MMisc::is_blank($err)) {
    &valerr($sf, $err);
    next;
  }

  vprint(1, "Process each output directory");
  foreach my $odir (@expected_dir_output) {
    my ($derr, $rd, $rf, $ru) = MMisc::list_dirs_files("$tmpdir/$odir");
    if (! MMisc::is_blank($derr)) {
      &valerr($sf, $derr);
      $ok = 0;
      next;
    }
    my @left = @$rf;
    push @left, @$ru;
    if (scalar @left > 0) {
      &valerr($sf, "Found more than just directories (" . join(" ", @left) . ")");
      $ok = 0;
      next;
    }
    if (scalar @$rd == 0) {
      &valerr($sf, "Found no submission directory");
      $ok = 0;
      next;
    }
    foreach my $sdir (sort @$rd) {
      vprint(2, "Checking Submission Directory ($sdir)");
      ($err, my $warn, my $note) = &check_submission_dir("$tmpdir/$odir", $sdir, $site);
      if (! MMisc::is_blank($err)) {
        &valerr($sf, $err);
        $ok = 0;
        next;
      }
      push @warnings, $warn
        if (! MMisc::is_blank($warn));
      push @notes, $note
        if (! MMisc::is_blank($note));
    }
  }

  if ($ok) {
    &valok($sf, "ok" 
           . ((scalar @notes > 0) ? (" -- NOTES : " . join(". ", @notes)) : "")
           . ((scalar @warnings > 0) ? (" -- WARNINGS: " . join(". ", @warnings)) : "") );
    $done ++;
  }
}

my @lin = ();
push @lin, "the \'skip_validation\' option was used, therefore the XML files were not checked for accuracy. Submitted archive files must have been XML validated to be accepted."
  if ($skipval);
push @lin, "the \'ecf\' option was not used, therefore your XML files were not matched against it. Submitted archive files must run this process to avoid missed elements in submission."
  if (! $useECF);
push @lin, "the \'dryrun_mode\' option was used, therefore the \'Event_Processed:\' was not looked for in your submission text file.  Submitted EVAL archive files must run this process to obtain the list of Events scored against."
  if ($dryrun);
push @lin, "the \'work_in_dir\' option was used, please rerun the program against the final archive file to confirm it is a valid submission file." 
  if (defined $wid);

MMisc::ok_quit
  (
   "All submission processed (OK: $done / Total: $todo)\n" 
   . ((scalar @lin == 0) ? "" :
      ($done ? "\nIMPORTANT NOTES:\n - " . join("\n - ", @lin) . "\n" : "")
   )
  );

########## END

sub valok {
  my ($fname, $txt) = @_;

  print "$fname: $txt\n";
}

#####

sub valerr {
  my ($fname, $txt) = @_;
  foreach (split(/\n/, $txt)) { 
    &valok($fname, "[ERROR] $_");
  }
  &valok($fname, "[ERROR] ** Please refer to the \'Submission Instructions\' (Appendix B) of the \'TRECVid Event Detection Evaluation Plan\' for more information");
}


##########

sub check_archive_extension {
  my $ext = MMisc::iuv(shift @_, "");

  return(&cmp_exp("file extension", lc($ext), @expected_ext));
}

##########

sub check_archive_name {
  my $file = MMisc::iuv(shift @_, "");

  my $et = "Archive name not of the form \'<SITE>_<SUB-NUM>\'";

  my ($lsite, $lsubnum, @left) = split(m%\_%, $file);
  
  return($et . " (leftover entries: " . join(" ", @left) . ")")
    if (scalar @left > 0);

  return($et . " (<SUB-NUM> ($lsubnum) not of the expected form: integer value starting at 1)")
    if ( ($lsubnum !~ m%^\d+$%) || ($lsubnum =~ m%^0%) );

  return("", $lsite, $lsubnum);
}

##########

sub uncompress_archive {
  my ($dir, $file, $ext, $rtmpdir) = MMisc::iuav(\@_, "", "", "", undef);

  my $tmpdir = "";
  if (! defined $rtmpdir) {
    $tmpdir = MMisc::get_tmpdir();
    return("Problem creating temporary directory", undef)
      if (! defined $tmpdir);
  } else {
    $tmpdir = $rtmpdir;
  }

  my $lf = MMisc::concat_dir_file_ext($dir, $file, $ext);

  my $pwd = Cwd::cwd();
  my $f = Cwd::abs_path($lf);

  my $ferr = MMisc::check_file_r($lf);
  return("Problem finding requested sourcefile ($lf): $ferr")
    if (! MMisc::is_blank($ferr));

  my $lext = lc($ext);
  return("Could not find extension ($ext) approved command line ?")
    if (! exists $exp_ext_cmd{$lext});

  my $cmdline = $exp_ext_cmd{$lext} . " $f";

  chdir($tmpdir);
  my ($retcode, $stdout, $stderr) = MMisc::do_system_call($cmdline);
  chdir($pwd);

  return("Problem while uncompressing archive ($stderr)", undef)
    if (! MMisc::is_blank($stderr));

  return("", $tmpdir);
}

##########

sub check_for_output_dir {
  my $tmpdir = MMisc::iuv(shift @_, "");

  return("Empty directory ?")
    if (MMisc::is_blank($tmpdir));

  my ($err, $rd, $rf, $ru) = MMisc::list_dirs_files($tmpdir);

  my @left = @$rf;
  push @left, @$ru;
  return("Found files where only directories expected (seen: " . join(" ", @left) .")")
    if (scalar @left > 0);
  
  my @d = @$rd;

  return("Found a different amount of directories in the base directory than expected (expected: " . join(" ", @expected_dir_output) . ") (seen: " . join(" ", @d) . ")")
  if (scalar @d != scalar @expected_dir_output);

  my ($ri, $ro) = MMisc::confirm_first_array_values(\@expected_dir_output, @d);
  return("Not all expected directories (" . join(" ", @expected_dir_output) . ") found")
    if (scalar @$ri != scalar @expected_dir_output);

  return("");
}


##########

sub check_submission_dir {
  my ($bd, $dir, $site) = @_;

  vprint(3, "Checking name");
  my ($lerr, my $data) = &check_name($dir, $site);
  return("[$dir : $lerr]", "") if (! MMisc::is_blank($lerr));

  vprint(3, "Checking expected directory files");
  ($lerr, my $lw, my @ep) = &check_exp_dirfiles($bd, $dir, $data);
  return("[$dir : $lerr]", "") if (! MMisc::is_blank($lerr));
  $lw = "[$dir : $lw]" if (! MMisc::is_blank($lw));
  my $nt = "";
  $nt = "[$dir : Expected_Events: " . join(" ", @ep) . "]"
    if (scalar @ep > 0);

  return("", $lw, $nt);
}

##########

sub check_name {
  my ($name, $site) = @_;

  my $et = "\'EXP-ID\' not of the form \'<SITE>_<YEAR>_<TASK>_<DATA>_<LANG>_<INPUT>_<SYSID>_<VERSION>\' : ";

  my ($lsite, $lyear, $ltask, $ldata, $llang, $linput, $lsysid, $lversion,
      @left) = split(m%\_%, $name);

  return($et . " leftover entries: " . join(" ", @left) . ". ", "")
    if (scalar @left > 0);

  return($et ." missing parameters ($name). ", "")
    if (MMisc::any_blank($lsite, $lyear, $ltask, $ldata, $llang, $linput, $lsysid, $lversion));

  my $err = "";

  $err .= " <SITE> ($lsite) is different from submission file <SITE> ($site)."
    if ($site ne $lsite);

  $err .= &cmp_exp("<YEAR>", $lyear, @expected_year);
  $err .= &cmp_exp("<TASK>", $ltask, @expected_task);
  $err .= &cmp_exp("<DATA>", $ldata, @expected_data);
  $err .= &cmp_exp("<LANG>", $llang, @expected_lang);
  $err .= &cmp_exp("<INPUT>", $linput, @expected_input);

  my $b = substr($lsysid, 0, 2);
  $err .= "<SYSID> ($lsysid) does not start by expected value (" 
    . join(" ", @expected_sysid_beg) . "). "
      if (! grep(m%^$b$%, @expected_sysid_beg));
  
  $err .= "<VERSION> ($lversion) not of the expected form: integer value starting at 1). "
    if ( ($lversion !~ m%^\d+$%) || ($lversion =~ m%^0%) || ($lversion > 19) );
  # More than 19 submissions would make anybody suspicious ;)

  return($et . $err, "")
    if (! MMisc::is_blank($err));

  vprint(4, "<SITE> = $lsite | <YEAR> = $lyear | <TASK> = $ltask | <DATA> = $ldata | <LANG> = $llang | <INPUT> = $linput | <SYSID> = $lsysid | <VERSION> = $lversion");

  return("", $ldata);
}

##########

sub check_exp_dirfiles {
  my ($bd, $exp, $data) = @_;

  my ($derr, $rd, $rf, $ru) = MMisc::list_dirs_files("$bd/$exp");
  return($derr, "")
    if (! MMisc::is_blank($derr));

  my @left = @$rd;
  push @left, @$ru;
  return("Found more than just files (" . join(" ", @left) . ")", "")
    if (scalar @left > 0);

  return("Found no files", "")
    if (scalar @$rf == 0);

  my %leftf = MMisc::array1d_to_count_hash(@$rf);
  vprint(4, "Checking for expected text file");
  my $expected_exp = "$exp.txt";
  my @txtf = grep(m%\.txt$%, @$rf);
  return("Found no \'.txt\' file. ", "")
    if (scalar @txtf == 0);
  return("Found more than the one expected \'.txt\' file :" . join(" ", @txtf) . ")", "")
    if (scalar @txtf > 1);
  return("Could not find the expected \'.txt\' file ($expected_exp) (seen: " . join(" ", @txtf) . ")", "")
    if (! grep(m%$expected_exp$%, @txtf));
  vprint(5, "Found: $expected_exp" . (($dryrun) ? " (dryrun_mode: skipping content check)" : "") );

  my @events_processed = ();
  if (! $dryrun) {
    ($derr, @events_processed) = &get_events_processed("$bd/$exp", $expected_exp);
    return($derr, "")
      if (! MMisc::is_blank($derr));
    return("No event found in \'Events_Processed:\' line ?", "")
      if (scalar @events_processed == 0);
  }
  delete $leftf{$expected_exp};

  vprint(4, "Checking for XML files");
  my @xmlf = grep(m%\.xml$%, @$rf);
  return("Found no \'.xml\' file. ", "")
    if (scalar @xmlf == 0);
  foreach my $xf (@xmlf) { delete $leftf{$xf}; }
  return("More than just \'.txt\' and \'.xml\' files in directory (" . join(" ", keys %leftf) . ")", "")
    if (scalar keys %leftf > 0);
  vprint(5, "Found: " . join(" ", @xmlf));

  # Try to validate the XML file
  my $errs = "";
  my $warns = "";
  if (! $skipval) {
    foreach my $xf (@xmlf) {
      vprint(4, "Trying to validate XML file ($xf)");
      my ($e, $w) = validate_xml("$bd/$exp", $xf, $data, $exp, @events_processed);
      if (! MMisc::is_blank($e)) {
        vprint(5, "ERROR: $e");
        $errs .= "[$xf : $e] ";
      }
      if (! MMisc::is_blank($w)) {
        vprint(5, "WARNING: $w");
        $warns .= "[$xf : $w] ";
      }
    }
  }
  
  if ($useECF) {
    my ($err, $rmiss, $rnotin) = TrecVid08HelperFunctions::confirm_all_ECF_sffn_are_listed($ecfobj, @xmlf);
    return("Problem obtaining file list from ECF", $warns)
      if (! MMisc::is_blank($err));
    $warns .= "Will not be able to perform soring (comparing ECF to common list); the following referred to files are present in the ECF but where not found in the submission: " . join(" ", @$rmiss) . ". "
      if (scalar @$rmiss > 0);
    $warns .= "FYI: the following referred to files are not listed in the ECF, and therefore will not be scored against: ", join(" ", @$rnotin) . ". " 
      if (scalar @$rnotin > 0);
  }

  return($errs, $warns, @events_processed);
}

##########

sub get_events_processed {
  my $dir = shift @_;
  my $file = shift @_;

  my $fn = "$dir/$file";

  vprint(4, "Checking for \'Events_Processed:\' line in txt file");
  
  my @ep = ();

  my $err = MMisc::check_file_r($fn);
  return("Problem with file ($file): $err", @ep)
    if (! MMisc::is_blank($err));

  my $fc = MMisc::slurp_file($fn);
  return("Problem reading txt file ($file)", @ep)
    if (! defined $fc);

  if ($fc =~ m%^Events_Processed:(.+)$%m) {
    my $el = MMisc::clean_begend_spaces($1);
    print "[$el]\n";
    $fc =~ s%^Events_Processed:(.+)$%%m;
    return("Multiple \'Events_Processed:\' lines found in txt file", @ep) 
      if ($fc =~ m%^Events_Processed:(.+)$%m);
    my @tep = split(m%\s+%, $el);
    @tep = $dummy->validate_events_list(@tep);
    return("Problem validating file's event list (" . $dummy->get_errormsg() . ")", @ep)
      if ($dummy->error());
    @ep = @tep;
  } else {
    return("Could not find the \'Events_Processed:\' line in file ($file)", @ep);
  }

  vprint(5, "Events Processed: " . join(" ", @ep));
  return("", @ep);
}

##########

sub validate_xml {
  my ($dir, $xf, $data, $exp, @events_processed) = @_;

  my $warn = "";

  vprint(5, "Loading ViperFile");
  my $tmp = "$dir/$xf";
  my ($retstatus, $object, $msg) = 
    TrecVid08HelperFunctions::load_ViperFile(0, $tmp, 
					     $fps, $xmllint, $xsdpath);

  return($msg, $warn)
    if (! $retstatus);

  vprint(5, "Confirming sourcefile filename is proper");
  my $sffn = $object->get_sourcefile_filename();
  return("Problem obtaining the sourcefile's filename (" . $object->get_errormsg() . ")", $warn)
    if ($object->error());
  
  my ($derr, $dir, $exp_key, $ext) = MMisc::split_dir_file_ext($xf);
  return("Problem splitting file and extension for ($xf)", "")
    if (! MMisc::is_blank($derr));
  
  return("Could not find matching sourcefile filename for <DATA> ($data) and xml file ($xf)", "")
    if (! exists $expected_sffn{$data}{$exp_key});
  
  my $exp_sffn = $expected_sffn{$data}{$exp_key};
  return("Sourcefile's filename is wrong (is: $sffn) (expected: $exp_sffn)", $warn)
    if ($sffn !~ m%$exp_sffn$%);
  
  my ($bettxt, $bte, $btot) = $object->get_txt_and_number_of_events(2);
  return("Problem obtaining the number of events (" . $object->get_errormsg() . ")", $warn)
    if ($object->error());

  $warn .= "Found no events in file. "
    if ($btot == 0);

  $warn .= &write_memdump_file($object, $exp, $xf)
    if (defined $memdump);
  
  return("", $warn)
    if (! $useECF);

  vprint(5, "Applying ECF file ($ecffile) to ViperFile");
  my ($lerr, $nobject) =
    TrecVid08HelperFunctions::get_new_ViperFile_from_ViperFile_and_ECF($object, $ecfobj);
  return($lerr, $warn)
    if (! MMisc::is_blank($lerr));
  return("Problem with ViperFile object", $warn)
    if (! defined $nobject);

  my ($aettxt, $ate, $atot) = $nobject->get_txt_and_number_of_events(2);
  return("Problem obtaining the number of events (after ECF) (" . $nobject->get_errormsg() . ")", $warn)
    if ($nobject->error());

  $warn .= "Total number of events changed from before ($btot / Events: $bettxt) to after applying the ECF ($atot / Events: $aettxt). "
    if ($atot != $btot);

  if (scalar @events_processed > 0) {
    my @ue = $nobject->list_used_events();
    my ($ri, $ro) = MMisc::confirm_first_array_values(\@ue, @events_processed);
    return("Some events found in file that were not in the \'Events_Processed:\' list: " . join(" ", @$ri) . ".", $warn)
      if (scalar @$ri > 0);
  }

  return("", $warn);
}

##########

sub write_memdump_file {
  return("") if (! defined $memdump);

  my ($vf, $diradd, $fname) = @_;

  my $dd = "$memdump/$diradd";

  return("In \'WriteMemDump\' problem creating output directory ($dd)")
    if (! MMisc::make_dir($dd));

  my $derr = MMisc::check_dir_w($dd);
  return("In \'WriteMemDump\', output directory problem: $derr")
    if (! MMisc::is_blank($derr));

  my $of = "$dd/$fname";
  my $ok = TrecVid08HelperFunctions::save_ViperFile_MemDump($of, $vf, "gzip", 0);
  return("In \'WriteMemDump\', a problem occurred while writing the output file ($of)")
    if (! $ok);

  return("");
}

##########

sub cmp_exp {
  my ($t, $v, @e) = @_;

  return("$t ($v) does not compare to expected value (" . join(" ", @e) ."). ")
    if (! grep(m%^$v$%, @e));

  return("");
}

##########

sub vprint {
  return if (! $verb);

  my $s = "********************";


  print substr($s, 0, shift @_), " ", join("", @_), "\n";
}

############################################################

sub _set_expected_sffn {
  my %tmp = (
    $expected_data[0] =>
    {
     'LGW_20071101_E1_CAM1' => 'LGW_20071101_E1_CAM1.mpeg',
     'LGW_20071101_E1_CAM2' => 'LGW_20071101_E1_CAM2.mpeg',
     'LGW_20071101_E1_CAM3' => 'LGW_20071101_E1_CAM3.mpeg',
     'LGW_20071101_E1_CAM4' => 'LGW_20071101_E1_CAM4.mpeg',
     'LGW_20071101_E1_CAM5' => 'LGW_20071101_E1_CAM5.mpeg',
     'LGW_20071106_E1_CAM1' => 'LGW_20071106_E1_CAM1.mpeg',
     'LGW_20071106_E1_CAM2' => 'LGW_20071106_E1_CAM2.mpeg',
     'LGW_20071106_E1_CAM3' => 'LGW_20071106_E1_CAM3.mpeg',
     'LGW_20071106_E1_CAM4' => 'LGW_20071106_E1_CAM4.mpeg',
     'LGW_20071106_E1_CAM5' => 'LGW_20071106_E1_CAM5.mpeg',
     'LGW_20071107_E1_CAM1' => 'LGW_20071107_E1_CAM1.mpeg',
     'LGW_20071107_E1_CAM2' => 'LGW_20071107_E1_CAM2.mpeg',
     'LGW_20071107_E1_CAM3' => 'LGW_20071107_E1_CAM3.mpeg',
     'LGW_20071107_E1_CAM4' => 'LGW_20071107_E1_CAM4.mpeg',
     'LGW_20071107_E1_CAM5' => 'LGW_20071107_E1_CAM5.mpeg',
     'LGW_20071108_E1_CAM1' => 'LGW_20071108_E1_CAM1.mpeg',
     'LGW_20071108_E1_CAM2' => 'LGW_20071108_E1_CAM2.mpeg',
     'LGW_20071108_E1_CAM3' => 'LGW_20071108_E1_CAM3.mpeg',
     'LGW_20071108_E1_CAM4' => 'LGW_20071108_E1_CAM4.mpeg',
     'LGW_20071108_E1_CAM5' => 'LGW_20071108_E1_CAM5.mpeg',
     'LGW_20071112_E1_CAM1' => 'LGW_20071112_E1_CAM1.mpeg',
     'LGW_20071112_E1_CAM2' => 'LGW_20071112_E1_CAM2.mpeg',
     'LGW_20071112_E1_CAM3' => 'LGW_20071112_E1_CAM3.mpeg',
     'LGW_20071112_E1_CAM4' => 'LGW_20071112_E1_CAM4.mpeg',
     'LGW_20071112_E1_CAM5' => 'LGW_20071112_E1_CAM5.mpeg',
    },
    $expected_data[1] =>
    { 
      'LGW_20071123_E1_CAM1' => 'LGW_20071123_E1_CAM1.mpeg',
      'LGW_20071123_E1_CAM2' => 'LGW_20071123_E1_CAM2.mpeg',
      'LGW_20071123_E1_CAM3' => 'LGW_20071123_E1_CAM3.mpeg',
      'LGW_20071123_E1_CAM4' => 'LGW_20071123_E1_CAM4.mpeg',
      'LGW_20071123_E1_CAM5' => 'LGW_20071123_E1_CAM5.mpeg',
      'LGW_20071130_E1_CAM1' => 'LGW_20071130_E1_CAM1.mpeg',
      'LGW_20071130_E1_CAM2' => 'LGW_20071130_E1_CAM2.mpeg',
      'LGW_20071130_E1_CAM3' => 'LGW_20071130_E1_CAM3.mpeg',
      'LGW_20071130_E1_CAM4' => 'LGW_20071130_E1_CAM4.mpeg',
      'LGW_20071130_E1_CAM5' => 'LGW_20071130_E1_CAM5.mpeg',
      'LGW_20071130_E2_CAM1' => 'LGW_20071130_E2_CAM1.mpeg',
      'LGW_20071130_E2_CAM2' => 'LGW_20071130_E2_CAM2.mpeg',
      'LGW_20071130_E2_CAM3' => 'LGW_20071130_E2_CAM3.mpeg',
      'LGW_20071130_E2_CAM4' => 'LGW_20071130_E2_CAM4.mpeg',
      'LGW_20071130_E2_CAM5' => 'LGW_20071130_E2_CAM5.mpeg',
      'LGW_20071206_E1_CAM1' => 'LGW_20071206_E1_CAM1.mpeg',
      'LGW_20071206_E1_CAM2' => 'LGW_20071206_E1_CAM2.mpeg',
      'LGW_20071206_E1_CAM3' => 'LGW_20071206_E1_CAM3.mpeg',
      'LGW_20071206_E1_CAM4' => 'LGW_20071206_E1_CAM4.mpeg',
      'LGW_20071206_E1_CAM5' => 'LGW_20071206_E1_CAM5.mpeg',
      'LGW_20071207_E1_CAM1' => 'LGW_20071207_E1_CAM1.mpeg',
      'LGW_20071207_E1_CAM2' => 'LGW_20071207_E1_CAM2.mpeg',
      'LGW_20071207_E1_CAM3' => 'LGW_20071207_E1_CAM3.mpeg',
      'LGW_20071207_E1_CAM4' => 'LGW_20071207_E1_CAM4.mpeg',
      'LGW_20071207_E1_CAM5' => 'LGW_20071207_E1_CAM5.mpeg',
    }
    );

  return(%tmp);
}

sub _set_exp_ext_cmd {
  my %tmp = 
    (
     $expected_ext[0] => "tar xfz",
     $expected_ext[1] => "tar xf",
     $expected_ext[2] => "tar xfz",
     $expected_ext[3] => "tar xfj",
     $expected_ext[4] => "unzip",
    );

  return(%tmp);
}

##############################

sub _warn_add {
  $warn_msg .= "[Warning] " . join(" ", @_) ."\n";
}

############################################################ Manual

=pod

=head1 NAME

TV08ED-Submission Checker - TrecVid08 Event Detection Submission Checker

=head1 SYNOPSIS

B<TV08ED-SubmissionChecker> S<[B<--help> | B<--version> | B<--man>]>
  S<[B<--xmllint> I<location>] [B<--TrecVid08xsd> I<location>]>
  S<[B<--ecf> I<ecffile> B<--fps> I<fps>]>
  S<[B<--skip_validation>] [B<--WriteMemDump> I<dir>]>
  S<[B<--dryrun_mode>] [B<--Verbose>]>
  S<[B<--uncompress_dir> I<dir> | B<--work_in_dir> I<dir>]>
  S<last_parameter>

=head1 DESCRIPTION

B<TV08ED-SubmissionChecker> is a I<TrecVid08 Event Detection Sumbission Checker> program designed to confirm that a submission archive follow the guidelines posted in the I<Submission Instructions> (Appendix B) of the I<TRECVid Event Detection Evaluation Plan>.
The software will confirm that an archive's files and directory structure conforms with the I<Submission Instructions>, and will validate the SYS XML files.

In the case of B<--work_in_dir>, S<last_parameter> is the E<lt>SITEE<gt>.
In all other cases, S<last_parameter> is the archive file to process in the E<lt>I<SITE>E<gt>_E<lt>I<SUB-NUM>E<gt>.I<extension> form (recognized extensions are available using the B<--help> option).

=head1 PREREQUISITES

B<TV08ED-SubmissionChecker> VIPeR files need to pass the B<TV08ViperValidator> validation process. The program relies on the following software and files.
 
=over

=item B<SOFTWARE>

I<xmllint> (part of I<libxml2>) is required (at least version 2.6.30) to perform the syntactic validation of the source file.
If I<xmllint> is not available in your PATH, you can specify its location either on the command line (see B<--xmllint>) or by setting the S<TV08_XMLLINT> environment variable.

The program relies on I<gnu tar> and I<unzip> to process the archive files.

=item B<FILES>

The syntactic validation requires some XML schema files (full list can be obtained using the B<--help> option).
It is possible to specify their location using the B<--xsdpath> option or the B<TV08_XSDPATH> environment variable.
You should not have to specify their location, if you have performed an install and have set the global environment variables.

=item B<GLOBAL ENVIRONMENT VARIABLES>

B<TV08ED-SubmissionChecker> relies on internal and external Perl libraries to function.

Simply running the B<TV08ED-SubmissionChecker> script should provide you with the list of missing libraries.
The following environment variables should be set in order for Perl to use the B<F4DE> libraries:

=over

=item B<F4DE_BASE>

The main variable once you have installed the software, it should be sufficient to run this program.

=item B<F4DE_PERL_LIB>

Allows you to specify a different directory for the B<F4DE> libraries.  This is a development environment variable.

=item B<TV08_PERL_LIB>

Allows you to specify a different directory for the B<TrecVid08> libraries.  This is a development environment variable.

=back

=back

=head1 GENERAL NOTES

B<TV08ED-SubmissionChecker> expects that the system and reference VIPeR files can be been validated using 'xmllint' against the TrecVid08 XSD file(s) (see B<--help> for files list).

B<TV08ED-SubmissionChecker> will ignore the I<config> section of the XML file, as well as discard any xml comment(s).

=head1 OPTIONS

=over

=item B<--dryrun_mode>

Perform all regular task related with checking a submission, except for checking the content of the txt file for the S<Events_Processed:> entry.

=item B<--ecf> I<ecffile>

Specify the I<ECF> to load. The ECF provides the duration of the test set for the error calculations and the list of sourcefile filename expected to be seen in the submission. 

=item B<--fps> I<fps>

Specify the default sample rate (in frames per second) of the Viper files.

=item B<--help>

Display the usage page for this program. Also display some default values and information.

=item B<--man>

Display this man page.

=item B<--skip_validation>

Do not perform XML validation on the VIPeR files within the archive.

=item B<--TrecVid08xsd> I<location>

Specify the default location of the required XSD files (use B<--help> to get the list of required files).
Can also be set using the B<TV08_XSDPATH> environment variable.

=item B<--uncompress_dir> I<dir>

Specify the location of the directory in which to uncompress the archive content (by default a temporary directory is created).

=item B<--Verbose>

Print a verbose log of every task being performed before performing it, and in some case, its results.

=item B<--version>

Display B<TV08ED-SubmissionChecker> version information.

=item B<--WriteMemDump> I<dir>

Write a memory dump of validated XML files into I<dir>.
Useful to avoid having to re-run the entire validation process on the XML file when using another one F4DE's program that accept such files.

=item B<--work_in_dir> I<dir>

Specify the location of the uncompressed files to check.
This step is designed to help confirm that a directory structure is proper before generating the archive.
When using this mode, the S<last_parameter> becomes E<lt>SITEE<gt>.

=item B<--xmllint> I<location>

Specify the full path location of the B<xmllint> command line tool if not available in your PATH.
Can also be set using the B<TV08_XMLLINT> environment variable.

=back

=head1 USAGE

=item B<TV08ED-SubmissionChecker SITE_3.tgz>

Will perform a submission check on archive file I<SITE_3.tgz> in a temporarily created directory.

=item B<TV08ED-SubmissionChecker SITE_3.tgz --uncompress_dir testdir --skip_validation --dryrun>

Will perform a submission check on archive file I<SITE_3.tgz>, uncompressing its content in the I<testdir> directory. This will also not try to validate the XML files, it will simply confirm that the directory structure, and that all the files are present. It will not check the content of the E<lt>EXP-IDE<gt> txt file for the S<Events_Processed:> entry. 

=item B<TV08ED-SubmissionChecker SITE --work_in_dir testdir -ecf ecfile.xml --fps 25>

Will check that the files and directories in I<testdir> are the expected ones. It will check the txt file for the S<Events_Processed:> entry. It will also confirm that the XML files validate against the XML strucutre. It will confirm that the content of the XML files be matched against the ECF file (using a frame per second rate of 25) to permit scoring (the scorer will refuse to process those XML files is one or more of the file listed in the ECF is missing).

=head1 BUGS

Please send bug reports to <nist_f4de@nist.gov>

=head1 AUTHORS

Martial Michel <martial.michel@nist.gov>

=cut

############################################################

sub set_usage {
  my $ok_exts = join(" ", @expected_ext);
  my $xsdfiles = join(" ", @xsdfilesl);
  my $ecf_xsdf = join(" ", @ecf_xsdfilesl);
  my $tmp=<<EOF
$versionid

Usage: $0 [--help | --version | --man] [--xmllint location] [--TrecVid08xsd location] [--ecf ecffile --fps fps] [--skip_validation] [--WriteMemDump dir] [--dryrun_mode] [--Verbose] [--uncompress_dir dir | --work_in_dir dir] last_parameter

Will confirm that a submission file conform to the 'Submission Instructions' (Appendix B) of the 'TRECVid Event Detection Evaluation Plan'.

'last_parameter' is usually the archive file(s) to process (of the form <SITE>_<SUB-NUM>.extension, example: NIST_2.tgz)
Only in the '--work_in_dir' case does it become <SITE>.

 Where:
  --help          Print this usage information and exit
  --man           Print a more detailled manual page and exit (same as running: $mancmd)
  --version       Print version number and exit
  --xmllint       Full location of the \'xmllint\' executable (can be set using the $xmllint_env variable)
  --TrecVid08xsd  Path where the XSD files can be found (can be set using the $xsdpath_env variable)
  --ecf           Specify the ECF file to load
  --fps           Set the number of frames per seconds (float value) (also recognized: PAL, NTSC)
  --skip_validation  Bypass the XML files validation process
  --WriteMemDump  Write a memory dump of each validated XML file into \'dir\'. Note that this option will recreate the <EXP-ID> directory.
  --dryrun_mode   Do not check for content of txt file
  --Verbose       Explain step by step what is being checked
  --uncompress_dir  Specify the directory in which the archive file will be uncompressed
  --work_in_dir   Bypass all steps up to and including uncompression and work with files in the directory specified (useful to confirm a submission before generating its archive)

Note:
- Recognized archive extensions: $ok_exts
- This prerequisite that the XML files can be been validated using 'xmllint' against the 'TrecVid08.xsd' file
- 'TrecVid08xsd' files are: $xsdfiles (and if the 'ecf' option is used, also: $ecf_xsdf)
EOF
    ;

    return $tmp;
}
