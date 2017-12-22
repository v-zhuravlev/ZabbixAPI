# ZabbixAPI
Zabbix API perl module provided as is.

## Dependencies  
Perl modules required:  
```
LWP
JSON::XS
```
There are numerous ways to install them:  

| in Debian  | In Centos* | using CPAN | using cpanm|  
|------------|-----------|------------|------------|  
|  `apt-get install libwww-perl libjson-xs-perl` | `yum install perl-JSON-XS perl-libwww-perl perl-LWP-Protocol-https` | `PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'install Bundle::LWP'` and  `PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'install JSON::XS'` | `cpanm install LWP` and `cpanm install JSON::XS`|  

## Sample usage  
### Login / logout
```perl
$zbx = ZabbixAPI->new( { api_url => $url, username => $user, password => $password } );
$zbx->login();
## DO SOMETHING
$zbx->logout();
```

### Get params from raw JSON(copy and paste params from Zabbix API documentation examples):  
```perl
$json = <<'END_PARAMS';
{
        "output": ["host","name","hostid","status"],
        "selectInventory": "extend",
        "search": {"host":"myname"}
}
END_PARAMS

my $host_result = $zbx->do_raw('host.get',$json);
```
### Or prepare params using perl hash:  
```perl
my $json = {
             hostid => 10084,
             selectParentTemplates => 'extend'
            };

my $host_obj=$zbx->do('host.get',$json);
```
### Create mediatype
```perl
#setup email
$json = <<'END_PARAMS';
    {
        "description": "E-mail localhost only",
        "type": 0,
        "smtp_server": "localhost",
        "smtp_helo": "localhost",
        "smtp_email": "admin@localhost.localdomain"
    }
END_PARAMS


$params = JSON::XS->new->utf8->decode($json);
$result = $zbx->create_or_update_mediatype($params);
```


### Import Templates from XML files (with create,update,delete options all ticked)  
```perl
$zbx->import_configuration_from_file("$file");
```
### Import all Templates from XML files in specific directory:  
```perl
#!/usr/bin/perl
use warnings;
use strict;

use FindBin qw($Bin);
use lib "$Bin/ZabbixAPI";

use Data::Dumper;
use ZabbixAPI;
my $username = 'Admin';
my $password = 'zabbix';
my $api_url = 'http://localhost/zabbix/api_jsonrpc.php';

my $zbx;
my $params;
my $json;
my $result;
$zbx = ZabbixAPI->new( { api_url=>$api_url, username => $username, password => $password } );

$zbx->login();

my $temp_dir = $ARGV[0] or die "Please provide directory with templates as first ARG\n"; 

    opendir my $dir, $temp_dir  or die "Cannot open directory: $!";
    my @files = grep { /\.xml$/ && -f "$temp_dir/$_" } readdir($dir);
    closedir $dir;

    foreach my $file (@files) {
            print $file."\n";
            $zbx->import_configuration_from_file("$temp_dir/$file");
    }



$zbx->logout();
```


### Import all images from directory and make them icons (mass import of icons)  
see https://github.com/v-zhuravlev/ZabbixAPI/blob/master/bin/zabbix-add-images.pl sample script. Then run  
`perl zabbix-add-images.pl dir_with_png_icons`  
or  
`perl zabbix-add-images.pl png_icon_file`  
