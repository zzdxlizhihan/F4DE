#!/bin/sh
#! -*-perl-*-
eval 'exec env PERL_PERTURB_KEYS=0 PERL_HASH_SEED=0 perl -x -S $0 ${1+"$@"}'
    if 0;

# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#
# KWSEval
# 
# Original Authors: Jerome Ajot, Jon Fiscus
# Additions: Martial Michel, David Joy

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

### Die on any warning and give a stack trace
use Carp qw(cluck);
### Die on warning
$SIG{__WARN__} = sub { cluck "Warning:\n", @_, "\n";  die; };
### On die, make a stack trace
$SIG{__DIE__} = \&Carp::confess;

# Test: perl KWSEval.pl -e ../test_suite/test2.ecf.xml -r ../test_suite/test2.rttm -s ../test_suite/test2.stdlist.xml -t ../test_suite/test2.kwlist.xml -o -A

use strict;
use Encode;
use if $^V lt 5.18.0, "encoding", 'euc-cn';
use if $^V ge 5.18.0, "Encode::CN";
use if $^V lt 5.18.0, "encoding", 'utf8';
use if $^V ge 5.18.0, "utf8";

# Note: Designed for UNIX style environments (ie use cygwin under Windows).

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

#foreach my $f4dedir (@f4bv) { print $f4dedir . "\n"; }

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
foreach my $pn ("MMisc", "RTTMList", "KWSecf", "TermList", "KWSList", "KWSTools", "KWSMappedRecord", 'BipartiteMatch',
                "KWSAlignment", "KWSSegAlign", "DETCurveSet", "DETCurve", "MetricTWV", "TrialsTWV") {
  unless (eval "use $pn; 1") {
    my $pe = &eo2pe($@);
    &_warn_add("\"$pn\" is not available in your Perl installation. ", $partofthistool, $pe);
    $have_everything = 0;
  }
}
my $versionkey = MMisc::slurp_file(dirname(abs_path($0)) . "/../../../.f4de_version");
my $versionid = "KWSEval ($versionkey)";

# usualy part of the Perl Core
foreach my $pn ("Getopt::Long", "Data::Dumper") {
  unless (eval "use $pn; 1") {
    &_warn_add("\"$pn\" is not available on your Perl installation. ", "Please look it up on CPAN [http://search.cpan.org/]\n");
    $have_everything = 0;
  }
}

# something missing ? Abort
if (! $have_everything) {
  MMisc::error_quit("\n$warn_msg\nERROR: Some Perl Modules are missing, aborting\n");
}

Getopt::Long::Configure(qw( auto_abbrev no_ignore_case ));

my $usage = &set_usage();
MMisc::ok_quit($usage) if (scalar @ARGV == 0);

####################

my $ECFfile = "";
my $RTTMfile = "";
my $STDfile = "";
my $TERMfile = "";

my $thresholdFind = 0.5;
my $thresholdAlign = 0.5;
#my $epsilonTime = 1e-8; #this weights time congruence in the joint mapping table
#my $epsilonScore = 1e-6; #this weights score congruence in the joint mapping table

my $KoefV = 1;
my $KoefC = sprintf("%.4f", $KoefV/10);

my $trialsPerSec = 1;
my $probOfTerm = 0.0001;

my @isoPMISS = (0.0001, 0.001, 0.004, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 40, 60, 80, 90, 95, 98);
my @isoPFA = (0.0001);

my $displayall = 0;

my $segmentbased = 0;
my $requestSumReport = 0;
my $requestBlockSumReport = 0;
my $requestCondSumReport = 0;
my $requestCondBlockSumReport = 0;
my $requestDETCurve = 0;
my $requestDETConditionalCurve = 0;
my $PooledTermDETs = 0;
my $cleanDETsFolder = 0;
my $requestalignCSV = 0;
my $includeNoTargBlocks = 0;
my $justSystemTerms = 0;
my $SerializeSeparateIsoRatioFile = 0;

my $reportOutTypes = [ "TXT" ];

my $haveReports = 0;

sub checksumSystemV
{
    my($filename) = @_;
    my $stringf = "";
    
    open(FILE, $filename) 
      or MMisc::error_quit("cannot open file '$filename' for checksum");
    
    while (<FILE>)
    {
        chomp;
        $stringf .= $_;
    }
    
    close(FILE);
    
    #clean unwanted spaces
    $stringf =~ s/\s+/ /g;
    $stringf =~ s/> </></g;
    $stringf =~ s/^\s+//;
    $stringf =~ s/\s+$//;
    
    return(unpack("%32b*", $stringf));
}

my @arrayparseterm;
my $numberFiltersTermArray = 0;
my %filterTermArray;

my @arraycmdline;
my @arrayparsefile;

my @arrayparsetype;
my $numberFiltersTypeArray = 0;
my %filterTypeArray;

my $fileRoot = "";

my $requestwordsoov = 0;
my $IDSystem = "";

my $OptionIsoline = undef;
my @listIsolineCoef = ();

my @Queries;
my $Groupbytarg = 0;

my $charSplitText = 0;
my $charSplitTextNotASCII = 0;
my $charSplitTextDeleteHyphens = 0;

my @textPrefilters = ();

my $articulatedDET = 0;
my $bypassxmllint = 0;
my $xpng = 0;
my $excludeCounts = 0;
my $IncludeRowTotals = 0;

my $measureThreshPlots = "";

my @globalMeasures = ();

# Av  : ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz #
# Used:  BCDEFG I K  NOP  ST   XY abcdefghijk mnopqrst vwxy  #
# Mult:                                   i                z #

GetOptions
  (
   'ecffile=s'                           => \$ECFfile,
   'rttmfile=s'                          => \$RTTMfile,
   'sysfile|stdfile=s'                   => \$STDfile,
   'termfile=s'                          => \$TERMfile,
   'Find-threshold=f'                    => \$thresholdFind,
   'Similarity-threshold=f'              => \$thresholdAlign,
   'file-root=s'                         => \$fileRoot,
   'osummary-report'                     => \$requestSumReport,
   'block-summary-report'                => \$requestBlockSumReport,
   'Osummary-conditional-report'         => \$requestCondSumReport,
   'Block-summary-conditional-report'    => \$requestCondBlockSumReport,
   'Term=s@'                             => \@arrayparseterm,
   'query=s@'                            => \@Queries,
   'Group-by-targ'                       => \$Groupbytarg,
   'Namefile=s@'                         => \@arraycmdline,
   'YSourcetype=s@'                      => \@arrayparsetype,
   "gsegment-based-alignment"            => \$segmentbased,
   'iso-lines:s'                         => \$OptionIsoline,
   'det-curve'                           => \$requestDETCurve,
   'DET-conditional-curve'               => \$requestDETConditionalCurve,
   'Clean-DETs-folder'                   => \$cleanDETsFolder,
   'csv-of-alignment'                    => \$requestalignCSV,
   'ytypes-of-report-output=s@'          => \$reportOutTypes,
   'koefcorrect=f'                       => \$KoefC,
   'Koefincorrect=f'                     => \$KoefV,
   'number-trials-per-sec=f'             => \$trialsPerSec,
   'prob-of-term=f'                      => \$probOfTerm,
   'Pooled-DETs'                         => \$PooledTermDETs,
   'version'                             => sub { MMisc::ok_quit($versionid); },
   'help'                                => sub { MMisc::ok_quit($usage); },
   'words-oov'                           => \$requestwordsoov,
   'include-blocks-w-notargs'            => \$includeNoTargBlocks,
   'just-system-terms'                   => \$justSystemTerms,
   'ID-System=s'                         => \$IDSystem, 
   'xprefilterText=s@'                   => \@textPrefilters,
   'articlulatedDET'                     => \$articulatedDET,
   'XmllintBypass'                       => \$bypassxmllint,
   'ExcludePNGFileFromTxtTable'          => \$xpng,
   'ExcludeCountsFromReports'            => \$excludeCounts,
   'measureThreshPlots=s'                => \$measureThreshPlots,
   'zIsoRatioDAF'                        => \$SerializeSeparateIsoRatioFile,
   'zincludeRowTotals'                   => \$IncludeRowTotals,
   'zGlobalMeasures=s@'                  => \@globalMeasures,
) or MMisc::error_quit("Unknown option(s)\n\n$usage\n");

#parsing TermIDs
$numberFiltersTermArray = @arrayparseterm;
for(my $i=0; $i<$numberFiltersTermArray; $i++) {
    my @tmp = split(/:/, join(':', $arrayparseterm[$i]));
    @{ $filterTermArray{$tmp[0]} } = split(/,/, join(',', $tmp[(@tmp==1)?0:1]));
}

#parsing Filenames and channels
my @tmpfile = split(/,/, join(',', @arraycmdline));
for(my $i=0; $i<@tmpfile; $i++) {
    push(@arrayparsefile, [ split("\/", $tmpfile[$i]) ]);
}

#parsing Sourcetypes
$numberFiltersTypeArray = @arrayparsetype;
for(my $i=0; $i<$numberFiltersTypeArray; $i++) {
    my @tmp = split(/:/, join(':', $arrayparsetype[$i]));
    @{ $filterTypeArray{$tmp[0]} } = split(/,/, join(',', $tmp[(@tmp==1)?0:1]));
}

$requestalignCSV = 1 if($requestalignCSV != 0);

# Isoline Option
my @tmplistiso1 = ();
my @tmplistiso2 = ();

if( ! defined($OptionIsoline)) {
	# Create the default list of coefficients
	foreach my $PFAi ( @isoPFA ) {
		foreach my $PMISSi ( @isoPMISS ) {
			push( @tmplistiso1, $PMISSi/$PFAi );
		}
	}
}
else {
	# Use the list given on the command-line
	foreach my $coefi ( split( /,/ , $OptionIsoline ) ) {
		MMisc::error_quit("The coefficient for the iso-line if not a proper floating-point")
      if( $coefi !~ /^\d+(\.\d+)?$/ );
		push( @tmplistiso1, $coefi );
	}
}

@tmplistiso2 = KWSTools::unique(@tmplistiso1);
@listIsolineCoef = sort {$a <=> $b} @tmplistiso2;

$haveReports = $requestSumReport || $requestBlockSumReport || $requestCondSumReport || $requestCondBlockSumReport || $requestalignCSV || $requestDETConditionalCurve;
MMisc::error_quit("Must include a file root") if ($fileRoot eq "");

if ($fileRoot =~ m:/[^/]+$:) { $fileRoot .= "."; } #if the fileroot has a prepend string add a '.'
###Error breakouts before loading
#check if the options are valid to run
MMisc::error_quit("An RTTM file must be set")
  if (MMisc::is_blank($RTTMfile));
MMisc::error_quit("A KWList file must be set")
  if (MMisc::is_blank($TERMfile));

if($haveReports) {
  MMisc::error_quit("An ECF file must be set")
    if (MMisc::is_blank($ECFfile));
  MMisc::error_quit("An STDList file must be set")
    if (MMisc::is_blank($STDfile));
}

my $groupBySrcType = 0; $groupBySrcType = 1 if (keys %filterTypeArray > 0);
my $groupByTerm = 0; $groupByTerm = 1 if (keys %filterTermArray > 0);
my $groupByAttr = 0; $groupByAttr = 1 if (@Queries > 0);
my $groupByTarg = 0; $groupByTarg = 1 if ($Groupbytarg);
if ($groupBySrcType + $groupByTerm + $groupByAttr + $requestwordsoov + $groupByTarg > 1) {
  MMisc::error_quit("Cannot specify more than one condition (-Y, -q, -T, -G) for the conditional report");
} #Perhaps a more descriptive error

foreach my $filt(@textPrefilters){
  if ($filt =~ /^charsplit$/i){
    $charSplitText = 1;
  } elsif ($filt =~ /^notascii$/i){
    $charSplitTextNotASCII = 1;
  } elsif ($filt =~ /^deletehyphens$/i){
    $charSplitTextDeleteHyphens = 1;
  } else {
    MMisc::error_quit("Error: -zprefilterText option /$filt/ not defined.  Aborting.");
  }
}
print "Warning: -zprefilterText notASCII ignored because -z charsplit not used\n" if (!$charSplitText && $charSplitTextNotASCII);
print "Warning: -zprefilterText deleteHyphens ignored because -z charsplit not used\n" if (!$charSplitText && $charSplitTextDeleteHyphens);

if ($measureThreshPlots ne ""){
  MMisc::error_quit("Error: argument for -measureThreshPlots must be either (true|trueWithSE), not $measureThreshPlots")
    if ($measureThreshPlots !~ /^(true|trueWithSE)$/);
}

foreach my $_gMea(@globalMeasures){
  MMisc::error_quit("Error: Requested global measure /$_gMea/ not (MAP|MAPpct|Optimum|Supremum)")
    if ($_gMea !~ /^(MAP|MAPpct|Optimum|Supremum)$/);
}

###loading the files
my $ECF;
my $STD;

my $err;

$err = MMisc::check_file_r($ECFfile);
MMisc::error_quit("Problem with ECF File ($ECFfile): $err")
  if (! MMisc::is_blank($err));
print "Loading ECF $ECFfile\n";
$ECF = new KWSecf($ECFfile);

$err = MMisc::check_file_r($STDfile);
MMisc::error_quit("Problem with STD File ($STDfile): $err")
  if (! MMisc::is_blank($err));
print "Loading KWSList File $STDfile\n";
$STD = new KWSList();
$STD->openXMLFileAccess($STDfile, 0, $bypassxmllint); #now ready for getNextDetectedKWlist
$STD->SetSystemID($IDSystem) if (! MMisc::is_blank($IDSystem));

$err = MMisc::check_file_r($TERMfile);
MMisc::error_quit("Problem with TERM File ($TERMfile): $err")
  if (! MMisc::is_blank($err));
print "Loading KWList File $TERMfile\n";
my $TERM = new TermList($TERMfile, $charSplitText, $charSplitTextNotASCII, $charSplitTextDeleteHyphens);

$err = MMisc::check_file_r($RTTMfile);
MMisc::error_quit("Problem with RTTM File ($RTTMfile): $err")
  if (! MMisc::is_blank($err));
print "Loading RTTM File $RTTMfile\n";
my $RTTM = new RTTMList($RTTMfile, $TERM->getLanguage(), 
                        $TERM->getCompareNormalize(), $TERM->getEncoding(), $charSplitText, $charSplitTextNotASCII, $charSplitTextDeleteHyphens, 1); # bypassCoreText -> no RTTM text rewrite possible
#print $RTTM->dumper();

# clean the filter for terms
$numberFiltersTermArray = keys %filterTermArray;
####Alignments
my @alignResults;
my ($dset, $qdset);
my @filters = ();
my $groupBySubroutine = undef;
my $alignmentCSV = "";
if ($requestalignCSV == 1) {
  if ($fileRoot ne "-") { $alignmentCSV = $fileRoot . "alignment.csv"; }
  else { $alignmentCSV = "alignment.csv"; }
}
if ($segmentbased != 0)
{
###Segment based Alignment
  print "Performing Segment Alignment\n";
  my $segAlignment = new KWSSegAlign($RTTM, $STD, $ECF, $TERM, \@globalMeasures);
  $segAlignment->setFilterData(\%filterTypeArray, \%filterTermArray, \@arraycmdline, \@Queries);

#Setup segment filters
  push (@filters, \&KWSSegAlign::filterByFileChan) if (@arraycmdline > 0);

  $groupBySubroutine = \&KWSSegAlign::groupByECFSourceType if ($groupBySrcType == 1);
  $groupBySubroutine = \&KWSSegAlign::groupByTerms if ($groupByTerm == 1);
  $groupBySubroutine = \&KWSSegAlign::groupByAttributes if ($groupByAttr == 1);
  $groupBySubroutine = \&KWSSegAlign::groupByOOV if ($requestwordsoov == 1);
  $groupBySubroutine = \&KWSSegAlign::groupByIsTarget if ($groupByTarg == 1);

  #Align
  @alignResults = @{ $segAlignment->alignSegments($alignmentCSV, \@filters, $groupBySubroutine, $thresholdFind, $KoefC, $KoefV, $probOfTerm, \@listIsolineCoef, $PooledTermDETs, $includeNoTargBlocks, $justSystemTerms) };
}
else
{
###Occurence based Alignment
  print "Performing Occurrence Alignment\n";
  my $alignment = new KWSAlignment($RTTM, $STD, $ECF, $TERM, \@globalMeasures);
  $alignment->setFilterData(\%filterTypeArray, \%filterTermArray, \@arraycmdline, \@Queries);

#Setup filters
  push (@filters, \&KWSAlignment::belongsInECF);
  push (@filters, \&KWSAlignment::filterByFileChan) if (@arraycmdline > 0);

  $groupBySubroutine = \&KWSAlignment::groupByECFSourceType if ($groupBySrcType == 1);
  $groupBySubroutine = \&KWSAlignment::groupByTerms if ($groupByTerm == 1);
  $groupBySubroutine = \&KWSAlignment::groupByAttributes if ($groupByAttr == 1);
  $groupBySubroutine = \&KWSAlignment::groupByOOV if ($requestwordsoov == 1);
  $groupBySubroutine = \&KWSAlignment::groupByIsTarget if ($groupByTarg == 1);

  #Align
  @alignResults = @{ $alignment->alignTerms($alignmentCSV, \@filters, $groupBySubroutine, $thresholdFind, $thresholdAlign, $KoefC, $KoefV, \@listIsolineCoef, $trialsPerSec, $probOfTerm, $PooledTermDETs, $includeNoTargBlocks, $justSystemTerms) };
}

print "Computing requested DET curves and reports\n";
#Set dets
my $detoptions = 
{ ("Xmin" => .0001,
   "Xmax" => 40,
   "Ymin" => 5,
   "Ymax" => 98,
   "DETShowPoint_Actual" => 1,
   "DETShowPoint_Best" => 1,
   "DETShowPoint_Ratios" => 1,
   "xScale" => "nd",
   "yScare" => "nd",
   "ColorScheme" => "color",
   "createDETfiles" => 1,
   "DrawIsometriclines" => 1,
   "Isometriclines" => [ (0.3) ],
   "title" => $STD->getSystemID(),
   "serialize" => 1,
   'ExcludePNGFileFromTxtTable' => ($xpng == 1),
   "ExcludeCountsFromReports" => ($excludeCounts == 1),
   "ReportRowTotals" => ($IncludeRowTotals == 1) ? 1 : 0,
  ) };
$detoptions->{"PlotMeasureThresholdPlots"} = $measureThreshPlots if ($measureThreshPlots ne "");
$detoptions->{"SerializeSeparateIsoRatioFile"} = "true" if ($SerializeSeparateIsoRatioFile == 1);

$dset = $alignResults[0];
$qdset = $alignResults[1];

## Set the DET renderStyle
if ($articulatedDET){
  print "Building Articulated DETs\n";
  foreach my $det(@{ $dset->getDETList() }, @{ $qdset->getDETList() }){
    $det->setCurveStyle("Articulated");
  }
}

## Add the global measure visualization
foreach my $globMea(@globalMeasures){
  if ($globMea =~ /^(Optimum|Supremum)$/){
    $detoptions->{"DETShowPoint_" . $globMea} = 1;
    $detoptions->{"Report" . $globMea} = 1;
  } else {
    $detoptions->{"ReportGlobal"} = 1;
  }
}

##Render reports
my $detsPath = "";
if ($fileRoot ne "-") { $detsPath = $fileRoot . "dets/"; }
else { $detsPath = "dets/"; }
if ($requestDETCurve || $requestDETConditionalCurve) {
  if ((not mkdir ($detsPath)) && $cleanDETsFolder == 1) {
    MMisc::error_quit($detsPath ." already exists, cleaning it may lead to unwanted results"); }
}

my $file;
my $binmode = ($RTTM->{ENCODING} ne "") ? $RTTM->getPerlEncodingString() : undef;
my %outTypes = map {  lc($_) => 1  } @$reportOutTypes;

#Render summary reports
if ($requestSumReport) {
  if ($fileRoot eq "-") { $file = "-"; }
  else { $file = $fileRoot . "sum"; }
  
  print "Summary Report: " . $file . "\n";
  
  my $detsPath = "";
  if ($fileRoot ne "-") { $detsPath = $fileRoot . "dets/sum" }
  else { $detsPath = "dets/sum"; }
  $dset->renderReport($detsPath, $requestDETCurve, $detoptions, 
		      ($outTypes{"txt"}) ? ($file eq "-") ? "-" : "$file.txt" : undef,
		      ($outTypes{"csv"}) ? ($file eq "-") ? "-" : "$file.csv" : undef, 
		      ($outTypes{"html"}) ? ($file eq "-") ? "-" : "$file.html" : undef, $binmode);
}
if ($requestBlockSumReport) {
  if ($fileRoot eq "-") { $file = "-"; }
  else { $file = $fileRoot . "bsum"; }
  
  print "Block Summary Report: " . $file . "\n";
  
  $dset->renderBlockedReport($segmentbased,
			     ($outTypes{"txt"}) ? ($file eq "-") ? "-" : "$file.txt" : undef,
			     ($outTypes{"csv"}) ? ($file eq "-") ? "-" : "$file.csv" : undef, 
			     ($outTypes{"html"}) ? ($file eq "-") ? "-" : "$file.html" : undef, $binmode, $detoptions); #shows Corr!Det if segment based
}

#Render conditional summary reports
if ($requestCondSumReport) {
  if (@{ $qdset->getDETList() } > 0){
    if ($fileRoot eq "-") { $file = "-"; }
    else { $file = $fileRoot . "cond.sum"; }
    
    print "Conditional Summary Report: " . $file . "\n";
    my $detsPath = "";
    if ($fileRoot ne "-") { $detsPath = $fileRoot . "dets/cond.sum" }
    else { $detsPath = "dets/cond.sum"; }
    $qdset->renderReport($detsPath, $requestDETConditionalCurve, $detoptions,
                         ($outTypes{"txt"}) ? ($file eq "-") ? "-" : "$file.txt" : undef,
                         ($outTypes{"csv"}) ? ($file eq "-") ? "-" : "$file.csv" : undef, 
                         ($outTypes{"html"}) ? ($file eq "-") ? "-" : "$file.html" : undef, $binmode);
  } else {
    print "  No Conditional Summary Report will be generated.  No conditional DET Curves found\n";
  } 
}
if ($requestCondBlockSumReport) {
  if (@{ $qdset->getDETList() } > 0){
    if ($fileRoot eq "-") { $file = "-"; }
    else { $file = $fileRoot . "cond.bsum"; }
    
    print "Conditional Block Summary Report: " . $file . "\n";
    
    $qdset->renderBlockedReport($segmentbased,
                                ($outTypes{"txt"}) ? ($file eq "-") ? "-" : "$file.txt" : undef,
                                ($outTypes{"csv"}) ? ($file eq "-") ? "-" : "$file.csv" : undef, 
                                ($outTypes{"html"}) ? ($file eq "-") ? "-" : "$file.html" : undef, $binmode); #shows Corr!Det if segment based
  } else {
    print "  No Conditional Summary Report will be generated.  No conditional DET Curves found\n";
  } 
}
###

##Clean DETS folder
if ($cleanDETsFolder) {
  my $dir2clean = $fileRoot . $detsPath;
  opendir (DIR, $dir2clean) or MMisc::error_quit("Cannot locate DETs directory to clean.");
#  print "About to remove ..\n";
  my @files2rm = ();
  while (my $file = readdir(DIR)) {
    next if ($file =~ /^\.{1,2}/ || $file =~ /\.png$/i || $file =~ /\.srl\.gz$/i);
    push (@files2rm, $dir2clean . $file);
#    print $dir2clean . $file . "\n";
  }
  unlink @files2rm;
}
##

MMisc::ok_exit();

############################################################

sub set_usage {
  my $tmp = "";

	$tmp .= "KWSEval.pl -e ecffile -r rttmfile -s kwsfile -t kwfile -f fileroot [ OPTIONS ]\n";
	$tmp .= "\n";
	$tmp .= "Required file arguments:\n";
	$tmp .= "  -e, --ecffile            Path to the ECF file.\n";
	$tmp .= "  -r, --rttmfile           Path to the RTTM file.\n";
	$tmp .= "  -s, --sysfile            Path to the KWSList file.\n";
	$tmp .= "  -t, --termfile           Path to the KWList file.\n";
	$tmp .= "\n";
	$tmp .= "Find options:\n";
	$tmp .= "  -F, --Find-threshold <thresh>\n";
	$tmp .= "                           The <thresh> value represents the maximum time gap in\n";
	$tmp .= "                           seconds between two words in order to consider the two words\n";
	$tmp .= "                           to be part of a term when searching the RTTM file for reference\n";
	$tmp .= "                           term occurrences. (default: 0.5).\n";
	$tmp .= "  -S, --Similarity-threshold <thresh>\n";
	$tmp .= "                           The <thresh> value represents the maximum time distance\n";
	$tmp .= "                           between the temporal extent of the reference term and the\n";
	$tmp .= "                           mid point of system's detected term for the two to be\n";
	$tmp .= "                           considered a pair of potentially aligned terms. (default: 0.5).\n";
	$tmp .= "\n";
	$tmp .= "Filter options:\n";
	$tmp .= "  -T, --Term [<set_name>:]<termid>[,<termid>[, ...]]\n";
	$tmp .= "                           Only the <termid> or the list of <termid> (separated by ',')\n";
	$tmp .= "                           will be displayed in the Conditional Occurrence Report and Con-\n";
	$tmp .= "                           ditional DET Curve. An name can be given to the set by specify-\n";
	$tmp .= "                           ing <set_name> (<termid> can be a regular expression).\n";
	$tmp .= "  -Y, --YSourcetype [<set_name>:]<type>[,<type>[, ...]]\n";
	$tmp .= "                           Only the <type> or the list of <type> (separated by ',') will\n";
	$tmp .= "                           be displayed in the Conditional Occurrence Report and Condi-\n";
	$tmp .= "                           tional DET Curve. An name can be given to the set by specifying\n";
	$tmp .= "                           <set_name> (<type> can be a regular expression).\n";
  $tmp .= "  -G, --Group-by-targ\n";
	$tmp .= "  -N, --Namefile <file/channel>[,<file/channel>[, ...]]\n";
	$tmp .= "                           Only the <file> and <channel> or the list of <file> and <chan-\n";
	$tmp .= "                           nel> (separated by ',') will be displayed in the Occurrence\n";
	$tmp .= "                           Report and DET Curve (<file> and <channel> can be regular\n";
	$tmp .= "                           expressions).\n";
	$tmp .= "  -q, --query <name_attribute>[:regex=<REGEXP>][ && <name_attribute>[:regex=<REGEXP>]*\n";
	$tmp .= "                           Populate the Conditional Reports with set of terms identified by\n";
	$tmp .= "                           <name_attribute> in the the term list's 'terminfo' tags.  Optionally,\n";
	$tmp .= "                           the valuses of the attribute can be selected using the regular expression\n";
	$tmp .= "                           <REGEXP>.  Multiple attributes specified with the '&&' operator which will\n";
  $tmp .= "                           create the joint set of all occurring attributed\n";
	$tmp .= "  -w, --words-oov          Generate a Conditional Report sorted by terms that are \n";
	$tmp .= "                           Out-Of-Vocabulary (OOV) for the system.\n";
	$tmp .= "\n";
  $tmp .= "Alignment options:\n";
  $tmp .= "  -g, --gsegment-based-alignment\n";
  $tmp .= "                           Produces a segment alignment rather than occurence based alignment\n";
  $tmp .= "                           (default: off)\n";
	$tmp .= "Report options:\n";
  $tmp .= "  -path <path>             Output directory for generated reports.\n";
  $tmp .= "  -f  --file-root          File root for the generated reports.\n";
	$tmp .= "  -o, --osummary-report                    Output the Summary Report.\n";
  $tmp .= "  -b, --block-summary-report               Output the Block Summary Report.\n";
	$tmp .= "  -O, --Osummary-conditional-report        Output the Conditional Occurrence Report.\n";
  $tmp .= "  -B, --Block-summary-conditional-report   Output the Conditional Block Summary Report.\n";
	$tmp .= "  -i, --iso-lines [<coef>[,<coef>[, ...]]]\n";
	$tmp .= "                            Include the iso line information inside the serialized det curve.\n";
	$tmp .= "                            Every <coef> can be specified, or it uses those by default.\n";
	$tmp .= "                            The <coef> is the ratio Pmiss/Pfa.\n";
	$tmp .= "  -d, --det-curve               Output the DET Curve.\n";
	$tmp .= "  -D, --DET-conditional-curve   Output the Conditional DET Curve.\n";
	$tmp .= "  -P, --Pooled-DETs             Produce term occurrence DET Curves instead of 'Term Weighted' DETs.\n";
  $tmp .= "  -C, --Clean-DETs-folder       Removes all non-png files from the generated dets folder.\n";
  $tmp .= "  -c, --csv-of-alignment        Output the alignment CSV.\n";
  $tmp .= "  -y, --ytype-of-report-output  Output types of the reports. (TXT,CSV,HTML) (Default is Text)\n";
	$tmp .= "  -k, --koefcorrect <value>     Value for correct (C).\n";
	$tmp .= "  -K, --Koefincorrect <value>   Value for incorrect (V).\n";
	$tmp .= "  -m, --measureThreshPlots (true|trueWithSE)  Generate detection score threshold plots for the error measures\n";
	$tmp .= "  -n, --number-trials-per-sec <value>  The number of trials per second. (default: 1)\n";
	$tmp .= "  -p, --prob-of-term <value>    The probability of a term. (default: 0.0001)\n";
  $tmp .= "  -inc, --include-blocks-w-notargs  Include blocks with no targets in block reports.\n";
	$tmp .= "  -I, --ID-System <name>        Overwrites the name of the STD system.\n";
  $tmp .= "  -j, --just-system-terms       Ignores terms which are not present in the system output.\n";
	$tmp .= "      --zprefilterText <opts>   Prefilter the KWList and  RTTM with the options.  May be used more than once.\n";
	$tmp .= "                                  charSplit -> split multi-character tokens into characters\n";
  $tmp .= "                                  notASCII  -> do not split ASCII words.  (no effect without charSplit)\n";
  $tmp .= "                                  deleteHyphens -> treat hyphens like required whitespace. (no effect without charSplit)\n";
  $tmp .= "      --zIsoRatioDAF            Write the Iso Ratio status into a separate DAF file and not in the SRL\n";
  $tmp .= "      --zGlobalMeasures <name>  Include additional performance measures.  <name> can be MAP, AP, Optimum, Supremum.\n";
	$tmp .= "                                The option cane be used multiple times.\n";
	$tmp .= "\n";
	$tmp .= "Other options:\n";
	$tmp .= "  -a, --articulatedDET          Compute the faster articulated DET curves.\n";
  $tmp .= "  -X, --XmllintBypass           Bypass xmllint check of the KWSList XML file (this will reduce the memory footprint when loading the file, but requires that the file be formatted in a way similar to how \'xmllint --format\' would).\n"; 
  $tmp .= "  --ExcludePNGFileFromTxtTable  Exclude PNG files loaction from output text tables\n";
  $tmp .= "  --ExcludeCountsFromReports    Exclude trial counts from report tables\n";
  $tmp .= "  --zincludeRowTotals           Include column count/mean/SE in the report tables\n";
  
	$tmp .= "\n";

  return($tmp);
}
