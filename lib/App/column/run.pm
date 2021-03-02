package App::column::run;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Text::Column::Util;

our %SPEC;

# TODO: color theme

$SPEC{column_run} = {
    v => 1.1,
    summary => 'Run several commands and show their output in multiple columns',
    description => <<'_',

This utility is similar to using the Unix utility <prog:pr> to columnate output,
something like (in bash):

    % pr -T -m -w $COLUMNS <(command1 args...) <(command2 args...)

except with the following differences:

* commands are run in sequence, not in parallel;

* all output are collected first, then displayed;

* multiplexing STDIN to all commands;

* ANSI color and wide character handling;

* passing adjusted COLUMNS environment to commands so they can adjust output;

* passing common arguments to all commands.


_
    args => {
        %Text::Column::Util::args_common,
        commands => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'command',
            schema => ['array*', of=>'str*'], # XXX actually array of str is allowed as command
            req => 1,
            pos => 0,
            slurpy => 1,
        },
        args => {
            summary => 'Common arguments to pass to each program',
            'x.name.is_plural' => 1,
            'x.name.singular' => 'arg',
            schema => ['array*', of=>'str*'],
        },
    },
    'cmdline.skip_format' => 1,
    links => [
        {url=>'prog:pr', summary=>'Unix utility to format and columnate text'},
        {url=>'prog:column', summary=>'Unix utility to fill columns with list'},
        {url=>'prog:diff', summary=>'The --side-by-side (-y) option display files in two columns'},
    ],
};
sub column_run {
    require IPC::Run;
    require ShellQuote::Any::PERLANCAR;

    my %args = @_;
    my $commands = delete $args{commands};
    my $command_args = delete $args{args};

    Text::Column::Util::show_texts_in_columns(
        %args,
        num_columns => scalar @$commands,
        gen_texts => sub {
            my %gargs = @_;
            # start the programs and capture the output. for now we do this in a
            # simple way: one by one and grab the whole output. in the future we
            # might do this parallel and line-by-line.

            my $stdin = "";
            unless (-t STDIN) {
                local $/;
                $stdin = <STDIN>;
            }

            local $ENV{COLUMNS} = $gargs{column_width};

            my @texts; # ([line1-from-cmd1, ...], [line1-from-cmd2, ...], ...)
            for my $i (0..$#{$commands}) {
                my $cmd = $commands->[$i];
                if ($command_args) {
                    $cmd .= " " . ShellQuote::Any::PERLANCAR::shell_quote(@{ $command_args });
                }
                my ($out, $err);
                IPC::Run::run(
                    sub {
                        system $cmd;
                        if ($?) { die "Can't system($cmd):, exit code=".($? < 0 ? $? : $? >> 8) }
                    },
                    \$stdin,
                    \$out,
                    \$err,
                );
                $texts[$i] = $out;
            }
            \@texts;
        }, # _gen_texts
    );
}

1;
#ABSTRACT:

=cut
