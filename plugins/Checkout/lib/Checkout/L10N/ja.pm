package Checkout::L10N::ja;

use strict;
use warnings;
use base 'Checkout::L10N::en_us';
use utf8;

use vars qw( %Lexicon );

%Lexicon = (
    '_PLUGIN_DESCRIPTION'   => 'Dreamweaver風のチェックアウト機能を提供し、複数人での更新作業を支援します',
    'Checkout Status'       => 'チェックアウト状態',
    # lib/Checkout/Plugin.pm
    'Undo'                  => '取り消し',
    'Override'              => '上書き',
    'Checkin'               => 'チェックイン',
    'Checkout'              => 'チェックアウト',
    'It is checked-out at [_1].'    => 'チェックアウト済です。（[_1]）',
    'By [_2], this was checked out at [_1].'    => '[_2]によってチェックアウトされています。（[_1]）',
    'It is not checked-out yet.'    => 'まだチェックアウトされていません。',
    "That you want to override the check out, there is a risk of losing the other user's changes."  => 'チェックアウトを上書きすると、他のユーザによる変更内容を上書きする可能性があります。',
    'Checkout Error'        => 'チェックアウトできません。',
    # tmpl/checkout_by_others.tmpl
    'Are you sure you want to override really?' => '本当にチェックアウトを上書きしますか？',
    'Checkout [_1]'         => '[_1]のチェックアウト',
    'Do you want to continue it after check-out?' => 'チェックアウトして継続しますか？',
);

1;