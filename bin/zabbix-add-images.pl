#!/usr/bin/perl

use warnings;
use strict;

binmode( STDOUT, ':utf8' );
binmode( STDERR, ':utf8' );
use FindBin qw($Bin);
use File::Basename;

use lib "$Bin/ZabbixAPI";
use Data::Dumper;
use ZabbixAPI;
use Getopt::Long;
my $username = 'Admin';
my $password = 'zabbix';
my $api_url  = 'http://localhost/zabbix/api_jsonrpc.php';
my $filter   = ''; #use this filter to import only files that contain this sequence.
my $opt_help =0 ;
my $help = <<'END_PARAMS';

To import a single template:
    import-images.pl [options] template.xml

     Options:
       --api_url,--url     Zabbix API URL, default is http://localhost/zabbix/api_jsonrpc.php
       --username,-u       Zabbix API user, default is 'Admin'
       --password,-p       Zabbix API user's password, default is 'zabbix'

To import all images in the directory:
    import-images.pl [options] dir_with_images

     Options:
       --api_url,--url     Zabbix API URL, default is http://localhost/zabbix/api_jsonrpc.php
       --username,-u       Zabbix API user, default is 'Admin'
       --password,-p       Zabbix API user's password, default is 'zabbix'       
       --filter            Imports only files that contain filter specified in their filenames.
END_PARAMS
GetOptions(
    "api_url|url=s" => \$api_url,
    "password|p=s"  => \$password,
    "username|u=s"  => \$username,
    "filter|lang=s" => \$filter,
    "help|?"        => \$opt_help
) or die("$help\n");

if ($opt_help) {
    print "$help\n";
    exit 0;
}


my $zbx = ZabbixAPI->new( { api_url => $api_url, username => $username, password => $password } );

my $temp = $ARGV[0] or die "Please provide directory with images(png) as first ARG or to image file.\n $help\n";
if ( -d $temp ) {

    opendir my $dir, $temp or die "Cannot open directory: $temp\n";

    my @images = grep { /${filter}.*$/ && -f "$temp/$_" } readdir($dir);

    closedir $dir;
    die "No images found in directory $temp!\n" if @images == 0;

    $zbx->login();
    foreach my $file ( sort { $a cmp $b } (@images) ) {
        print "$temp/$file\n";
        $zbx->import_image_from_file("$temp/$file",basename("$temp/$file"));
		
    }
    $zbx->logout();

}
elsif ( -f $temp ) {
    $zbx->login();
    print $temp. "\n";
	$zbx->import_image_from_file($temp,basename($temp));
    $zbx->logout();
}
