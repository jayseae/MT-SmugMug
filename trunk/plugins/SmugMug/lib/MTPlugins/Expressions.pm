# MTPlugins::Expressions
# Process tag expressions in Movable Type tag arguments
#
# Copyright 2003 Kalsey Consulting Group
# http://kalsey.com/
# Using this software signifies your acceptance of the license
# agreement that accompanies this software.
#
# Complete installation and usage instructions can be found at
# http://kalsey.com/tools/mtplugins/expressions/

#    Usage:
#    my $tokens = $ctx->stash('tokens');
#    my $builder = $ctx->stash('builder');
#    $args = MTPlugins::Expressions::process($ctx, $args);

package MTPlugins::Expressions;

use strict;


# Process MT tags in all arguments. Returns an argument reference
# with all tags processed.
sub process {
    my($ctx, $args) = @_;
    use MT::Util qw(decode_html);
    my %new_args;
    my $builder = $ctx->stash('builder');
    for my $arg (keys %$args) {
        my $expr = decode_html($args->{$arg});
        if ( ($expr =~ m/\<MT.*?\>/g) ||
              $expr =~ s/\[(MT(.*?))\]/<$1>/g) {
            my $tok = $builder->compile($ctx, $expr);
            my $out = $builder->build($ctx, $tok);
            return $ctx->error("Error in argument expression: ".$builder->errstr) unless defined $out;
            $new_args{$arg} = $out;
        } else {
            $new_args{$arg} = $expr;
        }
    }
    \%new_args;
}

1;