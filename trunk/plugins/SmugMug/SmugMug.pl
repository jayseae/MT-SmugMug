# ===========================================================================
# Copyright Everitz Consulting.  Not for redistribution.
# ===========================================================================
package MT::Plugin::SmugMug;

use strict;

use base qw( MT::Plugin );

use MT;
use MT::Util qw( format_ts );

my $plugin = MT::Plugin::SmugMug->new({
    id             => 'SmugMug',
    key            => 'smugmug',
    name           => 'MT-SmugMug',
    description    => q(<MT_TRANS phrase="Easily integrate SmugMug with your site.">),
    author_name    => 'Everitz Consulting',
    author_link    => 'http://everitz.com/',
    plugin_link    => 'http://everitz.com/mt/smugmug/index.php',
    doc_link       => 'http://everitz.com/mt/smugmug/install.php',
#    l10n_class     => 'SmugMug::L10N',
    version        => '0.0.1',
    config_template   => 'settings.tmpl',
    settings               => new MT::PluginSettings([
        ['smugmug_limit', { Default => 10 }],
    ]),
    container_tags         => {
        'SmugMug'                   => \&smugmug,
        'SmugMugPhotos'             => \&smugmug_photos,
    },
    template_tags          => {
        'SmugMugDatasource'         => \&smugmug_return_value,
        'SmugMugXMLVersion'         => \&smugmug_return_value,
        'SmugMugRSSVersion'         => \&smugmug_return_value,
        'SmugMugTitle'              => \&smugmug_return_value, # channel->title
        'SmugMugLink'               => \&smugmug_return_value, # channel->link
        'SmugMugDescription'        => \&smugmug_return_value, # channel->description
        'SmugMugCreatedDate'        => \&smugmug_return_value, # channel->pubDate
        'SmugMugModifiedDate'       => \&smugmug_return_value, # channel->lastBuildDate
        'SmugMugGenerator'          => \&smugmug_return_value, # channel->generator
        'SmugMugCopyright'          => \&smugmug_return_value, # channel->copyright
        'SmugMugFeedImage'          => \&smugmug_return_value, # image->url
        'SmugMugPhotoCount'         => \&smugmug_return_value, # count of items in gallery
        'SmugMugPhotoTitle'         => \&smugmug_return_value, # item->title
        'SmugMugPhotoLink'          => \&smugmug_return_value, # item->guid
        'SmugMugPhotoPage'          => \&smugmug_return_value, # item->link
        'SmugMugPhotoDescription'   => \&smugmug_return_value, # item->description
        'SmugMugPhotoCategory'      => \&smugmug_return_value, # item->category
        'SmugMugPhotoComments'      => \&smugmug_return_value, # item->comments
        'SmugMugPhotoOriginalDate'  => \&smugmug_return_value, # item->exif:DateTimeOriginal
        'SmugMugPhotoPublishedDate' => \&smugmug_return_value, # item->pubDate
        'SmugMugPhotoLatitude'      => \&smugmug_return_value, # item->geo:lat
        'SmugMugPhotoLongitude'     => \&smugmug_return_value, # item->geo:long
        'SmugMugPhotoID'            => \&smugmug_return_value, # photo id extracted from item->link
    },
});
MT->add_plugin($plugin);

sub init_registry {
    my $plugin = shift;
    $plugin->registry({
        tags => {
            block => {
                'SmugMug'                   => \&smugmug,
                'SmugMugPhotos'             => \&smugmug_photos,
            },
            function => {
                'SmugMugDatasource'         => \&smugmug_return_value,
                'SmugMugXMLVersion'         => \&smugmug_return_value,
                'SmugMugRSSVersion'         => \&smugmug_return_value,
                'SmugMugTitle'              => \&smugmug_return_value, # channel->title
                'SmugMugLink'               => \&smugmug_return_value, # channel->link
                'SmugMugDescription'        => \&smugmug_return_value, # channel->description
                'SmugMugCreatedDate'        => \&smugmug_return_value, # channel->pubDate
                'SmugMugModifiedDate'       => \&smugmug_return_value, # channel->lastBuildDate
                'SmugMugGenerator'          => \&smugmug_return_value, # channel->generator
                'SmugMugCopyright'          => \&smugmug_return_value, # channel->copyright
                'SmugMugFeedImage'          => \&smugmug_return_value, # image->url
                'SmugMugPhotoCount'         => \&smugmug_return_value, # count of items in gallery
                'SmugMugPhotoTitle'         => \&smugmug_return_value, # item->title
                'SmugMugPhotoLink'          => \&smugmug_return_value, # item->guid
                'SmugMugPhotoPage'          => \&smugmug_return_value, # item->link
                'SmugMugPhotoDescription'   => \&smugmug_return_value, # item->description
                'SmugMugPhotoCategory'      => \&smugmug_return_value, # item->category
                'SmugMugPhotoComments'      => \&smugmug_return_value, # item->comments
                'SmugMugPhotoOriginalDate'  => \&smugmug_return_value, # item->exif:DateTimeOriginal
                'SmugMugPhotoPublishedDate' => \&smugmug_return_value, # item->pubDate
                'SmugMugPhotoLatitude'      => \&smugmug_return_value, # item->geo:lat
                'SmugMugPhotoLongitude'     => \&smugmug_return_value, # item->geo:long
                'SmugMugPhotoID'            => \&smugmug_return_value, # photo id extracted from item->link
            },
        },
    });
}

sub apply_default_settings {
    my $plugin = shift;
    my ($data, $scope) = @_;
    if ($scope ne 'system') {
        my $sys = $plugin->get_config_obj('system');
        my $sysdata = $sys->data();
        if ($plugin->{settings} && $sysdata) {
            foreach (keys %$sysdata) {
                $data->{$_} = $sysdata->{$_} if !exists $data->{$_};
            }
        }
    } else {
        $plugin->SUPER::apply_default_settings(@_);
    }
}

sub load_config {
    my $plugin = shift;
    my ($args, $scope) = @_;

    $plugin->SUPER::load_config(@_);

    my $app = MT->instance;
    if ($app->isa('MT::App')) {
        $args->{static_uri} = $app->static_path;
    }
    $args->{mt4} = $app->version_number >= 4 ? 1 : 0;
}

sub smugmug {
    my ($ctx, $args, $cond) = @_;
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    require MTPlugins::Expressions;
    $args = MTPlugins::Expressions::process($ctx, $args);
    my $feed;
    my $type = $args->{type} ? '&Type='.$args->{type} : '';
    my $data = $args->{data} ? '&Data='.$args->{data} : '';
    my $parm = $type ? ($data ? $type.$data : $type) : '';
    my $nick = $args->{nickname};
    if ($parm) {
        if ($nick) {
            $feed = "http://$nick.smugmug.com/hack/feed.mg?$parm";
        } else {
            $feed = "http://www.smugmug.com/hack/feed.mg?$parm";
        }
    } else {
        if ($nick) {
            $feed = "http://$nick.smugmug.com/hack/feed.mg?Type=nickname&Data=$nick";
        } else {
            $feed = "http://www.smugmug.com/hack/feed.mg?Type=popular&Data=today";
        }
    }
    my $config = $plugin->get_config_hash('blog:'.$ctx->stash('blog_id'));
    my $limit = $args->{lastn} || $config->{smugmug_limit};
    $feed .= $config->{smugmug_limit} ? '&ImageCount='.$limit : '';
    $feed .= '&format=rss';
    my $dat = smugmug_load_feed($feed);
    return $ctx->error($plugin->translate('Error processing file: [_1]', $feed)) unless $dat;
    $dat =~ s|&|&amp;|g;
    $ctx->stash('smugmugcontent', $dat);
    $ctx->stash('smugmugdatasource', $feed);
    require XML::Twig;
    my $twig = XML::Twig->new(
        twig_handlers => {
            'rss' => sub {
                my ($twig, $rss) = @_;
                my $builder = $ctx->stash('builder');
                my $tokens = $ctx->stash('tokens');
                my $res = '';
                $ctx->stash('smugmugxmlversion', $twig->xml_version);
                $ctx->stash('smugmugrssversion', $rss->{'att'}->{'version'});
                smugmug_set_value($ctx, 'smugmugtitle', $rss->first_child('channel'), 'title');
                smugmug_set_value($ctx, 'smugmuglink', $rss->first_child('channel'), 'link');
                smugmug_set_value($ctx, 'smugmugdescription', $rss->first_child('channel'), 'description');
                smugmug_set_value($ctx, 'smugmugcreateddate', $rss->first_child('channel'), 'pubDate');
                smugmug_format_date($ctx, 'smugmugcreateddate', 'rss2');
                smugmug_set_value($ctx, 'smugmugmodifieddate', $rss->first_child('channel'), 'lastBuildDate');
                smugmug_format_date($ctx, 'smugmugmodifieddate', 'rss2');
                smugmug_set_value($ctx, 'smugmuggenerator', $rss->first_child('channel'), 'generator');
                smugmug_set_value($ctx, 'smugmugcopyright', $rss->first_child('channel'), 'copyright');
                smugmug_set_value($ctx, 'smugmugfeedimage', $rss->first_child('channel')->first_child('image'), 'url');
                my @photos = $rss->first_child('channel')->children('item');
                $ctx->stash('smugmugphotocount', scalar @photos);
                my $out = $builder->build($ctx, $tokens);
                return $ctx->error($builder->errstr) unless (defined $out);
                $res .= $out;
                $twig->purge;
            },
        },
    );
    $twig->parse($dat);
    my $out = $builder->build($ctx, $tokens);
    return $ctx->error($builder->errstr) unless (defined $out);
    my $res = '';
    $res .= $out;
}

sub smugmug_photos {
    my ($ctx, $args, $cond) = @_;
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    my $dat = $ctx->stash('smugmugcontent');
    my $glue = $args->{glue} || '';
    my $res = '';
    require XML::Twig;
    my $twig = XML::Twig->new(
        TwigHandlers => {
            'channel' => sub {
                my ($twig, $channel, $date) = @_;
                my @photos = $channel->children('item');
                foreach my $photo (@photos) {
                    if ($photo) {
                        smugmug_set_value($ctx, 'smugmugphototitle', $photo, 'title');
                        smugmug_set_value($ctx, 'smugmugphotolink', $photo, 'guid');
                        smugmug_set_value($ctx, 'smugmugphotopage', $photo, 'link');
                        my $id = $photo->first_child('link')->text;
                        $id =~ m|http://.+\.smugmug\.com/gallery/\d+\#(\d+)|;
                        $ctx->stash('smugmugphotoid', $1);
                        smugmug_set_value($ctx, 'smugmugphotodescription', $photo, 'description');
                        smugmug_set_value($ctx, 'smugmugphotocategory', $photo, 'category');
                        smugmug_set_value($ctx, 'smugmugphotocomments', $photo, 'comments');
                        smugmug_set_value($ctx, 'smugmugphotooriginaldate', $photo, 'exif:DateTimeOriginal');
                        smugmug_format_date($ctx, 'smugmugphotooriginaldate', 'exif');
                        smugmug_set_value($ctx, 'smugmugphotopublisheddate', $photo, 'pubDate');
                        smugmug_format_date($ctx, 'smugmugphotopublisheddate', 'rss2');
                        smugmug_set_value($ctx, 'smugmugphotolatitude', $photo, 'geo:lat');
                        smugmug_set_value($ctx, 'smugmugphotolongitude', $photo, 'geo:long');
                        my $out = $builder->build($ctx, $tokens);
                        return $ctx->error($builder->errstr) unless (defined $out);
                        $res .= $glue if $res ne '';
                        $res .= $out;
                    }
                }
                $twig->purge;
            },
        },
    );
    $twig->parse ($dat);
    $res;
}

# utilities

sub smugmug_format_date {
    my ($ctx, $field, $format) = @_;
    return unless (my $date = $ctx->stash($field));
    my ($dc_yyyy, $dc_mo, $dc_dd, $dc_hh, $dc_mm, $dc_ss);
    if ($format eq 'exif') {
        ($dc_yyyy, $dc_mo, $dc_dd, $dc_hh, $dc_mm, $dc_ss) = ($date =~ m|(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})|);
    }
    if ($format eq 'rss2') {
        ($dc_dd, $dc_mo, $dc_yyyy, $dc_hh, $dc_mm, $dc_ss) = ($date =~ m|\w{3}, (\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})|);
        my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
        for my $month (0..11) {
            $dc_mo = ++$month if ($dc_mo eq $months[$month]);
        }
    }
    $ctx->stash($field, $dc_yyyy.sprintf("%02d", $dc_mo).sprintf("%02d", $dc_dd).$dc_hh.$dc_mm.$dc_ss);
}

sub smugmug_load_feed {
    my $feed = shift;
    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new (GET => $feed);
    $ua->timeout (15);
    $ua->agent($plugin->name.'/'.$plugin->version);
    my $result = $ua->request($req);
    return '' unless $result->is_success;
    $result->content;
}

sub smugmug_return_value {
    my ($ctx, $args) = @_;
    my $val = $ctx->stash(lc($ctx->stash('tag')));
    if (my $fmt = $args->{format}) {
        if ($val =~ /^[0-9]{14}$/) {
            require MT::Util;
            return MT::Util::format_ts($fmt, $val, $ctx->stash('blog'));
        }
    }
    $val;
}

sub smugmug_set_value {
    my ($ctx, $field, $root, $element) = @_;
    $ctx->stash($field, $root->first_child($element) ? $root->first_child($element)->text : '');
}

1;