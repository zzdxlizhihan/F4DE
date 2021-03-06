package CLEARMetrics;
#
# $Id$
#
# CLEARMetrics
#
# Author(s): Martial Michel
#
# This software was developed at the National Institute of Standards and Technology by
# employees and/or contractors of the Federal Government in the course of their official duties.
# Pursuant to Title 17 Section 105 of the United States Code this software is not subject to 
# copyright protection within the United States and is in the public domain.
#
# "CLEARMetrics.pm" is an experimental system.
# NIST assumes no responsibility whatsoever for its use by any party, and makes no guarantees,
# expressed or implied, about its quality, reliability, or any other characteristic.
#
# We would appreciate acknowledgement if the software is used.  This software can be
# redistributed and/or modified freely provided that any derivative works bear some notice
# that they are derived from it, and any modified versions bear some notice that they
# have been modified.
#
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESSED
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;

########################################

sub computeMOTA {
  my ($costMD, $sumMD, $costFA, $sumFA, $costIS, $sumIDsplit, $sumIDmerge, $cng) = @_;

  return(undef) if ($cng == 0);
  
  return(1 - ( $costMD*$sumMD + $costFA*$sumFA + $costIS*($sumIDsplit + $sumIDmerge)) / $cng);
}

##########

sub _get_printable_value {
  my $v = $_[0];

  return("NaN") if (! defined $v);
  
  return(sprintf("%.06f", $v));
}

#####

sub computePrintableMOTA {
  my $v = &computeMOTA(@_);
  
  return(&_get_printable_value($v));
}

##########

sub __check_sameMOTAcomp {
  my ($col1, $col2, $name, @array) = @_;

  my $v1 = $array[$col1];
  my $v2 = $array[$col2];
  
  return("Different $name [$v1 / $v2]")
    if ($v1 != $v2);

  return("");
}

#####

sub sumMOTAcomp {
  my @all = @_;

  # Special case, adding to an empty, return the input as the result
  return("", @all[0..7]) if (scalar @all == 8);

  return("Strange number of elements (expected 16, got " . scalar @all . ")")
    if (scalar @all != 16);
  
  for (my $i = 0; $i < scalar @all; $i++) {
    my $v = $all[$i];
    return("Not all values given are integer value [$v]")
      if (! MMisc::is_integer($v));
  }

  my $err = "";
  $err .= &__check_sameMOTAcomp(0, 8, "CostMD", @all);
  $err .= &__check_sameMOTAcomp(2, 10, "CostFA", @all);
  $err .= &__check_sameMOTAcomp(4, 12, "CostIS", @all);
  return($err) if (! MMisc::is_blank($err));

  my @out = ();
  # Sum all
  for (my $i = 0; $i < 8; $i++) {
    $out[$i] = $all[$i] + $all[8 + $i];
  }
  # but 3 special cases
  $out[0] = $all[0];
  $out[2] = $all[2];
  $out[4] = $all[4];

  return("", @out);
}

##########

sub get_CorrectDetect_fromMOTAcomp {
  my ($d0, $miss, $d2, $d3, $d4, $d5, $d6, $nref) = @_;

  my $cordet = $nref - $miss;

  return($cordet);
}

#####

sub get_Precision_Recall_FrameF1_fromMOTAcomp {
  my ($d0, $miss, $d2, $fa, $d4, $d5, $d6, $nref) = @_;

  my $cordet = &get_CorrectDetect_fromMOTAcomp(@_);

  my $den = $cordet + $fa;
  my $v = ($den == 0) ? undef : ($cordet / $den);
  my $prec = &_get_printable_value($v);

  $den = $cordet + $miss;
  my $v = ($den == 0) ? undef : ($cordet / $den);
  my $rec = &_get_printable_value($v);

  $den = $prec + $rec;
  my $v = 
    ((! MMisc::is_float($prec)) || (! MMisc::is_float($rec)) || ($den == 0)) 
      ? undef : ((2 * $rec * $prec) / ($rec + $prec));
  my $ff1 = &_get_printable_value($v);

  return($prec, $rec, $ff1);
}

#####

sub get_NumSys_fromMOTAcomp {
  my ($d0, $d1, $d2, $fa, $d4, $idsp, $idsw, $d7, $cdet) = @_;

  my $nsys = $cdet + $fa + $idsp + $idsw;

  return($nsys);
}

##########

sub get_MOTE_comp_fromMOTAcomp {
  my ($costMD, $sumMD, $costFA, $sumFA, $costIS, $sumIDsplit, $sumIDmerge, $cng) = @_;
  my $num_md = $costMD * $sumMD;
  my $v = ($cng == 0) ? undef : ($num_md / $cng);
  my $emd = &_get_printable_value($v);

  my $num_fa = $costFA * $sumFA;
  my $v = ($cng == 0) ? undef : ($num_fa / $cng);
  my $efa = &_get_printable_value($v);
 
  my $num_is = $costIS * $sumIDsplit;
  my $v = ($cng == 0) ? undef : ($num_is / $cng);
  my $eis = &_get_printable_value($v);

  my $num_im = $costIS * $sumIDmerge;
  my $v = ($cng == 0) ? undef : ($num_im / $cng);
  my $eim = &_get_printable_value($v);

  my $v = ($cng == 0) ? undef : ( ($num_md + $num_fa + $num_is + $num_im) / $cng );
  my $mote = &_get_printable_value($v);

  return($mote, $emd, $efa, $eis, $eim);
}

########################################

1;
