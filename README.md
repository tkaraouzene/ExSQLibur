# ExSQLibur

Description: An SQLite and Perl based exome data analyser which will help you to find the Graal

Authors: Thomas Karaouzene

## Overview
ExSQLibur is a set of modul based on Perl & SQLite program that finds potential disease-causing variants from whole-exome sequencing data.

Starting from a reads file and a set of phenotypes it will align and call genotypes and return vcf files.
From these files it will annotate, filter and prioritise likely causative variants. The program does this based on user-defined criteria such as a variant's predicted pathogenicity, frequency of occurrence in a population and also how closely the given phenotype matches the known phenotype of diseased genes from human and model organism data.

## Workflow

### 1. Initialisation

```sh 
perl ExSQLibur NEW \
  --project_name [your_project_name] 
```

### 2. Add data

##### 1. firstly you have to add a new Exome project:

```sh 
perl ExSQLibur ADD \
  --add_exome [file containing exome project info]
```
your Exome file must be tab delimited and have these header line: 

```
platform	model	place	date	exome_capture	comment
Illumina	Hiseq2000	Somewhere	08/11/2013  Agilent SureSelect Human All exon v5  no comment
```
platform, model place and date fields are requiered

##### 2. secondly you have to add a new pathology:

```sh 
perl ExSQLibur ADD \
  --add_pathology [file containing pathology description]
```
your Pathology file must also be tab delimited and have these header line:

```
name	comment
heart_condition it hurts a lot
```
name field is requiered

##### 3. finaly you can add patients to your database

```sh 
perl ExSQLibur ADD \
  --add_patient [file containing patient info]
```
```
id	sex	reads_file1	reads_file2 pathology	seq_plateforme	seq_model	seq_place	seq_date  comment
ID:0001	M	ID_0001.1.fastq.gz	ID_0001.2.fastq.gz	heart_condition Illumina	Hiseq2000	Somewhere	08/11/2013 no comment
```
##### 4. Other way

These 3 steps can be performed in one single command 

 ```
 perl ExSQLibur ADD \
  --add_exome [file containing exome project info] \
  --add_exome [file containing pathology description] \
  --add_patient [file containing patient info] \
 ```

### 3. Data Alignment

The installation of MAGIC is requiered for this step

```
perl ExSQLibur ALIGN \
  --project_name  [your_project_name] \ 
  --raw_data [path/to/your/files.fastq] \
  --genome [path/to/your/genomeref/directory] \
  --magic_source [patho/to/your/magic/source/directory]
```


### 4. Genotype calling

```
perl ExSQLibur CALL \
  --project_name  [your_project_name] \ 
```
### 5. Variant annotation

```
perl ExSQLibur ANNOT \
  --project_name  [your_project_name] \ 
  --fork [Use forking to improve script runtime]
```

## Dependency 

MAGIC (ftp://ftp.ncbi.nlm.nih.gov/repository/acedb/Software/Magic/) and variant effect predictor (http://www.ensembl.org/info/docs/tools/vep/script/index.html) are nedeed

##### perl library:

use DBI;
use Getopt::Long;
use feature qw(say);
use File::Path qw(rmtree);
use Scalar::Util qw(openhandle);
use File::Basename;






