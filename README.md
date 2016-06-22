# ExSQLibur

Description: An SQLite and Perl based exome data analyser which will help you to find the Graal

Authors: Thomas Karaouzene

### Overview
ExSQLibur is a set of modul based on Perl & SQLite program that finds potential disease-causing variants from whole-exome sequencing data.

Starting from a reads file and a set of phenotypes it will align and call genotypes and return vcf files.
From these files it will annotate, filter and prioritise likely causative variants. The program does this based on user-defined criteria such as a variant's predicted pathogenicity, frequency of occurrence in a population and also how closely the given phenotype matches the known phenotype of diseased genes from human and model organism data.
