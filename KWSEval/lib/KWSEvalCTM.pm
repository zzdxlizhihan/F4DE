package KWSEvalCTM;
# -*- mode: Perl; tab-width: 2; indent-tabs-mode: nil -*- # For Emacs
#
# $Id$
#
# CTM
# KWSEvalCTM.pm
#
# Author:  Martial Michel
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
#
# $Id$

use strict;

use MMisc;
use MErrorH;


sub new {
  my $class = shift;
  my $ctmfile = shift;
  my $bypassCoreText = MMisc::iuv($_[0], 0); 

  my $errorh = new MErrorH('KWSEvalCTM');
  my $errorv = $errorh->error();

  my $self =
    {
     FILE       => $ctmfile,
     content    => undef,
     CoreText   => "", # for a quick rewrite (if not bypassed)
     bypassCoreText   => $bypassCoreText,
     LoadedFile => 0, # to avoid overwriting
     errorh     => $errorh,
     errorv     => $errorv, # cache information
    };

  bless $self;
  $self->loadFile($ctmfile) if (defined($ctmfile));

  return($self);
}

#####

sub loadSSVFile {
  my ($self, $file) = @_;

  return($self->_set_error_and_return_scalar("Refusing to load a file on top of an already existing object", 0))
    if ($self->{LoadedFile} != 0);

  my $err = MMisc::check_file_r($file);
  return($self->_set_error_and_return_scalar("Problem with input file ($file): $err", 0))
    if (! MMisc::is_blank($err));

  open(FILE, $file) 
    or return($self->_set_error_and_return_scalar("Unable to open for read file '$file' : $!", 0));

  my $linec = 0;
  my $core_text = "";
  my ($alt_mode, $alt_min_beg, $alt_max_end, $alt_last_et) = (undef, undef, undef, undef);
  while (my $line = <FILE>) {
    $linec++;
    chomp($line);
    $core_text .= "$line\n"
      if ($self->{bypassCoreText} == 0);

    $line =~ s%\;\;.*$%%;
    next if (MMisc::is_blank($line));
    
    $line =~ s%^\s+%%;
    $line =~ s%\s+$%%;

    my @rest = split(m/\s+/, $line); 
    return($self->_set_error_and_return_scalar("Problem with Line (#$linec): needed at least 5 arguments, found " . scalar @rest . " [$line]", 0)) 
        if (scalar @rest < 5);
    my ($file, $chan, $bt, $dur, $text, $conf) = @rest;

    # <ALT_BEG>
    if (uc($text) eq "<ALT_BEG>") {
      return($self->_set_error_and_return_scalar("Problem with Line (#$linec): Starting a new <ALT_BEG> when a previous one was never close (started on line $alt_mode) [$line]", 0))
        if (defined $alt_mode);
      $alt_mode = $linec;
      $alt_min_beg = undef;
      $alt_max_end = undef;
      $alt_last_et = undef;
      next;
    }
    # <ALT>
    if (uc($text) eq "<ALT>") {
      $alt_last_et = undef;
      next;
    }

    return($self->_set_error_and_return_scalar("Problem with Line (#$linec): begtime [$bt] not a positive number ? [$line]", 0))
      if ((! MMisc::is_float($bt)) || ($bt < 0));

    return($self->_set_error_and_return_scalar("Problem with Line (#$linec): duration [$dur] not a positive number ? [$line]", 0))
      if ((! MMisc::is_float($dur)) || ($dur < 0));

    my $et = $bt + $dur;

    return($self->_set_error_and_return_scalar("Problem with Line (#$linec): confidence [$conf] not a positive number ? [$line]", 0))
      if ((! MMisc::is_float($conf)) || ($conf < 0));

    # <ALT_END>
    if (uc($text) eq "<ALT_END>") {
      $bt = $alt_min_beg;
      $et = $alt_max_end;
      $alt_mode = undef;
    }

    # within an <ALT ...>
    if (defined $alt_mode) {
      return($self->_set_error_and_return_scalar("Problem with Line (#$linec): starting time of <ALT...> entry is after the end of the previous line (prev. end: $alt_last_et / curr. bt: $bt) [$line]", 0))
        if ((defined $alt_last_et) && ($bt > $alt_last_et));
      $alt_min_beg = $bt if ((! defined $alt_min_beg) || ($bt < $alt_min_beg));
      $alt_max_end = $et if ((! defined $alt_max_end) || ($et > $alt_max_end));
      $alt_last_et = $et;
    }

    push @{$self->{content}{$file}{$chan}}, $bt, $et;

#    print "[" . join("] [", @rest) . "]\n";

  }
  close FILE;

  return($self->_set_error_and_return_scalar("Problem with Line (#$linec): Started a new <ALT_BEG> which was not closed at file end (started on line $alt_mode)", 0))
    if (defined $alt_mode);
  
  $self->{CoreText} = $core_text;

  $self->{FILE} = $file;
  $self->{LoadedFile} = 1;

  return(1);
}

#####

sub saveFile {
  my ($self, $fn) = @_;

  MMisc::error_quit("Can not write file ($fn), since file was loaded with the \'bypassCoreText\' option on")
      if ($self->{bypassCoreText} != 0);
  
  my $to = MMisc::is_blank($fn) ? $self->{FILE} : $fn;
  # Re-adapt the file name to remove all ".memdump" (if any)
  $to = &_rm_mds($to);

  my $txt = $self->{CoreText};
  return(MMisc::writeTo($to, "", 1, 0, $txt,  undef, undef, undef, undef, undef, undef));
}

########## 'save' / 'load' Memmory Dump functions

my $MemDump_Suffix = ".memdump";

sub get_MemDump_Suffix { return $MemDump_Suffix; }

my $MemDump_FileHeader_cmp = "\#  KWSEval CTM MemDump";
my $MemDump_FileHeader_gz_cmp = $MemDump_FileHeader_cmp . " (Gzip)";
my $MemDump_FileHeader_add = "\n\n";

my $MemDump_FileHeader = $MemDump_FileHeader_cmp . $MemDump_FileHeader_add;
my $MemDump_FileHeader_gz = $MemDump_FileHeader_gz_cmp . $MemDump_FileHeader_add;

#####

sub _rm_mds {
  my ($fname) = @_;

  return($fname) if (MMisc::is_blank($fname));

  # Remove them all
  while ($fname =~ s%$MemDump_Suffix$%%) {1;}

  return($fname);
}

#####

sub save_MemDump {
  my ($self, $fname, $mode, $printw) = @_;

  $printw = MMisc::iuv($printw, 1);

  # Re-adapt the file name to remove all ".memdump" (added later in this step)
  $fname = &_rm_mds($fname);

  my $tmp = MMisc::dump_memory_object
    ($fname, $MemDump_Suffix, $self,
     $MemDump_FileHeader,
     ($mode eq "gzip") ? $MemDump_FileHeader_gz : undef,
     $printw, 'yaml');

  return("Problem during actual dump process", $fname)
    if ($tmp != 1);

  return("", $fname);
}

##########

sub _md_clone_value {
  my ($self, $other, $attr) = @_;

  MMisc::error_quit("Attribute ($attr) not defined in MemDump object")
      if (! exists $other->{$attr});
  $self->{$attr} = $other->{$attr};
}

#####

sub load_MemDump_File {
  my ($self, $file) = @_;

  return($self->_set_error_and_return_scalar("Refusing to load a file on top of an already existing object", 0))
    if ($self->{LoadedFile} != 0);

  my $err = MMisc::check_file_r($file);
  return($self->_set_error_and_return_scalar("Problem with input file ($file): $err", 0))
    if (! MMisc::is_blank($err));

  my $object = MMisc::load_memory_object($file, $MemDump_FileHeader_gz);

  $self->_md_clone_value($object, 'FILE');
  $self->_md_clone_value($object, 'content');
  $self->_md_clone_value($object, 'CoreText');
  $self->_md_clone_value($object, 'bypassCoreText');

  $self->{LoadedFile} = 1;

  return(1);
}

#####

sub loadFile {
  my ($self, $ctmFile, $bypassCoreText) = @_;

  return($self->_set_error_and_return_scalar("Refusing to load a file on top of an already existing object", 0))
    if ($self->{LoadedFile} != 0);
  
  my $err = MMisc::check_file_r($ctmFile);
  return($self->_set_error_and_return_scalar("Problem with input file ($ctmFile): $err", 0))
    if (! MMisc::is_blank($err));

  open FILE, "<$ctmFile"
    or return($self->_set_error_and_return_scalar("Problem opening file ($ctmFile) : $!", 0));

  my $header = <FILE>;
  close FILE;
  chomp $header;

  return($self->load_MemDump_File($ctmFile))
    if ( ($header eq $MemDump_FileHeader_cmp)
         || ($header eq $MemDump_FileHeader_gz_cmp) );

  return($self->loadSSVFile($ctmFile));
}

############################################################

sub get_fulllist {
  return($_[0]->_set_error_and_return_array("Can not provide a full list for a file non loaded file", undef))
    if ($_[0]->{LoadedFile} == 0);
  
  my @out = ();
  foreach my $file (sort keys %{$_[0]->{content}}) {
    foreach my $channel (sort keys %{$_[0]->{content}{$file}}) {
      my @t = @{$_[0]->{content}{$file}{$channel}};
      push @out, [$file, $channel, @t];
    }
  }

  return(@out);
}

############################################################

sub _set_errormsg {
  $_[0]->{errorh}->set_errormsg($_[1]);
  $_[0]->{errorv} = $_[0]->{errorh}->error();
}

##########

sub get_errormsg { return($_[0]->{errorh}->errormsg()); }

##########

sub error { return($_[0]->{errorv}); }

##########

sub clear_error {
  $_[0]->{errorv} = 0;
  return($_[0]->{errorh}->clear());
}

##########

sub _set_error_and_return_array {
  my $self = shift @_;
  my $errormsg = shift @_;
  $self->_set_errormsg($errormsg);
  return(@_);
}

#####

sub _set_error_and_return_scalar {
  $_[0]->_set_errormsg($_[1]);
  return($_[2]);
}

############################################################

1;
