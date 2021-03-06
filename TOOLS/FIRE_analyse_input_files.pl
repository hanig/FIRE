#!/usr/bin/perl

use lib "$ENV{FIREDIR}/SCRIPTS";

use Sets;
use Table;
use Fasta;

if ((!$ENV{FIREDIR}) || ($ENV{FIREDIR} eq '')) {
  die "Please set the FIREDIR environment variable.\n";
}


if (@ARGV == 0) {
  die "Args: -fastafile FILE -expfile FILE -species [ optional: -showmissinggenes 0/1 ]\n";
}

my $fastafile        = Sets::get_parameter(\@ARGV, "-fastafile");
my $expfile          = Sets::get_parameter(\@ARGV, "-expfile");
my $showmissinggenes = Sets::get_parameter(\@ARGV, "-showmissinggenes");
my $species          = Sets::get_parameter(\@ARGV, "-species");

if (defined($species)) {
  
  my $species_data = readSpeciesData($species);
  $fastafile = $species_data->{"fastafile_dna"};  

}


# read expression file

my %COUNTS = ();

if (defined($expfile)) {

  print "Checking the expression file\n";

  my %CNT_SYMBOLS = ();
  
  my $ta = Table->new;
  $ta->loadFile($expfile);
  my $a_ref = $ta->getArray();
  
  my $r = shift @$a_ref;


  foreach my $r (@$a_ref) {
    if (@$r > 2) {
      die "Your expression file appears to have more than 2 columns.\n";
    }
    if (@$r < 2) {
      die "Your expression file appears to have less than 2 columns.\n";
    }
    
    if ($r->[1] =~ /[^\d\-\+\.eE]/) {
      die "The expression value for gene $r->[0], '$r->[1]' contains non-numerical characters.\n"; 
    }

    if ($r->[0] =~ /\ +$/) {
      die "Gene name '$r->[0]' contains trailing spaces, please remove them.\n";
    }

    $CNT_SYMBOLS{ $r->[1] } ++;

    $COUNTS{$r->[0]} ++;
  }

  my $has_dup = 0;
  foreach my $v (values(%COUNTS)) {
    if ($v > 1) {
      $has_dup = 1;
    }
  }
  
  if ($has_dup == 1) {
    print "The following genes have been found more than once in the expression file:\n";
    foreach my $k (keys(%COUNTS)) {
      if ($COUNTS{$k} > 1) {
	print "$k\t$COUNTS{$k}\n";
      }
    }
    exit;
  }

  my $numsymbols = scalar(keys(%CNT_SYMBOLS));

  if ($numsymbols <= 1) {
    die "You need to have at least two groups in your expression file. For example, genes in group 1 could be your genes of interest, while genes in group 0 would be all other genes in your genome or on your microarray.\n";
  }
  
  print "Expression file is OK.\n\n";
}


my %COUNTS_FA = ();

if (defined($fastafile)) {

  print "Checking the fasta file\n";
  sleep(1);

  my $fa = Fasta->new;
  $fa->setFile($fastafile);
  
  my $minlen = 10000000;
  my $minseq = undef;
  my $maxlen = -1;
  my $maxseq = undef;

  my $hav_seq = 0;
  while (my $a_ref = $fa->nextSeq()) {
    my ($n, $s) = @$a_ref;

    my $l = length($s);
    if ($l > $maxlen) {
      $maxlen = $l;
      $maxseq = $n;
    }
    if ($l < $minlen) {
      $minlen = $l;
      $minseq = $s;
    }

    if ($n =~ /[\ \t]+$/) {
      die "Gene name '$n' contains trailing spaces or tabs, please remove them.\n";
    }

      
    $COUNTS_FA{$n} ++;

    

    if (defined($COUNTS{$n})) {
      $hav_seq ++;
    }
    
  }
  
  my $tot_seq = scalar(keys(%COUNTS));

  
  my $has_dup = 0;
  foreach my $v (values(%COUNTS_FA)) {
    if ($v > 1) {
      $has_dup = 1;
    }
  }
  
  if ($has_dup == 1) {
    print "The following genes have been found more than once in the expression file:\n";
    sleep(1);
    foreach my $k (keys(%COUNTS_FA)) {
      if ($COUNTS_FA{$k} > 1) {
	print "$k\t$COUNTS_FA{$k}\n";
      }
    }
    exit;
  }
  
  if ($minlen <= 5) {
    die "There is at least one sequence with length <= 5nt ($minseq). These sequences might make FIRE crash, please remove them.\n";
  }

  if ($maxlen >= 10000) {
    die "There is at least one sequence with length >= 10000bp ($maxseq). These sequences might make FIRE crash, please remove them.\n";
  }

  print "Fasta file is OK (min sequence length = $minlen, max length = $maxlen).\n\n";

  print "Found fasta sequence for $hav_seq / $tot_seq identifiers in expression file.\n";
  
}



sub readSpeciesData {
  my ($species) = @_;
  
  my %H = ();
  open IN, "$ENV{FIREDIR}/FIRE_DATA/SPECIES_DATA/$species" or die "No data file for $species.\n";
  while (my $l = <IN>) {
    chomp $l;
    my @a = split /\t/, $l, -1;    
    if ($a[1] =~ /^FIRE_DATA/) {
      $a[1] = "$ENV{FIREDIR}/$a[1]";
    }	
    $H{$a[0]} = $a[1];    
  }  
  close IN;
  
  return \%H;
}



