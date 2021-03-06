package GroupEnrichment;

use lib qw(/netapp/home/hani/FIRE/SCRIPTS/../modules/lib/perl5/site_perl/5.10.0/darwin-thread-multi-2level/netapp/home/hani/FIRE/SCRIPTS/../modules/lib/perl5/site_perl/5.12.4/darwin-thread-multi-2level/Hypergeom.pm
/netapp/home/hani/FIRE/SCRIPTS/../modules/lib64/perl5/Hypergeom.pm
);


use Sets;
use strict;

sub new {
    my ($class) = @_;

    my ($self) = {};
    
    my %h1 = ();  $self->{GROUPS}        = \%h1;
    my %h2 = ();  $self->{DESC}          = \%h2;
    my %h3 = ();  $self->{ANNOTATED}     = \%h3;
    my %h4 = ();  $self->{ANNOTATION}    = \%h4;
    $self->{USEMODULE}     = 1;

    if ($self->{USEMODULE} == 1) {
      require Hypergeom;
    }	

    $self->{GENE_UNIVERSE} = undef;
    $self->{VERBOSE}   = 0;
    
    bless $self;
    
    return $self;

}

sub setUseModule {
  my ($self, $n) = @_;
  $self->{USEMODULE} = $n;
}

#
#  return annotation
#
sub getAnnotation {
    my ($self, $g) = @_;
    if (defined($self->{ANNOTATION}->{$g})) {
	return $self->{ANNOTATION}->{$g};
    } else {
	return -1;
    }
}


sub setMaxGroupSize {
    my ($self, $g) = @_;
    $self->{MAXGROUPSIZE} = $g;
}


sub setMinGroupSize {
    my ($self, $g) = @_;
    $self->{MINGROUPSIZE} = $g;
}


sub setBonferroni {
    my ($self, $g) = @_;
    $self->{BONFERRONI} = $g;
}

sub setGeneUniverse {
  my ($self, $a_ref_universe) = @_;
  
  my %h5 = ();
  $self->{GENE_UNIVERSE} = \%h5;
  foreach my $r (@$a_ref_universe) {
    $self->{GENE_UNIVERSE}->{$r} = 1;
  }

}


#
# set groups (categories) from index file
#
sub setGroups {
  my ($self, $g) = @_;
  
  my %H = ();
  open IN, $g or die "no such file $g\n";
  while (my $l = <IN>) {
    chomp $l;
    my @a = split /\t/, $l;
    
    my $n = shift @a;  # gene name

    if (defined($self->{GENE_UNIVERSE}) && !defined($self->{GENE_UNIVERSE}->{$n})) {
      next;
    }
    
    $self->{ANNOTATED}->{$n} = 1;
    
    
    foreach my $r (@a) {
      if (!defined($H{$r}{$n})) {
	push @{ $self->{GROUPS}->{$r} }, $n; 
	$H{$r}{$n} = 1;
      }
    }
    
    $self->{ANNOTATION}->{$n} = \@a;
    
  }
  close IN;
  
}

sub setGroupDesc {
    my ($self, $g) = @_;
    
    open IN, $g or die "no such file $g\n";
    while (my $l = <IN>) {
	chomp $l;
	my @a = split /\t/, $l;
	$self->{DESC}->{$a[0]} = $a[1]; 
    }
    close IN;
}


sub filterSet {
    my ($self, $a_ref) = @_;
    
    my @new = ();
    foreach my $r (@$a_ref) {
	if ($self->{ANNOTATED}->{ $r }) {
	    push @new, $r;
	}
    }

    return \@new;

}


sub getGroupEnrichment {

  my ($self, $a_ref, $totalnbgenes, $pv) = @_;
  
  if ($totalnbgenes == -1) {
    $a_ref = $self->filterSet($a_ref);
    $totalnbgenes = scalar( keys (%{ $self->{ANNOTATED} }));
  }

  my @ids = keys(%{$self->{GROUPS}});
  
  if ($self->{VERBOSE} == 1) {
    print "Found " . scalar(@ids) . " groups\n";
  }


  my @a_res = ();
  
  #
  # determine the number of categories (note: must be done in advance for Bonferroni correction)
  #
  my $cnt = 0;
  foreach my $f (@ids) {
    my $a_ref_set = $self->{GROUPS}->{$f};
    my $s1        = scalar(@$a_ref_set);
    next if (defined($self->{MINGROUPSIZE}) && ($s1 < $self->{MINGROUPSIZE}));
    next if (defined($self->{MAXGROUPSIZE}) && ($s1 > $self->{MAXGROUPSIZE}));
    $cnt ++;     
  }
    
  foreach my $f (@ids) {
    my $a_ref_set = $self->{GROUPS}->{$f};
    my $s1        = scalar(@$a_ref_set);
    next if (defined($self->{MINGROUPSIZE}) && ($s1 < $self->{MINGROUPSIZE}));
    next if (defined($self->{MAXGROUPSIZE}) && ($s1 > $self->{MAXGROUPSIZE}));
    
    my $a_ovl     = Sets::getOverlapSet($a_ref_set, $a_ref);
    my $s2        = scalar(@$a_ref);
    my $ov        = scalar(@$a_ovl);
    my $p         = undef;
    if ($self->{USEMODULE} == 1) { 
      $p         = Hypergeom::cumhyper($ov, $s1, $s2, $totalnbgenes);
    } else {
      my $oo = `$ENV{FIREDIR}/PROGRAMS/myhypergeom -i $ov -s1 $s1 -s2 $s2 -N $totalnbgenes`;
      ($p) = $oo =~ /p\=(.+?)\,/;
    }
    

    if ($p*$cnt < $pv) {
      my @a_tmp = ($p, $ov, $s1, $s2, $totalnbgenes, $f, $self->{DESC}->{$f});
      push @a_res, \@a_tmp;
    } 
  }
  
  my @a_res_sorted = sort { $a->[0] <=> $b->[0] } @a_res;
  
  if ($self->{BONFERRONI} == 1) {
    foreach my $r (@a_res_sorted) {
      $r->[0] = Sets::min($r->[0]*$cnt, 1.0);
    }
  }
  
  return \@a_res_sorted;

}

sub setVerbose {
    my ($self, $n) = @_;
    
    $self->{VERBOSE} = $n;
}


sub getGroupIds {
  my ($self) = @_;
  my @ids = keys(%{$self->{GROUPS}});
  
  return \@ids;
}


sub getGeneAnnotation {
  my ($self, $f) = @_;
  
  if (!defined($self->{MINGROUPSIZE}) && !defined($self->{MAXGROUPSIZE})) {
    return $self->{ANNOTATION}->{$f}; 
  } else {
    
    my @out = ();
    foreach my $g (@{ $self->{ANNOTATION}->{$f} }) {
      
      if ( defined($self->{MINGROUPSIZE}) && (scalar(@{$self->{GROUPS}->{$g}}) < $self->{MINGROUPSIZE}) ) {
	next;
      } 
      
      if ( defined($self->{MAXGROUPSIZE}) && (scalar(@{$self->{GROUPS}->{$g}}) > $self->{MAXGROUPSIZE}) ) {
	next;
      } 
      
      push @out, $g;
      
    }
    return \@out;
    
  }
}


sub getGeneGroup {
  my ($self, $f) = @_;

  return $self->{GROUPS}->{$f};
  
}

sub getDesc {
   my ($self, $f) = @_;
   return $self->{DESC}->{$f};
}
1;
