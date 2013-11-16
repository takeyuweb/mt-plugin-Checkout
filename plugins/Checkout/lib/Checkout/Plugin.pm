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
    <mtapp:statusmsg
        id="checkout"
        class="info">
        <__trans phrase="It is not checked-out yet." />
        <mt:Unless name="reedit">
            <a href="<$mt:var name='script_url'$>?id=<$mtvar name='id' escape='html'$>&blog_id=<$mtvar name='blog_id'$>&__mode=checkout&_type=<$mt:var name='object_type'$>&magic_token=<$mt:var name='magic_token'$>"><__trans phrase="Checkout" /></a>
        </mt:Unless>
    </mtapp:statusmsg>
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
    return 1 unless $id;
    my $entry = MT->model( $type )->load( $id );
    return 1 unless $entry;
    
    if ( checkedout_by_user( $entry ) ) {
        $app->forward( 'save_entry' );
    } else {
        if ( checkedout_by_others( $entry ) ) {
            $app->forward( 'when_checkedout_by_others' );
        } else {
            $app->forward( 'when_not_checkedout_yet' );
        }
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
    my $type = $app->param( 'type' ) || MT::Entry->class_type;
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
    my $type = $app->param( 'type' ) || MT::Entry->class_type;
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

1;