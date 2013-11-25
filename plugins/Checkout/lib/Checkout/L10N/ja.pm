package Checkout::L10N::ja;

use strict;
use warnings;
use base 'Checkout::L10N::en_us';
use utf8;

use vars qw( %Lexicon );

%Lexicon = (
    '_PLUGIN_DESCRIPTION'   => 'Dreamweaver風のチェックアウト機能を提供し、複数人での更新作業を支援します',
    'Checkout Status'       => 'チェックアウト状態',
    'Check-out'             => 'チェックアウト',
    'Check-out (Allow override)'    => 'チェックアウト（上書きを許可）',
    'Check-in'              => 'チェックアウトの取り消し',
    # lib/Checkout/Plugin.pm
    'Undo'                  => '取り消し',
    'Override'              => '上書き',
    'Checkin'               => 'チェックイン',
    'Unheckout'             => 'チェックアウト取消',
    'Checkout'              => 'チェックアウト',
    'It is checked-out at [_1].'    => 'チェックアウト済です。（[_1]）',
    'By [_2], this was checked out at [_1].'    => '[_2]によってチェックアウトされています。（[_1]）',
    'It is not checked-out yet.'    => 'まだチェックアウトされていません。',
    'Checked-in now.'       => 'チェックインしました。',
    "That you want to override the check out, there is a risk of losing the other user's changes."  => 'チェックアウトを上書きすると、他のユーザによる変更内容を上書きする可能性があります。',
    'Checkout Error'        => 'チェックアウトできません。',
    'Checked-out [_1]'      => 'チェックアウトされた[_1]',
    'Check-out User'        => 'チェックアウトユーザー',
    'Checked-out of the [_1] [_2].' => '[_2]件の[_1]をチェックアウトしました。',
    'Checked-in of the [_1] [_2].'  => '[_2]件の[_1]のチェックアウトを取り消しました。',
    '[_1] can be checked-out does not exist.'   => 'チェックアウトできる[_1]がありませんでした。',
    '[_1] can be checked-in does not exist.'    => 'チェックアウト済みの[_1]がありませんでした。',
    'Update without Check-out'  => 'チェックアウトせずに更新',
    # tmpl/checkout_by_others.tmpl
    'Are you sure you want to override really?' => '本当にチェックアウトを上書きしますか？',
    'Checkout [_1]'         => '[_1]のチェックアウト',
    'Do you want to continue it after check-out?' => 'チェックアウトして継続しますか？',
);

1;