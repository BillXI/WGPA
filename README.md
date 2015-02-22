# Disease-Causing Genes Website

DC Genes combine the most recent scores developed to asses the intolerance of a gene to mutations (RVIS, EvoTol, Gene Constraints, ...) whith a set of widely used analysis (GSEA, fatmhh, gene networks, ...) in order to distinguish the genes containing disease-relevant mutations from genes containing irrelevant mutations..

The website is completely developed using [Mojolicious](http://mojolicio.us/) so you can check their site for more information.

## Getting started

### Necessary adjustments

It's necessary to change the variable $RootFolder in `lib/DCGenes/Utils/Paths.pm` to the path of the folder where you are deploying the website to.

Also it's necesary to update the database credentials on 3 files:

 * `lib/DCGenes/DB.pm`
 * `lib/fatmhh/fathmm.py` (line 237)
 * `lib/GSEA/config.properties`

### Running the website
To learn more about mojolicious I would recomend going to their website but just to get started mojolicious has two built in server.

Morbo is singlethereaded and good to get started and test locally. It will serve the website on port 3000.

```bash
  morbo script/dcgenes
```

Hypnotoad is pre-forked and starts the processes independent of the terminal and is more suitable for production. It will serve the website on port 3000.

```bash
  hypnotoad script/dcgenes
```

hypnotoad accept the followign flags:

 * Stop gracefully the server: -s / --stop 
 * Run hypnotoad dependent to the terminal: -f / --foreground
 
## Running the GSEA runner

Due to the performance issues that will produce to run the GSEA analysis on real time, the website just queue them  and there is a java process that run on the background and process all the analysis.

### Building the GSEA Runner

The GSEA Runner has two dependencies that need to be added to the project: the GSEA jar file and the JDBC jar file. In our production website I use slightly modified version of the GSEA  file but the normal distribution available at their website works to. Both jars should be place on `lib/GSEA/libs`.

DC Genes includes a script to build a production ready version of the website:

```bash
  script/build.sh
```

It will create a folder `dist` that will contain your website excluding the tests and other unnecesary files and including the compiled GSEA runner. It's necessary to  have  java sdk installed so the script can work.

If the script is not executable you can use chmod u+x script/build.sh and re-try.

### Managing the GSEA runner

For convenience there is a script to manage the GSEA Runner porcess

```bash
  script/gsearunner.sh -start
  
  script/gsearunner.sh -stop
  
  script/gsearunner.sh -restart
```

If the script is not executable you can use chmod u+x script/gsearunner.sh and re-try.

## Third party components

 * [Gene Set Enrichment Analysis (GSEA)](http://www.broadinstitute.org/gsea)
 * [Functional Analysis through Hidden Markov Models (fathmm)](http://fathmm.biocompute.org.uk/)

## Databases

 * DCGenes (available if requested)
 * fathmm (Available on [fathmm GitHub](https://github.com/HAShihab/fathmm))
 * STRING (Available on [STRIGN web](http://string-db.org/)) (Actually we don't use the STRING database but a table extracted from it that's contained in the DCGenes Database)