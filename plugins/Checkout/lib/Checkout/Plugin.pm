package Checkout::Plugin;
use strict;
use warnings;
use utf8;

sub _cb_ts_edit_entry {
    my ( $cb, $app, $tmpl ) = @_;
    my $checkout_msg = <<'MTML';
<__trans_section component="Checkout">
    <mt:if name="checkedout_by_user">
        <mtapp:statusmsg
            id="checkout"
            class="success">
            <__trans phrase="It is checked-out at [_1]." params="<$MTDate ts='$checkedout_on_ts' relative='1' format='%b %e %Y'$>" />
            <mt:Unless name="reedit">
                <a href="<$mt:var name='script_url'$>?id=<$mtvar name='id' escape='html'$>&blog_id=<$mtvar name='blog_id'$>&__mode=uncheckout&_type=<$mt:var name='object_type'$>&magic_token=<$mt:var name='magic_token'$>"><__trans phrase="Undo" /></a>
            </mt:Unless>
        </mtapp:statusmsg>
    </mt:if>
    <mt:if name="checkedout_by_others">
        <mtapp:statusmsg
            id="checkout"
            class="error">
            <__trans phrase="By [_2], this was checked out at [_1]." params="<$MTDate ts='$checkedout_on_ts' relative='1' format='%b %e %Y'$>%%<$mt:var name='checkedout_author_nickname' escape='html'$>(<a href="mailto:<$mt:var name='checkedout_author_email' escape='html'$>"><$mt:var name='checkedout_author_email' escape='html'$></a>)" />
            <mt:Unless name="reedit">
                <a href="<$mt:var name='script_url'$>?id=<$mtvar name='id' escape='html'$>&blog_id=<$mtvar name='blog_id'$>&__mode=force_checkout&_type=<$mt:var name='object_type'$>&magic_token=<$mt:var name='magic_token'$>"
                   onclick="return confirm('<__trans phrase="That you want to override the check out, there is a risk of losing the other user's changes." escape="js">');"><__trans phrase="Override" /></a>
            </mt:Unless>
        </mtapp:statusmsg>
    </mt:if>
    <mt:if name="not_checkedout_yet">
        <mt:if name="saved_changes">
            <mtapp:statusmsg
                id="checkout"
                class="success">
                <__trans phrase="Checked-in now." />
                <mt:Unless name="reedit">
                    <a href="<$mt:var name='script_url'$>?id=<$mtvar name='id' escape='html'$>&blog_id=<$mtvar name='blog_id'$>&__mode=checkout&_type=<$mt:var name='object_type'$>&magic_token=<$mt:var name='magic_token'$>"><__trans phrase="Checkout" /></a>
                </mt:Unless>
            </mtapp:statusmsg>
        <mt:else>
            <mtapp:statusmsg
                id="checkout"
                class="info">
                <__trans phrase="It is not checked-out yet." />
                <mt:Unless name="reedit">
                    <a href="<$mt:var name='script_url'$>?id=<$mtvar name='id' escape='html'$>&blog_id=<$mtvar name='blog_id'$>&__mode=checkout&_type=<$mt:var name='object_type'$>&magic_token=<$mt:var name='magic_token'$>"><__trans phrase="Checkout" /></a>
                </mt:Unless>
            </mtapp:statusmsg>
        </mt:if>
    </mt:if>
</__trans_section>
MTML
    $$tmpl =~ s/(<mt:if name="saved_added">)/$checkout_msg$1/g;
    
    my $checkin = <<'MTML';
<__trans_section component="Checkout">
    <mt:if name="checkedout_by_user">
        <ul>
            <li><input type="checkbox" name="checkin" id="checkin" value="1"<mt:if name="checkin"> checked="checked"</mt:if> class="cb" /> <label for="checkin"><__trans phrase="Checkin"></label></li>
        <ul>
    </mt:If>
</__trans_section>
MTML
    $$tmpl =~ s/(<div class="actions-bar">)/$checkin$1/;
    
    
    $$tmpl =~ s/name="__mode" value="save_entry"/name="__mode" value="save_entry_with_checkout"/;
}

sub _cb_tp_edit_entry {
    my ( $cb, $app, $param, $tmpl ) = @_;
    my $id      = $app->param( 'id' );
    my $type    = $app->param( '_type' ) || 'entry';
    return 1 unless $id;
    my $entry = MT->model( $type )->load( $id );
    return 1 unless $entry;

    my $plugin = MT->component( 'Checkout' );
    
    my $checkout = MT->model( 'checkout' )->fetch_by_object( $entry );
    if ( $checkout ) {
        if ($checkout->author_id == $app->user->id ) {
            $param->{ checkedout_by_user } = 1;
            $param->{ checkedout_on_ts } = $checkout->created_on;
        } else {
            $param->{ checkedout_by_others } = 1;
            $param->{ checkedout_on_ts } = $checkout->created_on;
            $param->{ checkedout_author_nickname } = $checkout->author_nickname;
            $param->{ checkedout_author_email } = $checkout->author_email;
        }
    } else {
        $param->{ not_checkedout_yet } = 1;
    }
    $param->{ checkin } = $app->param( 'checkin' );
    1;
}

sub _cb_tp_preview_strip {
    my ( $cb, $app, $param, $tmpl ) = @_;
    my $input = {
        'data_name' => 'checkin',
        'data_value' => $app->param( 'checkin' ),
    };
    push( @{ $param->{ 'entry_loop' } }, $input );
}

sub _save_entry_with_checkout {
    my $app = shift;
    my $id      = $app->param( 'id' );
    my $type    = $app->param( '_type' ) || 'entry';
    my $entry = $id ? MT->model( $type )->load( $id ) : undef;
    if ( $entry ) {
        if ( checkedout_by_user( $entry ) ) {
            $app->forward( 'save_entry' );
        } else {
            if ( checkedout_by_others( $entry ) ) {
                $app->forward( 'when_checkedout_by_others' );
            } else {
                $app->forward( 'when_not_checkedout_yet' );
            }
        }
    } else {
        $app->param( 'checkout', 1 );
        $app->forward( 'save_entry' );
    }
}

sub _cb_cms_pre_save_object {
    my ( $cb, $app, $object, $org_object ) = @_; 
    if ( $app->param( 'force_checkout' ) ) {
        unless ( force_checkout( $object ) ) {
            my $plugin = MT->component( 'Checkout' );
            return $app->error( $plugin->translate( 'Checkout Error' ) );
        }
    }
    return 1;
}

sub _cb_cms_post_save_object {
    my ( $cb, $app, $object, $org_object ) = @_;
    if ( my $checkin = $app->param( 'checkout' ) ) {
        checkout( $object );
    }
    if ( my $checkin = $app->param( 'checkin' ) ) {
        uncheckout( $object );
    }
    return 1;
}

sub _checkout {
    my $app = shift;
    return $app->trans_error( 'Invalid request.' ) unless ( $app->validate_magic );
    my $id      = $app->param( 'id' );
    my $type    = $app->param( '_type' ) || 'entry';
    return $app->trans_error( 'Invalid request.' ) unless $id;
    my $entry = MT->model( $type )->load( $id );
    return $app->trans_error( 'Invalid request.' ) unless $entry;
    return $app->permission_denied()
        unless $app->permissions->can_edit_entry( $entry, $app->user );
    my $checkout_error;
    unless ( checkout( $entry ) ) {
        $checkout_error = 1;
    }
    $app->redirect(
        $app->uri(
            'mode' => 'view',
            args   => {
                _type   => $entry->class,
                blog_id => $entry->blog_id,
                id      => $entry->id,
                ( $checkout_error ? ( checkout_error => 1 ) : () ),
            }
        )
    );
}

sub _force_checkout {
    my $app = shift;
    return $app->trans_error( 'Invalid request.' ) unless ( $app->validate_magic );
    my $id      = $app->param( 'id' );
    my $type    = $app->param( '_type' ) || 'entry';
    return $app->trans_error( 'Invalid request.' ) unless $id;
    my $entry = MT->model( $type )->load( $id );
    return $app->trans_error( 'Invalid request.' ) unless $entry;
    return $app->permission_denied()
        unless $app->permissions->can_edit_entry( $entry, $app->user );
    my $checkout_error;
    unless ( force_checkout( $entry ) ) {
        $checkout_error = 1;
    }
    $app->redirect(
        $app->uri(
            'mode' => 'view',
            args   => {
                _type   => $entry->class,
                blog_id => $entry->blog_id,
                id      => $entry->id,
                ( $checkout_error ? ( checkout_error => 1 ) : () ),
            }
        )
    );
}

sub _uncheckout {
    my $app = shift;
    return $app->trans_error( 'Invalid request.' ) unless ( $app->validate_magic );
    my $id      = $app->param( 'id' );
    my $type    = $app->param( '_type' ) || 'entry';
    return $app->trans_error( 'Invalid request.' ) unless $id;
    my $entry = MT->model( $type )->load( $id );
    return $app->trans_error( 'Invalid request.' ) unless $entry;
    return $app->permission_denied()
        unless $app->permissions->can_edit_entry( $entry, $app->user );
    my $uncheckout_error;
    unless ( uncheckout( $entry ) ) {
        $uncheckout_error = 1;
    }
    $app->redirect(
        $app->uri(
            'mode' => 'view',
            args   => {
                _type   => $entry->class,
                blog_id => $entry->blog_id,
                id      => $entry->id,
                ( $uncheckout_error ? ( uncheckout_error => 1 ) : () ),
            }
        )
    );
}

sub _when_checkedout_by_others {
    my $app = shift;
    
    my @data;
    my $q = $app->param();
    foreach my $col ( $q->param() ) {
        next if $col eq '__mode';
        next if $col eq '_type';
        push @data,
            {   data_name   => $col,
                data_value  => scalar $q->param( $col ),
            };
    }
    
    my %params;
    require MT::Entry;
    my $type = $app->param( '_type' ) || MT::Entry->class_type;
    my $pkg = $app->model( $type ) or return "Invalid request.";
    $params{ entry_loop }           = \@data;
    $params{ object_type }          = $type;
    $params{ object_label }         = $pkg->class_label;
    $params{ object_label_plural }  = $pkg->class_label_plural;
    
    my $id = $app->param( 'id' ) or return $app->trans_error( 'Invalid request.' );
    my $entry = MT->model( $type )->load( $id ) or return $app->trans_error( 'Invalid request.' );
    my $checkout = MT->model( 'checkout' )->fetch_by_object( $entry ) or return $app->trans_error( 'Invalid request.' );
    if ( $checkout ) {
        if ($checkout->author_id == $app->user->id ) {
            $app->forward( 'save_entry' );
        } else {
            $params{ checkedout_on_ts }             = $checkout->created_on;
            $params{ checkedout_author_nickname }   = $checkout->author_nickname;
            $params{ checkedout_author_email }      = $checkout->author_email;
            my $tmpl = $app->load_tmpl( 'checkedout_by_others.tmpl' );
            $app->build_page( $tmpl, \%params );
        }
    } else {
        $app->forward( 'when_not_checkedout_yet' );
    }
}

sub _when_not_checkedout_yet {
    my $app = shift;
    
    my @data;
    my $q = $app->param();
    foreach my $col ( $q->param() ) {
        next if $col eq '__mode';
        next if $col eq '_type';
        push @data,
            {   data_name   => $col,
                data_value  => scalar $q->param( $col ),
            };
    }
    
    my %params;
    require MT::Entry;
    my $type = $app->param( '_type' ) || MT::Entry->class_type;
    my $pkg = $app->model( $type ) or return "Invalid request.";
    $params{ entry_loop }           = \@data;
    $params{ object_type }          = $type;
    $params{ object_label }         = $pkg->class_label;
    $params{ object_label_plural }  = $pkg->class_label_plural;
    
    my $id = $app->param( 'id' ) or return $app->trans_error( 'Invalid request.' );
    my $entry = MT->model( $type )->load( $id ) or return $app->trans_error( 'Invalid request.' );
    if ( not_checkedout_yet( $entry ) ) {
        my $tmpl = $app->load_tmpl( 'not_checkedout_yet.tmpl' );
        $app->build_page( $tmpl, \%params );
    } else {
        if ( checkedout_by_user( $entry ) ) {
            $app->forward( 'save_entry' );
        } else {
            $app->forward( 'when_checkedout_by_others' );
        }
    }
}


sub can_checkout {
    my ( $object ) = @_;
    return not_checkedout_yet( $object ) ||  checkedout_by_user( $object );
}

sub force_checkout {
    my ( $object ) = @_;
    checkout( $object, 1 );
}

sub checkout {
    my ( $object, $force ) = @_;
    my $app = MT->instance;
    if ( checkedout_by_others( $object ) ) {
        if ( $force ) {
            force_uncheckout( $object );
        } else {
            return 0;
        }
    }
    my $checkout = MT->model( 'checkout' )->new;
    $checkout->blog_id( $object->blog_id );
    $checkout->object_id( $object->id );
    $checkout->object_ds( $object->datasource );
    $checkout->author_id( $app->user->id );
    $checkout->author_nickname( $app->user->nickname );
    $checkout->author_email( $app->user->email );
    $checkout->save or die $checkout->errstr;
}

sub force_uncheckout {
    my ( $object ) = @_;
    uncheckout( $object, 1 );
}

sub uncheckout {
    my ( $object, $force ) = @_;
    return 1 if not_checkedout_yet( $object );
    if ( checkedout_by_others( $object ) ) {
        unless ( $force ) {
            return 0;
        }
    }
    if ( my $checkout = MT->model( 'checkout' )->fetch_by_object( $object ) ) {
        $checkout->remove or die $checkout->errstr;
    }
    return 1;
}

sub not_checkedout_yet {
    my ( $object ) = @_;
    my $app = MT->instance;
    my $checkout = MT->model( 'checkout' )->fetch_by_object( $object );
    return ( $checkout ? 0 : 1 );
}

sub checkedout_by_user {
    my ( $object ) = @_;
    my $app = MT->instance;
    my $checkout = MT->model( 'checkout' )->fetch_by_object( $object ) or return 0;
    $checkout->author_id == $app->user->id;
}

sub checkedout_by_others {
    my ( $object ) = @_;
    my $app = MT->instance;
    my $checkout = MT->model( 'checkout' )->fetch_by_object( $object ) or return 0;
    $checkout->author_id != $app->user->id;
}

sub _list_props_entry {
    my $app    = MT->instance;
    my $plugin = MT->component( 'Checkout' );
    return {
        checkedout_by   => {
            label   => $plugin->translate( 'Check-out User' ),
            base    => '__virtual.string',
            auto    => 1,
            display => 'default',
            order   => 250,
            html    => sub {
                my ( $prop, $obj, $app ) = @_;
                my $checkout = MT->model( 'checkout' )->fetch_by_object( $obj );
                return $checkout ? $checkout->author_nickname : '-';
            },
            filter_label    => 'Check-out User',
            terms           => sub {
                my $prop = shift;
                my ( $args, $db_terms, $db_args ) = @_;
                my $app = MT->app or return;
                my $blog = $app->blog;
                my $blog_id = $blog ? $blog->id : undef;
                $prop->{col} = 'name';
                my $name_query = $prop->super( @_ );
                $prop->{col} = 'nickname';
                my $nickname_query = $prop->super( @_ );
                my $author_name  = $args->{ string };
                $db_args->{joins} ||= [];
                push @{ $db_args->{joins} }, MT->model( 'checkout' )->join_on(
                    undef,
                    {
                        object_id   => \'= entry_id',
                        object_ds   => $prop->datasource->datasource,
                        $blog ? ( blog_id => $blog_id ) : (),
                    },
                    {
                        joins       => [
                            MT->model( 'author' )->join_on(
                                undef,
                                [
                                    {id => \'= checkout_author_id'},
                                    ( '-and' ),
                                    [
                                        $name_query,
                                        ( $args->{ 'option' } eq 'not_contains' ? '-and' : '-or' ),
                                        $nickname_query,
                                    ]
                                ],
                                {
                                    unique => 1
                                } )
                        ]
                    },
                );
                return;
            },
        },
        checkout_author_id  => {
            base            => '__virtual.hidden',
            display         => 'none',
            filter_editable => 0,
            terms => sub {
                my $prop = shift;
                my ( $args, $db_terms, $db_args ) = @_;
                my $app = MT->app or return;
                my $blog = $app->blog;
                my $blog_id = $blog ? $blog->id : undef;
                my $class = $prop->datasource;
                my $author_id = $args->{ value };
                $db_args->{joins} ||= [];
                push @{ $db_args->{joins} }, MT->model( 'checkout' )->join_on(
                    undef,
                    {
                        object_id   => \'= entry_id',
                        object_ds   => $prop->datasource->datasource,
                        $blog ? ( blog_id => $blog_id ) : (),
                        author_id   => $author_id,
                    },
                );
                return;
            },
            
        }
    };
}

sub _filter_entry_checkout {
    my $app = MT->instance;
    my $user = $app->user or return {};
    my $type = $app->param( '_type' ) || $app->param( 'datasource' );
    my $label = $type eq 'entry' ?
        'Entry' :
            $type eq 'page' ?
                'Page' :
                    'Object';
    my $plugin = MT->component( 'Checkout' );
    return {
        condition   => sub {
            return defined( $user ) ? 1 : 0;
        },
        label       => $plugin->translate( 'Checked-out [_1]', $app->translate( $label ) ),
        items       => [
            {
                type    => 'checkout_author_id',
                args    => {
                    value   => $user->id,
                }
            }
        ]
    };
}

sub _list_action_checkin_entry {
    my $app = shift;
    $app->setup_filtered_ids
        unless $app->param( 'all_selected' );
    my $user = $app->user or
        return $app->trans_error( 'Invalid request.' );
    my $type = $app->param( '_type' ) || 'entry';
    my $class = MT->model( $type );
    my @ids = $app->param( 'id' );
    my $uncheckout_count = 0;
    for my $id ( @ids ) {
        my $object = $class->load( $id );
        next unless $object;
        return $app->permission_denied()
            unless $user->permissions( $object->blog_id )->can_edit_entry( $object, $user );
        $uncheckout_count++ if uncheckout( $object );
    }
    $app->add_return_arg( uncheckedout => 1, uncheckout_count => $uncheckout_count );
    return $app->call_return();
}

sub _list_action_checkout_entry {
    my $app = shift;
    __list_action_checkout_entry( $app );
}

sub _list_action_force_checkout_entry {
    my $app = shift;
    __list_action_checkout_entry( $app, 1 );
}

sub __list_action_checkout_entry {
    my $app = shift;
    my ( $force ) = @_;
    $app->setup_filtered_ids
        unless $app->param( 'all_selected' );
    my $user = $app->user or
        return $app->trans_error( 'Invalid request.' );
    my $type = $app->param( '_type' ) || 'entry';
    my $class = MT->model( $type );
    my @ids = $app->param( 'id' );
    my $checkout_count = 0;
    for my $id ( @ids ) {
        my $object = $class->load( $id );
        next unless $object;
        return $app->permission_denied()
            unless $user->permissions( $object->blog_id )->can_edit_entry( $object, $user );
        $checkout_count++ if checkout( $object, $force );
    }
    $app->add_return_arg( checkedout => 1, checkout_count => $checkout_count );
    return $app->call_return();
}

sub _cb_ts_entry_list_header {
    my ( $cb, $app, $tmpl_ref ) = @_;
    my $mtml = <<'MTML';
<mt:setvarblock name="system_msg" append="1">
<__trans_section component="Checkout">
<div id="msg-container">
    <mt:if name="request.checkedout">
        <mt:if name="request.checkout_count" gt="0">
            <mtapp:statusmsg
                id="checkedout"
                class="success"
                rebuild="">
                <__trans phrase="Checked-out of the [_1] [_2].", params="<MTVar name='object_label_plural'>%%<MTVar name='request.checkout_count'>">
            </mtapp:statusmsg>
        <mt:else>
            <mtapp:statusmsg
                id="checkedout"
                class="error"
                rebuild="">
                <__trans phrase="[_1] can be checked-out does not exist.", params="<MTVar name='object_label_plural'>">
            </mtapp:statusmsg>
        </mt:if>
    </mt:if>
    <mt:if name="request.uncheckedout">
        <mt:if name="request.uncheckout_count" gt="0">
            <mtapp:statusmsg
                id="checkedout"
                class="success"
                rebuild="">
                <__trans phrase="Checked-in of the [_1] [_2].", params="<MTVar name='object_label_plural'>%%<MTVar name='request.uncheckout_count'>">
            </mtapp:statusmsg>
        <mt:else>
            <mtapp:statusmsg
                id="checkedout"
                class="error"
                rebuild="">
                <__trans phrase="[_1] can be checked-in does not exist.", params="<MTVar name='object_label_plural'>">
            </mtapp:statusmsg>
        </mt:if>
    </mt:if>
</div>
</__trans_section>
</mt:setvarblock>
MTML
    $$tmpl_ref .= $mtml;
    1;
}

sub _cb_tp_entry_list_header {
    my ( $cb, $app, $param, $tmpl ) = @_;
    my $type = $app->param( '_type' ) || 'entry';
    my $pkg = $app->model( $type ) or return;
    $param->{ object_label_plural }  = $pkg->class_label_plural;
}

1;