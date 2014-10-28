#!/usr/bin/perl -w

############################################################
#
# Script to evaluate the slot filling task for the two SemEval 
# 2015 sub tasks. Computed metrics are per-slot overall accuracy, 
# overall weighted accuracy, and overall unweighted accuracy. 
#
##############################################################


# Parameters:
# -input (prediction directory)
# -gold (goldstandard directory)
# -n (specify name of team)
# -r (specify 1, 2, or 3 for which run)
# -t (specify A or B)
# -trace (optional trace 1 (on) or 0 (off) )


# Output file: $name_task$task_run$run.out
# Example: 	n_task2A_run1.out 
#			n_task2B_run1.out

# Example usage:
# ./task2_eval.pl -n team -r 1 -t A  -input team_dir -gold gold_dir
# ./task2_eval.pl -n team -r 1 -t B  -input team_dir -gold gold_dir

# Example usage with trace one:
# ./task2_eval.pl -n team -r 1 -t A  -input team_dir -gold gold_dir -trace 1

use strict;
use warnings;
use Getopt::Long;

my $name  = "";
my $run   = "";
my $input = "";
my $gold  = "";
my $trace = 0;
my $task = "";
my $error =
"# Parameters:\n# -input (prediction file)\n# -gold (goldstandard file)\n# -n (specify name of run)\n# -r (specify 1 or 2 for which run)\n# -t (specifiy A, B)\n# -trace (optional: 1 turns trace on, 0 trace off - by default trace is off)\n";

GetOptions(
    'trace:i' => \$trace,
	'n=s'     => \$name,
	'r=n'     => \$run,
	't=s'	  => \$task,
	'input=s' => \$input,
	'gold=s'  => \$gold	
) || die "$error";

if ( ( $name eq "" ) || ( $input eq "" ) || ( $gold eq "" ) ) {
	die "$error";
}
if ( ( $run != 1 ) && ( $run != 2 ) && ( $run != 3 )) {
	die "Incorrect run id\n";
}
if (($task ne "A")&&($task ne "B")) {
    die "Incorrect task id\n";}

if ($trace) {
	my $tracefile = $name . "_" . "task2$task" . "_run" . "$run.trace";
	open( TRACEOUT, ">$tracefile" );
}

# open output file
my $outputfile = $name . "_" . "task2$task" . "_run" . "$run.out";
open( OUT, ">$outputfile" ) || die "Error: Cannot write file: $outputfile\n";

#########################
my %canonical_slots = (
	CUI      => { "ANY_CUI" => 1, },
	Negation => {
		"no"  => .21,
		"yes" => .79
	},
	Subject => {
		"patient"       => .01,
		"family_member" => .99,
		"other"         => 1,
		"doner_other"   => 1
	},
	Uncertainty => {
		"no"  => .07,
		"yes" => .93
	},
	Course => {
		"unmarked"  => .04,
		"increased" => .99,
		"improved"  => .99,
		"worsened"  => .99,
		"resolved"  => .99,
		"decreased" => 1,
		"changed"   => 1
	},
	Severity => {
		"unmarked" => .08,
		"moderate" => .96,
		"severe"   => .97,
		"slight"   => .99
	},
	Conditional => {
		"false" => .06,
		"true"  => .94
	},
	Generic => {
		"false" => .01,
		"true"  => .99
	},
	BodyLoc => {
		"null"    => .51,
		"ANY_CUI" => .49
	}
);

#####################################################
# Define Important globals
#####################################################
# gs_disorders and pred_disorders hold disorder_id's organized by document.
# for the gold standar and predictions respectivly.
# The data structure is multi-level hash.
# Top level key: is a document name, value: is a hash of disorder_id.
# At the disorder_id level,  key: disorder_id, values are hash of slots
my %gs_disorders;
my %pred_disorders;

# TP_disorders is disorder pairs $TP_disorders{gs_disorder}{pred_disorder} = 1
my %TP_disorders;

# FP disorders is disorders from the pred $FP_disorders{pred_disorder} = 1
my %FP_disorders;

# FN disorders is disorders from the gs $FN_disorders{gs_disorder} = 1
my %FN_disorders;

# load gold standard files and prediction files
load_disorders( $gold,  \%gs_disorders );
load_disorders( $input, \%pred_disorders );

######################################################################
##### Step 1. identify TP, FP, FN disorders
######################################################################
# keep track of disorders seen already or not
my %pred_marked;
my %gs_marked;


# get names of documents from gold standard
my @documents = keys %gs_disorders;
print "Processing slot filling task for $input...";

# process predictions per document
# first cull exact span matches
foreach my $document (@documents) {
	foreach my $gs_disorder ( keys %{ $gs_disorders{$document} } ) {
		if ( exists $pred_disorders{$document} ) {
			
			my $pred_disorder = $gs_disorder;
			next if ( $pred_marked{$pred_disorder} );
			
			# first test for exatct id match
			if ( exists $pred_disorders{$document}{$pred_disorder} ) {
				$pred_marked{$gs_disorder}  = 1;
				$gs_marked{$gs_disorder}    = 1;
				$TP_disorders{$gs_disorder} = $pred_disorder;
				next;
			}
		}
	}
}
# Next look for inexact matches by looking for span overlaps
foreach my $document (@documents) {
	foreach my $gs_disorder ( keys %{ $gs_disorders{$document} } ) {
		my %overlap_disorders;
		if ( exists $pred_disorders{$document} ) {	

			foreach my $pred_disorder ( keys %{ $pred_disorders{$document} } ) {

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

			#$TP_disorders{$gs_disorder}{$tp_pred} = 1;  -- assign value instead
			$TP_disorders{$gs_disorder} = $tp_pred;
			foreach my $pred_id (@pred_ids) {
				$FP_disorders{$pred_id} = 1;
			}
		}
		undef %overlap_disorders;
	}

	# look for FN by looking at unmarked gs_disorders in document
	foreach my $gs_disorder ( keys %{ $gs_disorders{$document} } ) {
		next if ( $gs_marked{$gs_disorder} );
		$FN_disorders{$gs_disorder} = 1;
	}

	# look for FP by looking at unmarked pred_disorders in document
	if ( exists $pred_disorders{$document} ) {
		foreach my $pred_disorder ( keys %{ $pred_disorders{$document} } ) {
			next if ( $pred_marked{$pred_disorder} );
			$FP_disorders{$pred_disorder} = 1;
		}
	}
}

# finished step 1 (processing disorders in all documents)

######################################################
##### Step 2. compute P, R, F for span identification
######################################################
my $P = 0, my $R = 0, my $F = 0;
my $TP_nb = scalar( keys %TP_disorders );
my $FP_nb = scalar( keys %FP_disorders );
my $FN_nb = scalar( keys %FN_disorders );

#calc P,R, F -  check denominator to avoid division by zero
$P = $TP_nb / ( $TP_nb + $FP_nb ) if ( ( $TP_nb + $FP_nb ) > 0 );
$R = $TP_nb / ( $TP_nb + $FN_nb ) if ( ( $TP_nb + $FN_nb ) > 0 );
$F = 2 * $P * $R / ( $P + $R ) if ( ( $P + $R ) > 0 );

####################################################
##### Step 3. compute slot-filling accuracies
####################################################
my $accuracy      = 0;
my $wt_accuracy   = 0;
my $F_ACCURACY    = 0;
my $F_WT_ACCURACY = 0;

 # hash to save wts for each attribute slot - used in calc weight accuracy per slot 
my %pred_per_slot;   

# Calculate Unweighted accuracy
# sum over slots divided by nb of slots
foreach my $gs_disorder ( keys %TP_disorders ) {
	my $pred_disorder = $TP_disorders{$gs_disorder};
	my $per_disorder_acc = per_disorder_acc( $gs_disorder, $pred_disorder );
	$accuracy += $per_disorder_acc;
}
$accuracy = $accuracy / ( keys %TP_disorders ) if ( keys %TP_disorders > 0 );
$F_ACCURACY = $F * $accuracy;



# Initalize slots to hold wt accuracy
foreach my $slot ( keys %canonical_slots ) {
	$pred_per_slot{$slot}{'wt_accuracy'} = 0;
	$pred_per_slot{$slot}{'norm'}        = 0;
}

print TRACEOUT "weighted accuracy\n" if ($trace);

# Calculate Weighted accuracy
# sum over slots divided by sum of wt for each gs slot
foreach my $gs_disorder ( keys %TP_disorders ) {
	my $pred_disorder = $TP_disorders{$gs_disorder};
	
	print TRACEOUT "\nTP: $gs_disorder:" if ($trace);	
	
	my $per_disorder_acc =
	  per_disorder_wt_acc( $gs_disorder, $pred_disorder, \%pred_per_slot );
	$wt_accuracy += $per_disorder_acc;	
}

$wt_accuracy = $wt_accuracy / ( keys %TP_disorders )
  if ( keys %TP_disorders > 0 );
$F_WT_ACCURACY = $F * $wt_accuracy;

########################################################
##### Step 4. Print metrics
# print P, R, F,
# print accuracy, F*accuracy, wt_accuracy, F*wt_accuracy
########################################################
print OUT "TP: $TP_nb FP: $FP_nb FN: $FN_nb\n";
printf OUT ( "P:\t %0.3f \n",              $P );
printf OUT ( "R:\t %0.3f \n",              $R );
printf OUT ( "F:\t %0.3f\n\n",             $F );
printf OUT ( "Accuracy:\t %0.3f \t",       $accuracy );
printf OUT ( "F*Accuracy:\t %0.3f \n",     $F_ACCURACY );
printf OUT ( "Wt_Accuracy:\t %0.3f \t",    $wt_accuracy );
printf OUT ( "F*Wt_Accuracy:\t %0.3f\n", $F_WT_ACCURACY );

print OUT "\nSlot Weighted Accuracy:\n";

print TRACEOUT "\nSlot Weighted Accuracy:\n" if ($trace);

foreach my $slot ( keys %canonical_slots ) {
	my $slot_wt_acc =
	  $pred_per_slot{$slot}{'wt_accuracy'} / $pred_per_slot{$slot}{'norm'};
	printf OUT ( "%-11s\t%0.3f \n", $slot.":", $slot_wt_acc );
	
	# trace output
	if ($trace) {
		print TRACEOUT "$slot: $pred_per_slot{$slot}{'wt_accuracy'}/$pred_per_slot{$slot}{'norm'} =  $slot_wt_acc\n" ;
	}	
	
}

if ($trace) {
	# print totrace file
	print TRACEOUT "\nFP Predictions:\n";
	foreach my $id ( keys %FP_disorders ) {
		print TRACEOUT "FP: $id\n";
	}
		
	print TRACEOUT "\nTP Predictions:\n";
	foreach my $id ( keys %TP_disorders ) {
		print TRACEOUT "TP: gold: $id   pred: $TP_disorders{$id}\n";
	}
	
	print TRACEOUT "\nFN:\n";
	foreach my $id ( keys %FN_disorders ) {
		print TRACEOUT "FN: $id \n";
	}
}

print "Finished. Result in $outputfile\n";

########################################################
# Functions and subroutines

#######################################################
# Load disorders
# inputs pars: file path, hash of disorders
#######################################################
sub load_disorders {
	my ( $dir, $disorders ) = @_;
	opendir( DIR, $dir ) || die("$dir\n");
	my @files = grep /\.pipe.*$/, readdir DIR;
	closedir DIR;
	foreach my $file (@files) {

		#print "$dir/$file\n";
		open( IN, "$dir/$file" ) || die "$dir/$file\n";
		while (<IN>) {

			# format of pipe file is
			# DocName|Diso_Spans|CUI|Neg_value|Neg_span|
			# Subj_value|Subj_span|Uncertain_value|Uncertain_span|
			# Course_value|Course_span|Severity_value|Severity_span|
			# Cond_value|Cond_span|Generic_value|Generic_span|
			# Bodyloc_value|Bodyloc_span");
			chomp;
			

			my (
				$DocName,       $Diso_Spans,      $CUI,
				$Neg_value,     $Neg_span,        $Subj_value,
				$Subj_span,     $Uncertain_value, $Uncertain_span,
				$Course_value,  $Course_span,     $Severity_value,
				$Severity_span, $Cond_value,      $Cond_span,
				$Generic_value, $Generic_span,    $Bodyloc_value,
				$Bodyloc_span
			) = split( /\|/, lc($_) );

			# get disorder id
			# in case chomp not stripping windows CRLF
			next if ( !defined $Diso_Spans );

			my $disorder_id = $DocName . '^' . $Diso_Spans;

		 # load slots. First, we organize by document name, then by disorder_id.
			$disorders->{$DocName}{$disorder_id}{Diso_Spans} = $Diso_Spans;
			$disorders->{$DocName}{$disorder_id}{CUI}        = $CUI;
			$disorders->{$DocName}{$disorder_id}{Negation}   = $Neg_value;
			$disorders->{$DocName}{$disorder_id}{Subject}    = $Subj_value;
			$disorders->{$DocName}{$disorder_id}{Uncertainty} =
			  $Uncertain_value;
			$disorders->{$DocName}{$disorder_id}{Course}      = $Course_value;
			$disorders->{$DocName}{$disorder_id}{Severity}    = $Severity_value;
			$disorders->{$DocName}{$disorder_id}{Conditional} = $Cond_value;
			$disorders->{$DocName}{$disorder_id}{Generic}     = $Generic_value;
			$disorders->{$DocName}{$disorder_id}{BodyLoc}     = $Bodyloc_value;
		}
		close IN;
	}
}

##################################################################
# calculate per disorder weighted accuracy
# input parameters: gold_standard disorder and predicted disorder
# output: weighted accuracy for the disorder
##################################################################
sub per_disorder_wt_acc {
	my ( $gs_disorder_id, $pred_disorder_id, $pred_per_slot ) = @_;
	
	my ( $document,      $gs_span )   = split( /\^/, $gs_disorder_id );
	my ( $pred_document, $pred_span ) = split( /\^/, $pred_disorder_id );

	# print error if documents don't match
	die
"document name for predicted disorder does not match gold standard's document name!\n"
	  if ( $document ne $pred_document );
	  
	print TRACEOUT "\n" if ($trace);
	# variables for trace
	
	my $gs_disorder   = $gs_disorders{$document}{$gs_disorder_id};
	my $pred_disorder = $pred_disorders{$document}{$pred_disorder_id};

	my ( $norm_gs_wts, $acc ) = ( 0, 0 );

	# Go through the canonical slots
	foreach my $slot ( keys %canonical_slots ) {

		# get weight for the slot value of the gs_disorder
		my $gs_slot_value = $gs_disorder->{$slot};

		# special weights for CUI and BodyLoc
		if ( $slot eq 'CUI' ) {
			$gs_slot_value = "ANY_CUI";
		}
		if ( $slot eq 'BodyLoc' ) {
			$gs_slot_value = 'ANY_CUI' unless ( $gs_slot_value eq 'null' );
		}
		my $gs_slot_wt = $canonical_slots{$slot}{$gs_slot_value};

		# compute the normalization factor from the gold-standard weights
		$norm_gs_wts += $gs_slot_wt;
		$pred_per_slot->{$slot}{'norm'} += $gs_slot_wt;
		

		print TRACEOUT "$slot: gold_value: $gs_disorder->{$slot}\tpred_value: $pred_disorder->{$slot}  " if ($trace);
		# compare slot values between gold standard and predicted
		if ( $pred_disorder->{$slot} eq $gs_disorder->{$slot} ) {
			$acc += $gs_slot_wt;
			$pred_per_slot->{$slot}{'wt_accuracy'} += $gs_slot_wt;
			
			# my debug 
			print TRACEOUT " $gs_slot_wt\n" if ($trace);				
		}
		else {
			print TRACEOUT  "0\n" if ($trace);
		}
	
	}

	if ( $norm_gs_wts == 0 ) {
		die "problem with gold standard weights\n";
	}
	
	# my debug code 
	

	print TRACEOUT "$acc/$norm_gs_wts=" if ($trace);  
	
	$acc = $acc / $norm_gs_wts;
	
	print TRACEOUT "$acc\n" if ($trace);
	
	return $acc;
}

##################################################################
# calculate per disorder accuracy
# input parameters: gold_standard disorder and predicted disorder
# output: unweighted accuracy for the disorder
##################################################################
sub per_disorder_acc {
	my ( $gs_disorder_id, $pred_disorder_id ) = @_;
	my ( $document, $gs_span ) = split( /\^/, $gs_disorder_id );
	my ( $pred_document, $pred_span ) = split( /\^/, $pred_disorder_id );

	# print error if documents don't match
	die
"document name for predicted disorder does not match gold standard's document name!\n"
	  if ( $document ne $pred_document );
	

	my $gs_disorder   = $gs_disorders{$document}{$gs_disorder_id};
	my $pred_disorder = $pred_disorders{$document}{$pred_disorder_id};

	my $agree     = 0;
	my $num_slots = keys %canonical_slots;

	# accuracy = # correct slot values / number of slots

	# Go through the canonical slots
	foreach my $slot ( keys %canonical_slots ) {

		# compare slot values between gold standard and predicted
		# increment if agreement
		if ( $pred_disorder->{$slot} eq $gs_disorder->{$slot} ) {
			$agree++;
		}
		
	}

	return $agree / $num_slots;
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

#######################################################
# Determine if there is overlap between a gs disorder span
# and a prediction disorder span.
# input: gs disorder slot hash, pred disorder slot hash
# output: amount of overlap, 0 if no overlap
#######################################################
sub determine_overlaps {
	my ( $gs_slots, $pred_slots ) = @_;

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

