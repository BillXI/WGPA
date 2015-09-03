package WGPA::Utils::DB;
use DBI;
use POSIX qw(ceil);

# my $database = 'WGPA:';
my $host = 'localhost:';
my $port = '';
my $user = 'root';
my $password = 'root';

sub Connect {
    my $database = shift || return;
    my $dbh = DBI->connect("DBI:mysql:$database:$host:$port", $user, $password);
    return $dbh;
}

sub Disconnect {
    my $dbh = shift || return;
    $dbh->disconnect();
}

1;