#!/bin/bash

# peak_distrib_matrix.sh
########################
# takes as input
################
# - a file of unstranded peaks in bed format
# - a file of gene annotation with at least exon rows that must have at least gene_id in the 9th field in gtf or gff2 format
# produces as standard output
#############################
# - the peaks distribution matrix as a tsv file with header that has peaks in rows and list of genes reflecting
#   the intersection with different genomic domains as columns (exons, introns, tss, tss1kb, tss5kb, tts, tts1kb, tts5kb)
# !!! be careful not made to be used several times in the same directory since uses fixed names !!!

# Example
#########
# cd /work/project/fragencode/workspace/sdjebali/atacseq/fragencode/peaks/peakdistrib/pergene_andrea/test
# pig=/work/project/fragencode/results/atacseq/sus_scrofa/indiv.peaks.merged/mergedpeaks.peaknb.readcov.bed
# annot=/work/project/fragencode/data/species/sus_scrofa/Sscrofa10.2.84/sus_scrofa.gtf
# time peak_distrib_matrix.sh $pig $annot > mergedpeaks_allinfo.tsv 2> peak_distrib_matrix.err
# real	0m26.723s  

# More precisely The body of the matrix will contain the following:
###################################################################
# - chromosome of the atac-seq peak
# - beg of the atac-seq peak (in bed coord)
# - end of the atac-seq peak (in bed coord)
# - list of genes with at least one exon overlapping the atac-seq peak (by at least 1 bp)
# - list of genes with at least one intron encompassing the atac-seq peak
# - list of genes with their most 5' bp overlapping the atac-seq peak
# - list of genes with the 1kb window around their most 5' bp overlapping the atac-seq peak
# - list of genes with the 5kb window around their most 5' bp overlapping the atac-seq peak
# - list of genes with their most 3' bp overlapping the atac-seq peak
# - list of genes with the 1kb window around their most 3' bp overlapping the atac-seq peak
# - list of genes with the 5kb window around their most 3' bp overlapping the atac-seq peak

# For this I need to do the following intersections:
####################################################
# 1) peaks with exons and get the gene list
# 2) peaks with introns (inclusion option) and get the gene list
# 3) peaks with most 5' bp of each gene and get the gene list
# 4) peaks with window of 1kb around most 5'bp of each gene and get the gene list
# 5) peaks with window of 5kb around most 5'bp of each gene and get the gene list
# 6) peaks with most 3' bp of each gene and get the gene list
# 7) peaks with window of 1kb around most 3'bp of each gene and get the gene list
# 8) peaks with window of 5kb around most 3'bp of each gene and get the gene list

# This way I will be able to know
#################################
# - list of genes with at least one exon overlapping the atac-seq peak (by at least 1 bp)
#   --> using 1)
# - list of genes with at least one intron encompassing the atac-seq peak
#   --> using 2) and 1) since could be overlapping an exon and totally included in an intron of the same gene
# - list of genes with their most 5' bp overlapping the atac-seq peak
#   --> using 3)
# - list of genes with the 1kb window around their most 5' bp overlapping the atac-seq peak
#   --> using 4)
# - list of genes with the 5kb window around their most 5' bp overlapping the atac-seq peak
#   --> using 5)
# - list of genes with their most 3' bp overlapping the atac-seq peak
#   --> using 6)
# - list of genes with the 1kb window around their most 3' bp overlapping the atac-seq peak
#   --> using 7)
# - list of genes with the 5kb window around their most 3' bp overlapping the atac-seq peak
#   --> using 8)

# Check if both needed inputs are present otherwise exits
#########################################################
if [ ! -n "$1" ] || [ ! -n "$2" ]
then
    echo Usage: peak_distrib_matrix.sh peaks.bed annot.gff >&2
    echo "" >&2
    echo "Takes as input" >&2
    echo "- a file of unstranded peaks in bed format" >&2
    echo "- a file of gene annotation with at least exon rows that must have at least gene_id in the 9th field in gtf or gff2 format" >&2
    echo "" >&2
    echo "Provides as output in the working directory" >&2
    echo "- the peaks distribution matrix as a tsv file with header that has peaks in rows and list of genes reflecting" >&2
    echo "  the intersection with different genomic domains as columns (exons, introns, tss, tss1kb, tss5kb, tts, tts1kb, tts5kb)" >&2
    echo "- multiple intermediate tsv files with individual intersection results" >&2
    echo "" >&2
    echo "!!! be careful: do not run twice simulaneously in the same working directory since uses files with fixed names !!!" >&2
    exit 1
fi

# General variables
###################
path="`dirname \"$0\"`" # relative path
rootDir="`( cd \"$path\" && pwd )`" # absolute path
peaks=$1
annot=$2
b=`basename ${annot%.gff}`
b2=${b%.gtf} 

# Programs
##########
BED2GFF=$rootDir/../Awk/bed2gff2.awk
MAKEOK=$rootDir/../Awk/make_gff_ok.awk
CUTGFF=$rootDir/../Awk/cutgff.awk
INTRONS=$rootDir/../Awk/make_introns.awk
MAKETSS=$rootDir/make_TSS_file_from_annotation_simple.sh
MAKETTS=$rootDir/make_TTS_file_from_annotation_simple.sh
GFF2GFF=$rootDir/../Awk/gff2gff.awk
OVERLAP=$rootDir/../bin/overlap
CLASSIF=$rootDir/../Awk/peakoverlap2classif.awk


#######################################################
# 1. Make all the files needed for the intersections  #
#######################################################
echo I am making all the files needed for the intersections >&2
# a. Make a gff file of atac-seq peaks from the bed file provided as 1st input
##############################################################################
# 1	1912	2237	.	5	+	5795	6748	11399	11094	6416	9561	9076	13502	10249	16273	9317
# 56364 (17 fields)  
echo "  - The merged peaks" >&2
awk -v sc=1 -v pgm=fragenc -v feat=atacpeak -f $BED2GFF $peaks > mergedpeaks.gff
# 1	fragenc	atacpeak	1913	2237	.	+	.	name: . sc: 5 
# 56364 (12 fields)

# b. Make an ok file of exons but ordered according to transcript id and then coord from the annotation gtf or gff2 file provided as 2nd input
##############################################################################################################################################
echo "  - The ok exon file sorted properly for making the intron file" >&2
awk '$3=="exon"' $annot | awk -f $MAKEOK | sort -k12,12 -k4,4n -k5,5n | awk -v to=12 -f $CUTGFF > exons.gff
# 5	ensembl	exon	588811	588841	.	-	.	gene_id "ENSSSCG00000000001"; transcript_id "ENSSSCT00000000001";
# 238668 (12 fields)

# c. Make a file of introns from the above sorted exon gff2 file
################################################################
echo "  - The intron file" >&2
awk -v fldgn=10 -v fldtr=12 -f $INTRONS exons.gff > introns.gff
# 5	ensembl	intron	588842	589615	.	-	.	gene_id "ENSSSCG00000000001"; transcript_id "ENSSSCT00000000001";  
# 208083 (12 fields)

# d. Make a gff2 file of TSS with gene_id from the annotation gtf or gff2 file provided as 2nd input
####################################################################################################
echo "  - The TSS file" >&2
$MAKETSS exons.gff
# has created a file called exons_capped_sites_nr.gff
# GL892233.1	.	TSS	21	21	.	+	.	gene_id "ENSSSCG00000028326"; trlist "ENSSSCT00000029565,";
# 29134 (12 fields) *** real	0m12.975s

# e. Make a gff2 file of TTS with gene_id from the annotation gtf or gff2 file provided as 2nd input
####################################################################################################
echo "  - The TTS file" >&2
$MAKETTS exons.gff
# has created a file called exons_tts_sites_nr.gff
# GL892233.1	.	TTS	1787	1787	.	+	.	gene_id "ENSSSCG00000028326"; trlist "ENSSSCT00000029565,";
# 29096 (12 fields)

# f. Make a gff2 file of TSS 1kb and a gff2 file of TSS 5kb windows from the TSS file generated above
#####################################################################################################
echo "  - The TSS file extended by 1kb on each side" >&2
awk -v ext=1000 '{$4=$4-ext; $5=$5+ext; $3=($3)"ext"(toext); if($4<0){$4=0} print $0}' exons_capped_sites_nr.gff | awk -f $GFF2GFF > exons_capped_sites_nr_ext1000.gff
# GL892233.1	.	TSSext	0	1021	.	+	.	gene_id "ENSSSCG00000028326"; trlist "ENSSSCT00000029565,";
# 29134 (12 fields) *** real	0m0.226s  *** checked that most are 2001 bp
echo "  - The TSS file extended by 5kb on each side" >&2
awk -v ext=5000 '{$4=$4-ext; $5=$5+ext; $3=($3)"ext"(toext); if($4<0){$4=0} print $0}' exons_capped_sites_nr.gff | awk -f $GFF2GFF > exons_capped_sites_nr_ext5000.gff
# GL892233.1	.	TSSext	0	5021	.	+	.	gene_id "ENSSSCG00000028326"; trlist "ENSSSCT00000029565,";
# 29134 (12 fields)  *** checked that most are 10 001 bp

# g. Make a gff2 file of TTS 1kb and a gff2 file of TTS 5kb windows from the TTS file generated above
#####################################################################################################
echo "  - The TTS file extended by 1kb on each side" >&2
awk -v ext=1000 '{$4=$4-ext; $5=$5+ext; $3=($3)"ext"(toext); if($4<0){$4=0} print $0}' exons_tts_sites_nr.gff | awk -f $GFF2GFF > exons_tts_sites_nr_ext1000.gff
# GL892233.1	.	TTSext	787	2787	.	+	.	gene_id "ENSSSCG00000028326"; trlist "ENSSSCT00000029565,";
# 29096 (12 fields)
echo "  - The TTS file extended by 5kb on each side" >&2
awk -v ext=5000 '{$4=$4-ext; $5=$5+ext; $3=($3)"ext"(toext); if($4<0){$4=0} print $0}' exons_tts_sites_nr.gff | awk -f $GFF2GFF > exons_tts_sites_nr_ext5000.gff
# GL892233.1	.	TTSext	0	6787	.	+	.	gene_id "ENSSSCG00000028326"; trlist "ENSSSCT00000029565,";
# 29096 (12 fields)
echo done >&2



##################################
# 2. Make all the intersections  #
##################################
echo "I am making all the intersections" >&2
# a. Intersect the 1st file elements with the exons of the 2nd file and remember the list of gene_id in an nr way
################################################################################################################
echo "  - the intersection between the peaks and the exons and remembering the nr list of gene ids" >&2
$OVERLAP mergedpeaks.gff exons.gff -m 10 -nr -f ex -v | sort -k1,1 -k4,4n -k5,5n | awk 'BEGIN{OFS="\t"}{gsub(/\;/,"",$NF); gsub(/\"/,"",$NF); print $1, $4-1, $5, $NF}' > mergedpeaks_over_exons.bed
# 1	1912	2237	.
# 56364 (4 fields)

# b. Intersect the 1st file elements with the introns of the 2nd file and remember the list of gene_id in an nr way and with inclusion mode
###########################################################################################################################################
echo "  - the intersection between the peaks and the introns (total inclusion) and remembering the nr list of gene ids" >&2
$OVERLAP mergedpeaks.gff introns.gff -m 10 -i 1 -nr -f intr -v | sort -k1,1 -k4,4n -k5,5n | awk 'BEGIN{OFS="\t"}{gsub(/\;/,"",$NF); gsub(/\"/,"",$NF); print $1, $4-1, $5, $NF}' > mergedpeaks_over_introns.tsv
# 1	1912	2237	.
# 56364 (4 fields)

# c. Intersect the 1st file elements with the TSS of the 2nd file and remember the list of gene_id in an nr way
###############################################################################################################
echo "  - the intersection between the peaks and the TSS and remembering the nr list of gene ids" >&2
$OVERLAP mergedpeaks.gff exons_capped_sites_nr.gff -m 10 -nr -f tss -v | sort -k1,1 -k4,4n -k5,5n | awk 'BEGIN{OFS="\t"}{gsub(/\;/,"",$NF); gsub(/\"/,"",$NF); print $1, $4-1, $5, $NF}' > mergedpeaks_over_tss.bed
# 1	1912	2237	.
# 56364 (4 fields)

# d. Intersect the 1st file elements with the 1kb TSS windows of the 2nd file and remember the list of gene_id in an nr way
############################################################################################################################
echo "  - the intersection between the peaks and the TSS extended by 1 kb and remembering the nr list of gene ids" >&2
$OVERLAP mergedpeaks.gff exons_capped_sites_nr_ext1000.gff -m 10 -nr -f tss1000 -v | sort -k1,1 -k4,4n -k5,5n | awk 'BEGIN{OFS="\t"}{gsub(/\;/,"",$NF); gsub(/\"/,"",$NF); print $1, $4-1, $5, $NF}' > mergedpeaks_over_tss_ext1000.bed
# 1	1912	2237	.
# 56364 (4 fields)

# e. Intersect the 1st file elements with the 5kb TSS windows of the 2nd file and remember the list of gene_id in an nr way
############################################################################################################################
echo "  - the intersection between the peaks and the TSS extended by 5 kb and remembering the nr list of gene ids" >&2
$OVERLAP mergedpeaks.gff exons_capped_sites_nr_ext5000.gff -m 10 -nr -f tss5000 -v | sort -k1,1 -k4,4n -k5,5n | awk 'BEGIN{OFS="\t"}{gsub(/\;/,"",$NF); gsub(/\"/,"",$NF); print $1, $4-1, $5, $NF}' > mergedpeaks_over_tss_ext5000.bed
# 1	1912	2237	.
# 56364 (4 fields)

# f. Intersect the 1st file elements with the TTS of the 2nd file and remember the list of gene_id in an nr way
################################################################################################################
echo "  - the intersection between the peaks and the TTS and remembering the nr list of gene ids" >&2
$OVERLAP mergedpeaks.gff exons_tts_sites_nr.gff -m 10 -nr -f tts -v | sort -k1,1 -k4,4n -k5,5n | awk 'BEGIN{OFS="\t"}{gsub(/\;/,"",$NF); gsub(/\"/,"",$NF); print $1, $4-1, $5, $NF}' > mergedpeaks_over_tts.bed
# 1	1912	2237	.
# 56364 (4 fields)

# g. Intersect the 1st file elements with the 1kb TTS windows of the 2nd file and remember the list of gene_id in an nr way
############################################################################################################################
echo "  - the intersection between the peaks and the TTS extended by 1 kb and remembering the nr list of gene ids" >&2
$OVERLAP mergedpeaks.gff exons_tts_sites_nr_ext1000.gff -m 10 -nr -f tts1000 -v | sort -k1,1 -k4,4n -k5,5n | awk 'BEGIN{OFS="\t"}{gsub(/\;/,"",$NF); gsub(/\"/,"",$NF); print $1, $4-1, $5, $NF}' > mergedpeaks_over_tts_ext1000.bed
# 1	1912	2237	.
# 56364 (4 fields)

# h. Intersect the 1st file elements with the 5kb TTS windows of the 2nd file and remember the list of gene_id in an nr way
############################################################################################################################
echo "  - the intersection between the peaks and the TTS extended by 5 kb and remembering the nr list of gene ids" >&2
$OVERLAP mergedpeaks.gff exons_tts_sites_nr_ext5000.gff -m 10 -nr -f tts5000 -v | sort -k1,1 -k4,4n -k5,5n | awk 'BEGIN{OFS="\t"}{gsub(/\;/,"",$NF); gsub(/\"/,"",$NF); print $1, $4-1, $5, $NF}' > mergedpeaks_over_tts_ext5000.bed
# 1	1912	2237	.
# 56364 (4 fields)
echo done >&2


#####################################################
# 3. Gather all the information in a single matrix  #
#####################################################
# - chromosome of the atac-seq peak
# - beg of the atac-seq peak (in bed coord)
# - end of the atac-seq peak (in bed coord)
# - list of genes with at least one exon overlapping the atac-seq peak (by at least 1 bp)
# - list of genes with at least one intron encompassing the atac-seq peak
# - list of genes with their most 5' bp overlapping the atac-seq peak
# - list of genes with the 1kb window around their most 5' bp overlapping the atac-seq peak
# - list of genes with the 5kb window around their most 5' bp overlapping the atac-seq peak
# - list of genes with their most 3' bp overlapping the atac-seq peak
# - list of genes with the 1kb window around their most 3' bp overlapping the atac-seq peak
# - list of genes with the 5kb window around their most 3' bp overlapping the atac-seq peak
# 1	161924	162248	.	1	161924	162248	ENSSSCG00000030218,	1	161924	162248	.	1	161924	162248	.	1	161924	162248	ENSSSCG00000030218,	1161924	162248	.	1	161924	162248	.	1	161924	162248	ENSSSCG00000030218,
echo "I am gathering all the intersection information in a single matrix for final output" >&2
paste mergedpeaks_over_exons.bed mergedpeaks_over_introns.tsv mergedpeaks_over_tss.bed mergedpeaks_over_tss_ext1000.bed mergedpeaks_over_tss_ext5000.bed mergedpeaks_over_tts.bed mergedpeaks_over_tts_ext1000.bed mergedpeaks_over_tts_ext5000.bed | awk -f $CLASSIF 
echo done >&2
# chr	beg	end	exon	intron	tss	tss1000	tss5000	tts	tts1000	tts5000
# ...
# 1	155874	156202	NA	NA	NA	NA	NA	NA	NA	ENSSSCG00000030218,  *** at tss5000 of a gene only (possible), looked at ucsc and ok
# 1	159261	159521	ENSSSCG00000030218,	NA	NA	NA	NA	NA	ENSSSCG00000030218,	ENSSSCG00000030218, *** exonic but also at the tts1000 and tts5000 but not at the tts, possible if far from the tts itself, looked at ucsc and ok
# 1	161924	162248	NA	ENSSSCG00000030218,	NA	NA	ENSSSCG00000030218,	NA	NA	ENSSSCG00000030218, *** intronic and at tss5000 and tts5000, possible, looked at ucsc and ok
# 1	164463	165057	ENSSSCG00000030218,	NA	NA	NA	ENSSSCG00000030218,	NA	NA	NA  *** exonic and tss5000, possible and looked at ucsc and ok
# 1	168067	168491	NA	NA	NA	NA	ENSSSCG00000030218,	NA	NA	NA  *** *** tss5000  checked ucsc ok
# 1	173226	173592	NA	NA	NA	NA	NA	NA	NA	NA
# 1	235658	235907	NA	ENSSSCG00000029697,	NA	NA	NA	NA	NA	NA
# 1	267912	269030	ENSSSCG00000029697,	NA	ENSSSCG00000029697,	ENSSSCG00000029697,	ENSSSCG00000029697,	NA	NA	NA
# 1	280058	280799	ENSSSCG00000027726,	NA	ENSSSCG00000027726,	ENSSSCG00000027726,	ENSSSCG00000027726,	NA	NA	NA
# 1	341647	342064	NA	NA	NA	NA	NA	NA	NA	NA
# 1	573072	573345	NA	NA	NA	NA	NA	NA	NA	NA
# 1	573722	574091	NA	NA	NA	NA	NA	NA	NA	NA
# 1	574401	575031	NA	NA	NA	NA	NA	NA	NA	NA
# 1	934619	935159	ENSSSCG00000030155,	NA	ENSSSCG00000030155,	ENSSSCG00000030155,	ENSSSCG00000030155,	NA	NA	ENSSSCG00000004009,
# 1	935231	935524	NA	ENSSSCG00000030155,	NA	ENSSSCG00000030155,	ENSSSCG00000030155,	NA	NA	ENSSSCG00000004009,
# X	127252267	127252660	ENSSSCG00000012699,	NA	ENSSSCG00000012699,	ENSSSCG00000012699,	ENSSSCG00000012699,	NA	NA	NA
# 56365 (11 fields) *** real	0m2.414s, some QCs were done and all were fine

							 
#############
# 4. Clean  #
#############
echo "I am cleaning" >&2
rm mergedpeaks.gff exons.gff introns.gff
rm exons_capped_sites.gff exons_capped_sites_nr.gff 
rm exons_tts_sites.gff exons_tts_sites_nr.gff
rm exons_capped_sites_nr_ext1000.gff exons_capped_sites_nr_ext5000.gff
rm exons_tts_sites_nr_ext1000.gff exons_tts_sites_nr_ext5000.gff
rm mergedpeaks_over_exons.bed mergedpeaks_over_introns.tsv
rm mergedpeaks_over_tss.bed mergedpeaks_over_tss_ext1000.bed mergedpeaks_over_tss_ext5000.bed
rm mergedpeaks_over_tts.bed mergedpeaks_over_tts_ext1000.bed mergedpeaks_over_tts_ext5000.bed
echo done >&2
