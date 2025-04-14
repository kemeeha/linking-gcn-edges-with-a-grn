#!/bin/bash

# STEP A: Download GRN file
echo "Downloading GRN file..."
wget https://www.cell.com/cms/10.1016/j.celrep.2017.10.001/attachment/e7309c03-e579-4119-a95e-376ab2066cbb/mmc2.csv

# Filter for tissue of interest (e.g., Uterus)
echo "Filtering for tissue-specific GRN..."
(head -n 1 mmc2.csv; grep 'Uterus' mmc2.csv) > grn.csv

# STEP B2: Prepare files for database loading
echo "Converting GRN to tab-delimited format..."
cat mmc2.csv | sed 's/\"//g' | sed 's/,/\t/4;s/,/\t/3;s/,/\t/1;s/,/\t/1' > grn.tab

echo "NOTE: You need to manually prepare your GCN tab-delimited file and download mart_export.txt from Ensembl BioMart"

# STEP B4-B6: Create and populate SQLite database
echo "Creating SQLite database and importing data..."
sqlite3 mapping << EOF
.separator "\t"
.import grn.tab grn
.separator "\t"
.import gcn.tab gcn
.mode csv
.import mart_export.txt names

.schema grn
.schema gcn
.schema names

.separator "\t"
.headers on
.output GRN-REMAPPED.tsv
SELECT TF, names."Gene Name", Tissues, TargetGene
FROM grn
INNER JOIN names on names."Gene stable ID"=grn.TargetGene
WHERE Tissues LIKE '%Uterus%';

.exit
EOF

# STEP C: Make merged GRN and GCN edge lists
echo "Creating edge lists..."
cat GRN-REMAPPED.tsv | awk '{print $1,$2}' > temp
awk '{print "GRN " $0}' temp > temp2
sed '1s/GRN/NetworkType/g' temp2 > temp3
sed '1s/"Gene/GeneTarget/g' temp3 > GRN_edges.tab
rm temp temp2 temp3

cat gcn.tab | awk '{print $1,$2}' > temp
awk '{print "GCN " $0}' temp > temp2
sed '1s/GCN/NetworkType/g' temp2 > GCN_edges.tab
rm temp temp2

# Concatenate the files
(tail -n +2 GRN_edges.tab; tail -n +2 GRN_edges.tab; tail -n +2 GCN_edges.tab) > merged.gcn.grn.tab

# Remove duplicate lines (edges)
cat merged.gcn.grn.tab | uniq | sed 's/\s/\t/g' > unique.merged.gcn.grn.tab

echo "Process completed! Final output: unique.merged.gcn.grn.tab"
echo "Transfer this file to your local computer and visualize it in Cytoscape.
