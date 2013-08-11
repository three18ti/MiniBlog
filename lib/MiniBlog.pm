package MiniBlog;
use DBI;
use Dancer;
use Template;
use File::Spec;
use File::Slurp;

our $VERSION = '0.1';

my $flash;

sub connect_db {
    return DBI->connect("dbi:SQLite:dbname=". setting 'database' )
        or die $DBI::errstr;
}

sub init_db {
    my $dbh = connect_db;
    my $schema = read_file( setting 'schema_file' );
    $dbh->do($schema) or die $dbh->errstr;
}

sub set_flash {
    $flash = shift;
}

sub get_flash {
    my $msg = $flash;
    $flash = "";
    return $msg;
}

before_template sub {
    my $tokens = shift;

    $tokens->{'home_url'}   = uri_for '/';    
    $tokens->{'css_url'}    = request->base . 'css/style.css';
    $tokens->{'login_url'}  = uri_for '/login';
    $tokens->{'logout_url'} = uri_for '/logout';
};

get '/' => sub {
    my $dbh  = connect_db();
    my $sql = 'SELECT id, title, text FROM ENTRIES ORDER BY ID DESC';
    my $sth = $dbh->prepare($sql) or die $dbh->error;
    $sth->execute or die $sth->errstr;
    template 'show_entires.tt', {
        'msg'             => get_flash,
        'add_entry_url'   => uri_for('/add'),
        'entries'         => $sth->fetchall_hashref('id'),
    };
};

post '/add' => sub {
    send_error "Not Logged in", 401 unless session('logged_in');

    my $dbh = connect_db;
    my $sql = 'INSERT INTO entries (title, text) VALUES (?, ?)';
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute( params->{'title'}, params->{text} ) or die $sth->errstr;

    set_flash('New entry posted!');
    redirect '/';
};

get '/view/:post_id' => sub {
    
    my $dbh = connect_db;
    my $sql = 'SELECT id, title, text FROM ENTRIES WHERE id = ?';
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute( params->{'post_id'} ) or die $sth->errstr;

    template 'view_entry.tt' => {
        'entry'   => $sth->fetchall_hashref('id')
    };
};

any ['get', 'post'] => '/login' => sub {
    my $err;
    
    if ( request->method eq 'POST' ) {
        if ( params->{'username'} ne setting('username') 
            || params->{'password'} ne setting('password') ) {
           $err = "Invalid username or password";
        }
        else {
            session 'logged_in' => true;
            set_flash('You are logged in.');
            redirect '/';
        }
    }

    template 'login.tt' => {
        err => $err,
    };
};

get '/logout' => sub {
    session->destroy;
    set_flash 'You are logged out.';
    redirect '/';
};

init_db;

true;
