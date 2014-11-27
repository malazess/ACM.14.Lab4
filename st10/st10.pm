package ST10;

use strict;

use LWP::UserAgent;
use URI::Escape;

use constant EXIT_FLAG => 'exit';

my $API_STUDENT_ID = 2;
my $API_URL = 'http://localhost:8080/cgi/Lab3/lab3.cgi';
my %API_PARAMS = (
    'student' => $API_STUDENT_ID,
    'action' => 'export',
    'API_KEY' => '0add42399f47c5125b45b292b8efb2b4',
);

my @ACTIONS = 
(
	\&add,
	\&edit,
	\&remove,
	\&list,
	\&save,
	\&load,
	\&export,
	\&exit
);

my @NAMES = 
(
	"Add object",
	"Edit object",
	"Remove object",
	"List of objects",
	"Save to file",
	"Load from file",
	"Export to server",
	"Exit",
);

my %objects;

my %attributes = (
    'name' => 'First Name',
    'lastname' => 'Last Name',
    'age' => 'Age'
);
my @attributesSort = (
    'name',
    'lastname',
    'age',
);

sub fill
{
    $objects{0} = {'name' => 'Petr', 'lastname' => 'Kuklianov', 'age' => 25};
    $objects{1} = {'name' => 'Den', 'lastname' => 'Davidoff', 'age' => 25};
    $objects{2} = {'name' => 'Ilya', 'lastname' => 'Pastukhov', 'age' => 22};
}

sub add
{
    my @ids = get_ids();
    my $id = 0;
    
    if(scalar @ids != 0) {
        $id = $ids[scalar @ids - 1]; # scalar @ids возвращает длину массива
        $id++;
    }
    
    my %obj;
    $objects{$id} = {};
    foreach my $key (values @attributesSort) {
        print $attributes{$key} . ": ";
        my $value = <STDIN>;
        $value = trim($value);
        $objects{$id}->{$key} = $value;
    }
    
    print "Object is added.\n";
}

sub edit
{
    print "Enter ID: ";
    my $id = <STDIN>;
    $id--;
    if(!exists($objects{$id})) {
        print "Object not exists\n";
        return;
    }
    
    foreach my $key (values @attributesSort) {
        my $oldValue = $objects{$id}->{$key};
        print $attributes{$key} . " [$oldValue]: ";
        my $value = <STDIN>;
        $value = trim($value);
        if(length $value == 0) {
            $value = $oldValue;
        }
        $objects{$id}->{$key} = $value;
    }
    
    print "Object is changed.\n";
}

sub remove
{
    print "Enter ID: ";
    my $id = <STDIN>;
    $id--;
    if(!exists($objects{$id})) {
        print "Object not exists\n";
        return;
    }
    
    delete $objects{$id};
    
    print "Removed.\n";
}

sub list
{
    my @ids = get_ids();
    
    if(scalar @ids > 0) {
        print "\n--------------------------------------------------\n";
    }

    foreach my $id (values @ids) {
        my $obj = $objects{$id};
        print "ID: ";
        printf("%-46s|\n", $id + 1);
        
        foreach my $key (values @attributesSort) {
            printf "%-20s", $attributes{$key} . ':';
            printf "%-30s|", $obj->{$key};
            print "\n";
        }
        print "--------------------------------------------------\n";
    }
}

sub save
{
    my $defaultFile = 'data';
    print "Enter DB name [$defaultFile]: ";
    my $fileName = <STDIN>;
    $fileName = trim($fileName);
    if(length $fileName == 0) {
        $fileName = $defaultFile;
    }
    $fileName = 'st10/data/' . $fileName;
    
    if(-e $fileName . '.dir') {
        unlink($fileName . '.dir');
    }
    if(-e $fileName . '.pag') {
        unlink($fileName . '.pag');
    }

    my %hash;
    dbmopen(%hash, $fileName, 0666);
    
    my $template = '';
    foreach my $key (keys %attributes) {
        $template .= 'u i ';
    }
    foreach my $key (keys %objects) {
        my $code = 'pack("' . $template . '"';
        foreach my $attr (sort keys %attributes) {
            my $c = '$objects{$key}->{' . $attr . '}, 1';
            $code .= ', ' . $c;
        }
        $code .= ');';
        
        my $packed;
        eval '$packed = ' . $code;
        
        $hash{$key} = $packed;
    }
    
    dbmclose(%hash);
    
    print "Saved.\n";
}

sub load
{
    my $defaultFile = 'data';
    print "Enter DB name [$defaultFile]: ";
    my $fileName = <STDIN>;
    $fileName = trim($fileName);
    if(length $fileName == 0) {
        $fileName = $defaultFile;
    }
    $fileName = 'st10/data/' . $fileName;
    
    %objects = ();
    
    my %hash;
    dbmopen(%hash, $fileName, 0666);
    
    my $template = '';
    foreach my $key (keys %attributes) {
        $template .= 'u i ';
    }
    my @attr_keys = sort keys %attributes;
    foreach my $key (keys %hash) {
        my @d = unpack($template, $hash{$key});
        $objects{$key} = {};
        my $i = 0;
        foreach my $k (keys @d) {
            if(($k % 2) != 0) {
                next;
            }
            $objects{$key}->{$attr_keys[$i]} = $d[$k];
            $i++;
        }
    }
    
    dbmclose(%hash);
    
    print "Loaded.\n";
}

sub export
{
    my @ids = get_ids();
    
    if(scalar @ids == 0) {
        print "No objects\n";
        return;
    }

    foreach my $id (values @ids) {
        my $obj = $objects{$id};
        print "Export Object: $id...";
        
        my $ua = LWP::UserAgent->new;
        $ua->agent("Cartoteka_Lab/4.0 ");
        
        my $req = HTTP::Request->new(POST => $API_URL);
        $req->content_type('application/x-www-form-urlencoded');
        
        my @vars;
        foreach my $key (keys %API_PARAMS) {
            my $str = ($key . '=' . uri_escape($API_PARAMS{$key}));
            push @vars, $str;
        }
        foreach my $key (values @attributesSort) {
            my $str = 'field_' . $key . '=' . uri_escape($obj->{$key});
            push @vars, $str;
        }
        $req->content(join('&', @vars));
        my $res = $ua->request($req);

        if($res->is_success) {
            print $res->decoded_content . "\n";
        } else {
            print "Error: " . $res->status_line . "\n";
        }
    }
}

sub get_ids
{
    my @ids;
    foreach my $id (keys %objects) {
        push @ids, $id;
    }
    @ids = sort {$a<=>$b} @ids;
    
    return @ids;
}

sub trim 
{
    my $s = shift; $s =~ s/\s+$//g; 
    return $s;
}

sub exit
{
    return EXIT_FLAG;
}

sub menu
{
	my $i = 0;
	print "\n------------------------------\n";
	print "Menu:\n";
	foreach my $s(@NAMES)
	{
		$i++;
		print "$i. $s\n";
	}
	print "------------------------------\n";
	print "Enter your number:\n";
	my $ch = <STDIN>;
	return ($ch-1);
}

sub st10
{
    while(1) {
        my $ch = menu();
	    if(defined $ACTIONS[$ch]) {
		    print $NAMES[$ch]." launching...\n\n";
		    my $return = $ACTIONS[$ch]->();
		    if($return eq EXIT_FLAG) {
		        return;
		    }
	    } else {
		    return;
	    }
    }
}

return 1;
