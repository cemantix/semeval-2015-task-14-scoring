SemEval-2015 Task 14 evaluation metrics
=======================================
#### Authors: Noemie  Elhadad, Sharon R. L Gorman 
#### Columbia University
#### 10/2014

## task1_eval.pl

Script evaluating F-score for Disorder Identification Task. A single
execution of the script calculates two scores; 1) strict F-score and
2) relaxed F-score.
  
### Input Parameters:
  -input (prediction directory)
  -gold (gold standard directory)
  -n (specify name of team)
  -r (specify 1, 2 or 3 for which run)
  -trace (optional: 1 turns trace on; 0 or omit option 
                      to turn trace off )
    
### Output 
  File reporting evaluation metrics for run
    
  Format of output file name: 
    team_task1_run1.out 
    team_task1_run2.out
      
  
  if -trace 1 option is given trace file is created in 
  same name as output file  with .trace file extension.
  example: team_task1_run1.trace 
      
      

### Example usages:

  to specify run 1:
    ./task1_eval.pl  -n team -r 1  -input team_dir -gold gold_dir
  
  to specify run 2:
    ./task1_eval.pl  -n team -r 2  -input team_dir -gold gold_dir
  
  to specify run 3:
    ./task1_eval.pl  -n team -r 3  -input team_dir -gold gold_dir

  to execute run 1 with trace on:
    ./task1_eval.pl l -n team -r 1  -input team_dir -gold gold_dir -trace 1


  
  
## task2_eval.pl
  Script to evaluate the slot filling task for the two sub tasks. 
  Computed metrics are per-slot overall accuracy, overall weighted 
  accuracy, and overall unweighted accuracy. 
  
### Input parameters
  -input (prediction directory)
  -gold (gold standard directory)
  -n (specify name of team)
  -r (specify 1, 2 or 3 for which run)
  -t (specify A or B for task)
  -trace (optional: 1 turns trace on; 0 or omit 
            option to turn trace off)
    
### Output
  file reporting evaluation metrics for run and task.
  Output includes, F*Accuracy,  F*Wt_Accuracy and 
  slot Weighted Accuracy.
    
  Format of output file name: 
    team_task2A_run1.out   (for: task A run 1)
    team_task2A_run2.out   (for: task A run 2)
    team_task2A_run3.out   (for: task A run 3)
    team_task2B_run1.out   (for: task B run 1)
    team_task2B_run2.out   (for: task B run 2)
    team_task2B_run3.out   (for: task B run 3)
    
  if -trace 1 option is given trace file is created in 
  same name as output file  with .trace file extension.
  example: team_task2A_run1.trace
      
### Example usage:

to specify run 1 task A:
  ./task2_eval.pl -n team -r 1 -t A  -input team_dir -gold gold_dir
    
to specify run 1 task B:
  ./task2_eval.pl -n team -r 1 -t B  -input team_dir -gold gold_dir
    
to specify run 2 task A:
  ./task2_eval.pl -n team -r 2 -t A  -input team_dir -gold gold_dir
    
to specify run 2 task B:
  ./task2_eval.pl -n team -r 2 -t B  -input team_dir -gold gold_dir
  
to specify run 3 task A:
  ./task2_eval.pl -n team -r 3 -t A  -input team_dir -gold gold_dir
    
to specify run 3 task B:
  ./task2_eval.pl -n team -r 3 -t B  -input team_dir -gold gold_dir
    
  
  
to execute run 1 task A with trace on:
  ./task2_eval.pl -n team -r 1 -t A  -input team_dir -gold gold_dir -trace 1
  
  
  
  

Important information regarding input file format and naming
=============================================================

1. Both gold standard and prediction input must contain a '.pipe' in the name.

   Example:
   correct:   00235-001028-DISCHARGE_SUMMARY.pipe 
        00235-001028-DISCHARGE_SUMMARY.pipe.txt
              
   incorrect: 00235-001028-DISCHARGE_SUMMARY.txt
   
2. Document name for a prediction must map to the identical document name in the gold standard to test for a span match. This is obvious, but just stating it for emphasis.
 
   Example: 
   correct:
  disorder 1 Prediction file, DocName field: 00235-001028-DISCHARGE_SUMMARY.txt
  disorder 1 gold standard file, DocName field: 00235-001028-DISCHARGE_SUMMARY.txt
   
   incorrect:
  disorder 1 Prediction file,     DocName field: 00235-001028.txt
  disorder 1 gold standard file,  DocName field: 00235-001028-DISCHARGE_SUMMARY.txt

3. Discontinuous disorder spans must be listed in increasing order to consider an exact 
   match to gold standard.
   Example:
   correct: 1006-1010,1027-1028
   
   incorrect: 1027-1028,1006-1010
   
4. Script task1_eval.pl  expects the following input format for both gold standard and prediction files:
    
   DocName|Diso_Spans|CUI|
  
   There is a single pipe field delimiter.
  
 5) Script task2_eval.pl expects the following input format for both gold standard and prediction files:
    
    DocName|Diso_Spans|CUI|Neg_value|Neg_span|Subj_value|Subj_span|Uncertain_value|Uncertain_span|Course_value|Course_span|Severity_value|Severity_span|Cond_value|Cond_span|Generic_value|Generic_span|Bodyloc_value|Bodyloc_span|
 
    As shown above there is a single pipe field delimiter with an extra pipe after the last field.a

