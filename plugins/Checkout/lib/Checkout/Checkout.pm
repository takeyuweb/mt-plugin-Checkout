package Checkout::Checkout;
use strict;
use warnings;
use utf8;
use base qw( MT::Object );

our $plugin = MT->component( 'Checkout' );

__PACKAGE__->install_properties({
    column_defs => {
        id          => 'integer not null auto increment',
        blog_id     => 'integer not null',
        object_id   => 'integer not null',
        object_ds   => 'string(50) not null',
        author_id   => 'integer not null',
        author_nickname => 'string(255)',
        author_email => 'string(255)',
    },
    indexes     => {
        author_id   => 1,
    },
    audit       => 1,
    datasource  => 'checkout',
    primary_key => 'id',
    class_type  => 'checkout',
});

sub class_label {
    $plugin->translate( 'Checkout Status' );
}

sub object {
    my $checkout = shift;
    $checkout->cache_property(
        'object',
        sub {
            return undef unless $checkout->object_ds && $checkout->object_id;
            my $object = MT->model( $checkout->object_ds )->load( $checkout->object_id );
            $object;
        }
    );
}

sub author {
    my $checkout = shift;
    $checkout->cache_property(
        'author',
        sub {
            return undef unless $checkout->author_id;
            my $req          = MT::Request->instance();
            my $author_cache = $req->stash( 'author_cache' );
            my $author       = $author_cache->{ $checkout->author_id };
            unless ($author) {
                $author = MT->model( 'author' )->load( $checkout->author_id )
                    or return undef;
                $author_cache->{ $checkout->author_id } = $author;
                $req->stash( 'author_cache', $author_cache );
            }
            $author;
        }
    );
}

sub fetch_by_object {
    my $class = shift;
    my ( $object ) = @_;
    my $checkout = $class->load(
        {   blog_id     => $object->blog_id,
            object_id   => $object->id,
            object_ds   => $object->datasource,
        }
    );
}

1;
