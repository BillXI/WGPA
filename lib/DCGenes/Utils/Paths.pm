package DCGenes::Utils::Paths;

our $RootFolder = '/var/www/apps/DCGenes';

my $gseaFolder = $RootFolder.'/lib/GSEA';

our %GSEA = (
	MAIN_FOLDER => $gseaFolder,
	DATA_FOLDER => "$gseaFolder/Data",
	INPUT_FOLDER => "$gseaFolder/Inputs",
	RESULTS_FOLDER => "$gseaFolder/Results"
);

our $Substitutions = '/tmp/dcgenes';

1;