#!/usr/bin/perl -w

############################################################################
#
# Evaluates F-score for SemEval 2015 Disorder Identification Task. A single 
# execution of the script calculates two scores; 1) strict F-score  
# and 2) relaxed F-score.
#
###########################################################################

# Parameters:
# -input (prediction directory)
# -gold (goldstandard directory)
# -n (specify name of run)
# -r (specify 1, 2, 3 for which run)
# -trace (optional trace 1 (on) or 0 (off) )

# Example usage:
# ./task1_eval.pl l -n team -r 1  -input team_dir -gold gold_dir
# ./task1_eval.pl  -n team -r 2  -input team_dir -gold gold_dir
# ./task1_eval.pl  -n team -r 3  -input team_dir -gold gold_dir

# Example usage with trace one:
# ./task1_eval.pl  -n team -r 1  -input team_dir -gold gold_dir -trace 1

# Output file: $name_task$task_run$run.out
# Example: 	n_task1_run1.out 
#			n_task1_run2.out
#			n_task1_run3.out


use strict;
use warnings;
use Getopt::Long;

my $name = "";
my $task = "task1";
my $run = "";
my $input = "";
my $gold = "";
my $trace = 0;
my $error = "# Parameters:\n# -input (prediction file)\n# -gold (goldstandard file)\n# -n (specify name of run)\n# -r (specify 1 or 2 for which run)\n# -trace (optional: 1 turns trace on, 0 trace off - by default trace is off)\n";

GetOptions (
      'n=s'=>\$name,
      'r=n'=>\$run,
      'trace:i'=>\$trace,
      'input=s'=>\$input,
      'gold=s'=>\$gold    
    )||die "$error";

if (($name eq "")||($input eq "")||($gold eq "")) {
    die "$error";}
if (($run != 1)&&($run != 2)&&($run != 3)) {
    die "Incorrect run id\n";}

 

if ($trace) {
	my $tracefile = $name . "_" . $task . "_run" . "$run.trace";
	# My debug trace - remove this ?
	open( TRACEOUT, ">$tracefile" );
}

#####################################################
# Define Important globals
#####################################################

# open output file
my $outputfile = $name . "_" . $task . "_run" . "$run.out";


open(OUT,">$outputfile")||die;

# gs_disorders and pred_disorders hold disorder_id's organized by document.
# for the gold standar and predictions respectivly.
# The data structure is multi-level hash.
# Top level key: is a document name, value: is a hash of disorder_id.
# At the disorder_id level,  key: disorder_id, values are hash of slots
my %gs_disorders;
my %pred_disorders;

# load gold standard files and prediction files
print "Processing task 1 F scores for $input...";
load_disorders( $gold,  \%gs_disorders );
load_disorders( $input, \%pred_disorders );

strict_f(%gs_disorders,  %pred_disorders);
relaxed_f(%gs_disorders,  %pred_disorders);

print "Finished. Result in $outputfile\n";

#####################################################################
#### Step 1. Strict F score - identify TP, FP, FN disorders
# input: gs disorder slot hash, pred disorder slot hash
#####################################################################
sub strict_f {

	my ( %gs_disorder, %pred_disorder ) = @_;

  # TP_disorders is disorder pairs $TP_disorders{gs_disorder}{pred_disorder} = 1
	my %TP_disorders;

	# FP disorders is disorders from the pred $FP_disorders{pred_disorder} = 1
	my %FP_disorders;

	# FN disorders is disorders from the gs $FN_disorders{gs_disorder} = 1
	my %FN_disorders;

	# keep track of disorders seen already or not
	my %pred_marked;
	my %gs_marked;

	# get names of documents from gold standard
	my @documents = keys %gs_disorders;

	# process predictions per document
	foreach my $document (@documents) {
		foreach my $gs_disorder ( keys %{$gs_disorders{$document}} ) {
			if ( exists ($pred_disorders{$document}) ) {
				foreach my $pred_disorder ( keys %{$pred_disorders{$document}}) {

					next if ( $pred_marked{$pred_disorder} );

					my $match = determine_exact_match(
						$gs_disorders{$document}{$gs_disorder},
						$pred_disorders{$document}{$pred_disorder}
					);

					# is there a match
					if ($match) {
						$pred_marked{$pred_disorder} = 1;
						$gs_marked{$gs_disorder}     = 1;
						$TP_disorders{$gs_disorder}  = $pred_disorder;
						next;
					}
				}

			}
		}

		# look for FN by looking at unmarked gs_disorders in document
		foreach my $gs_disorder ( keys %{$gs_disorders{$document}} ) {
			next if ( $gs_marked{$gs_disorder} );
			$FN_disorders{$gs_disorder} = 1;
		}

		# look for FP by looking at unmarked pred_disorders in document
		if ( exists $pred_disorders{$document} ) {
			foreach my $pred_disorder ( keys %{$pred_disorders{$document}} ) {
				next if ( $pred_marked{$pred_disorder} );
				$FP_disorders{$pred_disorder} = 1;
			}
		}

	}

	#  compute P, R, F for span identification

	my $P = 0, my $R = 0, my $F = 0;
	my $TP_nb = scalar (keys %TP_disorders);
	my $FP_nb = scalar (keys %FP_disorders);
	my $FN_nb = scalar (keys %FN_disorders);
	calculate_F($TP_nb, $FP_nb, $FN_nb, "Strict" );
	
	if ($trace) {
		print_trace("Strict-F", \%TP_disorders, \%FP_disorders, \%FN_disorders );
	}		
}

######################################################################
##Step 2. Relaxed F score -identify TP, FP, FN disorders
## input: gs disorder slot hash, pred disorder slot hash
######################################################################
sub relaxed_f {

	my ( %gs_disorder, %pred_disorder ) = @_;

  # TP_disorders is disorder pairs $TP_disorders{gs_disorder}{pred_disorder} = 1
	my %TP_disorders;

	# FP disorders is disorders from the pred $FP_disorders{pred_disorder} = 1
	my %FP_disorders;

	# FN disorders is disorders from the gs $FN_disorders{gs_disorder} = 1
	my %FN_disorders;

	# keep track of disorders seen already or not
	my %pred_marked;
	my %gs_marked;

	# get names of documents from gold standard
	my @documents = keys %gs_disorders;
	
	# first cull out exact span matches
	foreach my $document (@documents) {
		foreach my $gs_disorder ( keys %{ $gs_disorders{$document} } ) {
			if ( exists $pred_disorders{$document} ) {
				
				my $pred_disorder = $gs_disorder;
				next if ( $pred_marked{$pred_disorder} );
				
	
				# careful match in case spans are the same but not listed same order
				foreach my $pred_disorder ( keys %{ $pred_disorders{$document} } ) {
					next if ( $pred_marked{$pred_disorder} );
	
					if (
						determine_exact_match(
							$gs_disorders{$document}{$gs_disorder},
							$pred_disorders{$document}{$pred_disorder}
						)
					  )
					{
						$pred_marked{$gs_disorder}  = 1;
						$gs_marked{$gs_disorder}    = 1;
						$TP_disorders{$gs_disorder} = $pred_disorder;
						next;
					}
				}			
			}
		}
	}

	# process predictions per document
	foreach my $document (@documents) {
		foreach my $gs_disorder ( keys %{$gs_disorders{$document}} ) {
			my %overlap_disorders;
			if ( exists $pred_disorders{$document} ) {
				foreach my $pred_disorder ( keys %{$pred_disorders{$document}} ) {

					next if ( $pred_marked{$pred_disorder} );

					my $overlap = determine_overlaps(
						$gs_disorders{$document}{$gs_disorder},
						$pred_disorders{$document}{$pred_disorder}
					);

					# is there an overlap
					if ($overlap) {
						$overlap_disorders{$pred_disorder} = $overlap;
						$pred_marked{$pred_disorder}       = 1;
					}
				}
				next unless ( keys %overlap_disorders );
				$gs_marked{$gs_disorder} = 1;

				# sort by largest overlap
				my @pred_ids =
				  sort { $overlap_disorders{$a} <=> $overlap_disorders{$b} }
				  keys(%overlap_disorders);

				# go through overlaps and assign TP to longest and FP to others
				# pop the longest at the end of the list and assign it to TP
				my $tp_pred = pop @pred_ids;

				$TP_disorders{$gs_disorder} = $tp_pred;
				foreach my $pred_id (@pred_ids) {
					$FP_disorders{$pred_id} = 1;
				}
			}
			undef %overlap_disorders;
		}

		# look for FN by looking at unmarked gs_disorders in document
		foreach my $gs_disorder ( keys %{$gs_disorders{$document}} ) {
			next if ( $gs_marked{$gs_disorder} );
			$FN_disorders{$gs_disorder} = 1;
		}

		# look for FP by looking at unmarked pred_disorders in document
		if ( exists $pred_disorders{$document} ) {
			foreach my $pred_disorder ( keys %{$pred_disorders{$document}} ) {
				next if ( $pred_marked{$pred_disorder} );
				$FP_disorders{$pred_disorder} = 1;
			}
		}

	}

	#  compute P, R, F for span identification

	my $P = 0, my $R = 0, my $F = 0;
	my $TP_nb = scalar (keys %TP_disorders);
	my $FP_nb = scalar (keys %FP_disorders);
	my $FN_nb = scalar (keys %FN_disorders);
	calculate_F( $TP_nb, $FP_nb, $FN_nb, "Relaxed " );

	if ($trace) {
		print_trace("Relaxed-F", \%TP_disorders, \%FP_disorders, \%FN_disorders );
	}

}


########################################################
# Functions and subroutines

#######################################################
# inputs: match type (relaxed/strict), reference TP_disorders,
#		reference FP_disorders, reference FN_disorders
# if trace is 1 will print output to trace file
#######################################################
sub print_trace {
	my ( $typematch, $TP_disorders, $FP_disorders, $FN_disorders ) = @_;
	if ($trace) {
		print TRACEOUT "\n$typematch:\n";
		print TRACEOUT "TP predictions\n";
		foreach my $id (keys %{$TP_disorders}) {
			print TRACEOUT "TP: gold: $id  pred: $TP_disorders->{$id}\n";
		}
		
		print TRACEOUT "\nFP predictions\n";
		foreach my $id (keys %{$FP_disorders}) {
			print TRACEOUT "FP: $id\n";
		}
		
		print TRACEOUT "\nFN\n";
		foreach my $id (keys %{$FN_disorders}) {
			print TRACEOUT "FN: $id\n";
		}
	}
}

########################################################
# calculate and Print metrics
# inputs:  TP, FP, FN, test (name of task - ex: relaxed, strict)
# print P, R, F
########################################################
sub calculate_F {
	my ( $TP, $FP, $FN, $test ) = @_;
	my $P = 0, my $R = 0, my $F = 0;
	$P = $TP / ( $TP + $FP ) if ( ( $TP + $FP ) > 0 );
	$R = $TP / ( $TP + $FN ) if ( ( $TP + $FN ) > 0 );
	$F = 2 * $P * $R / ( $P + $R ) if ( ( $P + $R ) > 0 );

	printf OUT "$test Score\n";
	print OUT  "TP: $TP, FP: $FP, FN: $FN\n";
	printf OUT ( "P:\t %0.3f\n",  $P );
	printf OUT ( "R:\t %0.3f\n",  $R );
	printf OUT ( "F:\t %0.3f\n", $F );
	printf OUT "\n";
}

#######################################################
# Load disorders
# inputs pars: file path, hash of disorders
#######################################################
sub load_disorders {
	my ( $dir, $disorders ) = @_;
	opendir( DIR, $dir ) || die("$dir\n");
	#my @files = grep /\.text.*$/, readdir DIR;
	my @files = grep /\.pipe.*$/, readdir DIR;
	closedir DIR;
	foreach my $file (@files) {
		open( IN, "$dir/$file" ) || die "$dir/$file\n";
		while (<IN>) {

			# format of pipe file is
			# DocName|Diso_Spans|CUI|Neg_value|Neg_span|
			# Subj_value|Subj_span|Uncertain_value|Uncertain_span|
			# Course_value|Course_span|Severity_value|Severity_span|
			# Cond_value|Cond_span|Generic_value|Generic_span|
			# Bodyloc_value|Bodyloc_span");
			
			# If file was created on windows and local not set to $/ = "\r\n" 
			# make sure it's removed  
			#$_ =~ s/\r\n//; 
			
			s/\r\n//;
			chomp;
			
			my ( $DocName, $Diso_Spans, $CUI, @Other ) = split( /\|/, lc($_) );
			
			next if ( !defined $Diso_Spans );
			
			# get disorder id
			my $disorder_id = $DocName . '^' . $Diso_Spans;

		 # load slots. First, we organize by document name, then by disorder_id.
			$disorders->{$DocName}{$disorder_id}{Diso_Spans} = $Diso_Spans;
			$disorders->{$DocName}{$disorder_id}{CUI}        = $CUI;

		}
		close IN;
	}
}

#####################################################
# determine if overlap between 2 spans
# input: span 1 hash, span 2 hash
# 	     hash format: {start => val, end => val}
# output: 1 if overlap, 0 if no overlap
#####################################################
sub is_overlap {
	my ( $span1, $span2 ) = @_;
	return 1
	  if ( $span1->{start} >= $span2->{start}
		&& $span1->{start} <= $span2->{end} );
	return 1
	  if ( $span2->{start} >= $span1->{start}
		&& $span2->{start} <= $span1->{end} );

	return 0;
}

####################################################
# determine amaunt of overlap between 2 overlapping spans
# input: span 1 hash, span 2 hash
# 	     hash format: {start => val, end => val}
# output: amount of overlap
####################################################
sub get_overlap_amount {
	my ( $span1, $span2 ) = @_;

	my $max = (
		  $span1->{start} >= $span2->{start}
		? $span1->{start}
		: $span2->{start}
	);
	my $min =
	  ( $span1->{end} <= $span2->{end} ? $span1->{end} : $span2->{end} );
	return $min - $max + 1;
}


####################################################
# determine  if gold disorder and pred disorder are
# an exact match for spans and cui
# input: gold slot hash, pred slot hash
# 	     
# output: 1 if exact match, 0 if not exact match
####################################################
sub determine_exact_match {
	my ( $gs_slots, $pred_slots ) = @_;

	# return 0 if CUIs don't match
	return 0 if ( $gs_slots->{CUI} ne $pred_slots->{CUI} );

	# easy way -  if spans are same 
	return 0 if ( $gs_slots->{Diso_Spans} ne $pred_slots->{Diso_Spans} );
	
	return 1;

}

#######################################################
# Determine if there is overlap between a gs disorder span
# and a prediction disorder span.
# input: gs disorder slot hash, pred disorder slot hash
# output: amount of overlap, 0 if no overlap
#######################################################
sub determine_overlaps {
	my ( $gs_slots, $pred_slots ) = @_;

	# return 0 if CUIs don't match
	return 0 if ( $gs_slots->{CUI} ne $pred_slots->{CUI} );

	my @gs_span_strings   = split( ',', $gs_slots->{Diso_Spans} );
	my @pred_span_strings = split( ',', $pred_slots->{Diso_Spans} );
	my @gs_spans;
	my @pred_spans;

	foreach my $val (@gs_span_strings) {
		my ( $start, $end ) = split( "-", $val );
		push @gs_spans, { start => $start, end => $end };
	}

	foreach my $val (@pred_span_strings) {
		my ( $start, $end ) = split( "-", $val );
		push @pred_spans, { start => $start, end => $end };
	}

	# Do pairwise test between each span for gs and pred.
	# Where spans are discontinuous, we do a pairwise
	# comparason for each gs and each
	# pred, the largest amount of overlap is returned.
	my $max_overlap_amount = 0;
	foreach my $gs_span_obj (@gs_spans) {
		foreach my $pred_span_obj (@pred_spans) {
			if ( is_overlap( $gs_span_obj, $pred_span_obj ) ) {
				my $o_amt = get_overlap_amount( $gs_span_obj, $pred_span_obj );

				# is overlap largest so far ?
				if ( $o_amt > $max_overlap_amount ) {
					$max_overlap_amount = $o_amt;
				}
			}
		}
	}

	# Return largest overlap amount between spans.
	return $max_overlap_amount;
}
