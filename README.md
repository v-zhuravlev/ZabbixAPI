# ZabbixAPI
Zabbix API perl module provided as is.


## Sample usage  
### Login / logout
```
$zbx = ZabbixAPI->new( { api_url => $url, username => $user, password => $password } );
$zbx->login();
## DO SOMETHING
$zbx->logout();
```

### Get params from raw JSON(copy and paste params from Zabbix API documentation examples):  
```
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
```
my $json = {
             hostid => 10084,
             selectParentTemplates => 'extend'
            };

my $host_obj=$zbx->do('host.get',$json);
```
### Create mediatype
```
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
```
$zbx->import_configuration_from_file("$file");
```
