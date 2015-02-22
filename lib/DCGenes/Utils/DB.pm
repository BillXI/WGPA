package DCGenes::Utils::DB;
use DBI;
use POSIX qw(ceil);

# my $database = 'DCGenes:';
my $host = 'localhost:';
my $port = '';
my $user = 'root';
my $password = 'root';

sub Connect {
    my $database = shift || return;
    my $host = shift;
    my $port = shift;
    my $user = shift || return;
    my $password = shift;
    my $dbh = DBI->connect("DBI:mysql:$database:$host:$port", $user, $password);
    return $dbh;
}

sub Disconnect {
    my $dbh = shift || return;
    $dbh->disconnect();
}

sub ConnectTo {
    my $db = shift ||  return;

    return Connect('DCGenes', $host, $port, $user, $password) if ($db eq 'DCGenes');

    return Connect('STRING', $host, $port, $user, $password) if ($db eq 'STRING');
}

1;