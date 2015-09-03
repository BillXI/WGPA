package WGPA::Utils::Paths;

our $rootFolder = '/var/www/apps/WGPA';

our $dataFolder = "$rootFolder/data";
mkdir $dataFolder unless -e $dataFolder;

my $gseaFolder = "$dataFolder/GSEA";

our %GSEA = (
	MAIN_FOLDER => $gseaFolder,
	RANKINGS_FOLDER => "$gseaFolder/Rankings",
	INPUT_FOLDER => "$gseaFolder/Inputs",
	RESULTS_FOLDER => "$gseaFolder/Results"
);
mkdir $GSEA{MAIN_FOLDER} unless -e $GSEA{MAIN_FOLDER};
mkdir $GSEA{RANKINGS_FOLDER} unless -e $GSEA{RANKINGS_FOLDER};
mkdir $GSEA{INPUT_FOLDER} unless -e $GSEA{INPUT_FOLDER};
mkdir $GSEA{RESULTS_FOLDER} unless -e $GSEA{RESULTS_FOLDER};

our $fathmmFolder = "$dataFolder/fathmm";
mkdir $fathmmFolder unless -e $fathmmFolder;

our $polyphenFolder = "$dataFolder/polyphen";
mkdir $polyphenFolder unless -e $polyphenFolder;

our $tmpFolder = '/var/tmp/wgpa';
mkdir $tmpFolder unless -e $tmpFolder;


1;