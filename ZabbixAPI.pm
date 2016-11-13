package ZabbixAPI;
use Data::Dumper;
use LWP;
use JSON::XS;

sub new {
    my $class = shift;
    my $args  = shift;

    my $api_url = $args->{api_url}
      || 'http://localhost/zabbix/api_jsonrpc.php';
    my $username = $args->{username} || 'Admin';
    my $password = $args->{password} || 'zabbix';

    my $self = bless {
        api_url  => $api_url,
        username => $username,
        password => $password,
        ua       => LWP::UserAgent->new(),
        auth     => undef,
        id       => 1,
    }, $class;

    $self->{req} = HTTP::Request->new( POST => $self->{api_url} );
    $self->{req}->content_type('application/json-rpc');

    return $self;
}
sub id {
    my $self = shift;
    return $self->{id}++;
}
sub do {

    my $self   = shift;
    my $method = shift;
    my $params = shift;

    my $json = JSON::XS->new->utf8->encode(
        {
            jsonrpc => '2.0',
            method  => $method,
            params  => $params,
            id      => $self->id,
            auth    => $self->{auth},
        }
    );



    $self->{req}->content($json);

    # Pass request to the user agent and get a response back
    my $res = $self->{ua}->request( $self->{req} );

    # Check the outcome of the response
    if ( $res->is_success ) {
        
        my $return = JSON::XS->new->utf8->decode( $res->content );
        die $return->{error}->{data}."\n" if $return->{error};
        return $return->{result};
    }
    else {
        print $res->status_line, "\n";
    }

}

sub do_raw {

    my $self   = shift;
    my $method = shift;
    my $params = shift;

    my $json = JSON::XS->new->utf8->encode(
        {
            jsonrpc => '2.0',
            method  => $method,
            params  => JSON::XS->new->utf8->decode($params),
            id      => $self->id,
            auth    => $self->{auth},
        }
    );


    $self->{req}->content($json);

    # Pass request to the user agent and get a response back
    my $res = $self->{ua}->request( $self->{req} );

    # Check the outcome of the response
    if ( $res->is_success ) {
        my $return = JSON::XS->new->utf8->decode( $res->content );
        die $return->{error}->{data}."\n" if $return->{error};
        return $return->{result};
    }
    else {
        print $res->status_line, "\n";
    }


}

sub import_configuration_from_file {
    my $self = shift;
    my $file = shift;
    my $configuration;
    {
      local $/ = undef;
      open(my $fh,'<:encoding(UTF-8)', $file) or die "Error opening $file: $!";

      $configuration = <$fh>;
      close $fh;
    }

    my $json = <<'END_PARAMS';
{
    "format": "xml",
    "rules": {
        "groups": {
            "createMissing": true
        },
        "hosts": {
            "createMissing": true,
            "updateExisting": true
        },
        "templates": {
            "createMissing": true,
            "updateExisting": true
        },            
        "templateLinkage": {
            "createMissing": true
        },                    
        "templateScreens": {
            "createMissing": true,
            "updateExisting": true,
            "deleteMissing": true
        },   
        "applications": {
            "createMissing": true,
            "deleteMissing": true
        },    
        "discoveryRules": {
            "createMissing": true,
            "updateExisting": true,
            "deleteMissing": true
        },            
        "items": {
            "createMissing": true,
            "updateExisting": true,
            "deleteMissing": true
        },
        "triggers": {
            "createMissing": true,
            "updateExisting": true,
            "deleteMissing": true
        },
        "graphs": {
            "createMissing": true,
            "updateExisting": true,
            "deleteMissing": true
        },
        "screens": {
            "createMissing": true,
            "updateExisting": true
        },
        "maps": {
            "createMissing": true,
            "updateExisting": true
        },
        "images": {
            "createMissing": true,
            "updateExisting": true
        },
        "valueMaps": {
            "createMissing": true,
            "updateExisting": true
        }

    },
    "source": ""
}
END_PARAMS
    my $params = JSON::XS->new->utf8->decode($json);
    $params->{source}=$configuration;
    $self->do('configuration.import', $params);



}

sub login {
    my $self = shift;
    my $params = {
                user     => $self->{username},
                password => $self->{password}
            };
    my $content = $self->do("user.login",$params);
    $self->{auth}=$content;
    
}

sub logout {
    my $self = shift;
    $self->do( 'user.logout', {} );
}


sub create_or_update_mediatype {

    my $self = shift;
    my $params = shift;
    my $result;
    eval {    #try to create JSON
         $result =  $self->do('mediatype.create', $params);
    };
    if ($@) {
        if($@ =~ /already exists/) {
            warn "WARN: $params->{description} already exists. Updating instead..."."\n";
            #get mediatypeid
            $json = { output => ['mediatypeid'], filter =>{description=>[$params->{description}]}};
            my $id = $self->do('mediatype.get',$json);
            $params->{mediatypeid}= $id->[0]->{mediatypeid};
            #update instead of creating....
            $result =  $self->do('mediatype.update', $params);
            return $result;
        }
        else {
        
            die $@;
        
        }
    }
    else {
        
        return $result;
    
    }
}
    
    
sub create_or_update_user {

    my $self = shift;
    my $params = shift;
    my $result;
    eval {    #try to create JSON
        $result =  $self->do('user.create', $params);
    };
    if ($@) {
        if($@ =~ /already exists/) {
            warn "WARN: $params->{alias} already exists. Updating instead..."."\n";
            #get mediatypeid
            $json = { output => ['userid'], filter =>{alias=>[$params->{alias}]}};
            my $id = $self->do('user.get',$json);

            $params->{userid}= $id->[0]->{userid};
            #update instead of creating....
            my $medias = $params->{user_medias}->[0];

            delete $params->{user_medias}; # remove user_medias, not possible in 'user.update' call
            $result =  $self->do('user.update', $params);

            my $result_media = $self->do('user.updatemedia',{users => [ {userid=>$params->{userid}} ],
                                                                         medias => $medias
                                                                            });
                                                                            
            return $result;
        }
        else {
        
            die $@;
        
        }
    }
    else {
        
        return $result;
    
    }        


}

sub create_or_update_action {

    my $self = shift;
    my $params = shift;
    my $result;
    eval {    #try to create JSON
        $result =  $self->do('action.create', $params);
    };
    if ($@) {
        if($@ =~ /already exists/) {
            warn "WARN: $params->{name} already exists. Updating instead..."."\n";
            #get mediatypeid
            $json = { output => ['actionid'], filter =>{name=>[$params->{name}]}};
            my $id = $self->do('action.get',$json);
            $params->{actionid}= $id->[0]->{actionid};
            #update instead of creating....
            delete $params->{eventsource}; #cannot be update, must be removed
            $result =  $self->do('action.update', $params);
            return $result;
        }
        else {
        
            die $@;
        
        }
    }
    else {
        
        return $result;
    
    }        

}


sub create_or_update_drule {

    my $self = shift;
    my $params = shift;
    my $result;
    eval {    #try to create JSON
        $result =  $self->do('drule.create', $params);
    };
    if ($@) {
        if($@ =~ /already exists/) {
            warn "WARN: $params->{name} already exists. Updating instead..."."\n";
            $json = { output => ['druleid'], filter =>{name=>[$params->{name}]}};
            my $id = $self->do('drule.get',$json);
            $params->{druleid}= $id->[0]->{druleid};
            #update instead of creating....
            $result =  $self->do('drule.update', $params);
            return $result;
        }
        else {
        
            die $@;
        
        }
    }
    else {
        
        return $result;
    
    }        

}


sub get_template_id {
    
    my $self = shift;
    my $template_name = shift;
    
    my $json = { output => ['host','templateid'], filter =>{host=>[$template_name]}};
    my $result = $self->do('template.get',$json);
    return $result->[0]->{templateid};
   
}

sub get_hostgroup_id {
    
    my $self = shift;
    my $hgroup_name = shift;
    
    my $json = { output => ['groupid'], filter =>{name=>[$hgroup_name]}};
    my $result = $self->do('hostgroup.get',$json);
    return $result->[0]->{groupid};
   
}


sub get_host_id {

    my $self = shift;
    my $host_name = shift;
    
    my $json = { output => ['hostid'], filter =>{host=>[$host_name]}};
    my $result = $self->do('host.get',$json);
    return $result->[0]->{hostid};

}

sub get_host_by_name {

    my $self = shift;
    my $host_name = shift;
    
    my $json = { 
        output => ['hostid'],
        filter =>{host=>[$host_name]},
        selectGroups => ['groupid','name'],
        selectParentTemplates => ['templateid','name'],
        selectMacros => ['macro','value']
    };
    my $result = $self->do('host.get',$json);
    return $result->[0];

}



sub create_or_merge_host {

    my $self = shift;
    my $host_name = shift;
    my $params = shift;
    my $result;
    
    my $hostid  =  $self->get_host_id($host_name);

    if ($hostid) {
        print "WARN: Cannot create host $host_name ... going to merge instead\n";
        #print $hostid."\n";
        #update (merge mode currently)
        $params->{hostid}=$hostid;
       
       my $host = $self->get_host_by_name($host_name);
       if ($params->{templates}) {
            #merge with already existed
            my @templates;
            foreach my $template (@{$params->{templates}}){
                push @templates,$template->{templateid};
            }
            foreach my $template (@{$host->{parentTemplates}}){
                push @templates,$template->{templateid};
            }
            my %seen = (); # see http://perldoc.perl.org/perlfaq4.html#How-can-I-remove-duplicate-elements-from-a-list-or-array%3f
            
            @templates = grep { ! $seen{ $_ }++ } @templates;
            
            my $i=0;
            delete $params->{templates};
            foreach my $templateid (@templates) {
                $params->{templates}->[$i]->{templateid} = $templateid;
                $i++;
            }
            
       }
       
       if ($params->{groups}) {
            #merge with already existed
            my @groups;
            foreach my $group (@{$params->{groups}}){
                push @groups,$group->{groupid};
            }
            foreach my $group (@{$host->{groups}}){
                push @groups,$group->{groupid};
            }
            my %seen = (); # see http://perldoc.perl.org/perlfaq4.html#How-can-I-remove-duplicate-elements-from-a-list-or-array%3f
            
            @groups = grep { ! $seen{ $_ }++ } @groups;
            
            my $i=0;
            delete $params->{groups};
            foreach my $groupid (@groups) {
                $params->{groups}->[$i]->{groupid} = $groupid;
                $i++;
            }
            
       }
        
        if ($params->{macros}) {
            #merge with already existed
            my @macros;
            foreach my $macro (@{$params->{macros}}){
                push @macros,
                    {
                     macro => $macro->{macro},
                     value => $macro->{value}
                    };
            }
            foreach my $macro (@{$host->{macros}}){
                push @macros,
                    {
                     macro => $macro->{macro},
                     value => $macro->{value}
                    };
            }
            my %seen = (); # see http://perldoc.perl.org/perlfaq4.html#How-can-I-remove-duplicate-elements-from-a-list-or-array%3f
            @macros = grep { ! $seen{ $_->{macro} }++ } @macros;
            
            my $i=0;
            delete $params->{macros};
            
            foreach my $macro (@macros) {
                $params->{macros}->[$i] = $macro;
                $i++;
            }
            
        }
        
        if ($params->{interfaces}) {
            #merge with already existed
            #warn "WARN: host interfaces merge is not supported yet... skipping interfaces part\n";
            delete $params->{interfaces};
        }
        
        #print Dumper $params;
          $result =  $self->do('host.update', $params);

    } 
    else {
        #create
        $params->{host}=$host_name;
        #print Dumper $params;
        $result =  $self->do('host.create', $params);

    }
    
    return $result;
    
    
}

1;
