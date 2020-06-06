package App::column::run;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

our %SPEC;

$SPEC{column_run} = {
    v => 1.1,
    summary => 'Run several commands and show their output in multiple columns',
    description => <<'_',

Features:

* ANSI color and wide character handling

* multiple output backend (HTML or text)

* passing adjusted COLUMNS environment so commands can adjust their output

* Passing common arguments to all commands

* Multiplexing STDIN to all commands

_
    args => {
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
            req => 1,
            pos => 0,
            slurpy => 1,
        },
        linum => {
            summary => 'Add line number',
            schema => 'bool*',
        },
        linum_width => {
            summary => 'Line number width',
            schema => 'posint*',
        },
        separator => {
            summary => 'Separator character between columns',
            schema => 'str*',
            default => '|',
        },
        on_long_line => {
            summary => 'What to do to long lines',
            schema => ['str*', in=>['clip','wrap']],
            default => 'clip',
        },
        # TODO: column_widths
        # TODO: column_bgcolors
        # TODO: column_fgcolors
    },
    links => [
        {url=>'prog:column', summary=>'Unix utility'},
        {url=>'prog:diff', summary=>'The --side-by-side (-y) option display files in two columns'},
    ],
};
sub column_run {
    require IPC::Open2;
    require ShellQuote::Any::PERLANCAR;
    require Term::App::Util::Size;
    require Text::WideChar::Util;

    my %args = @_;
    my $commands = $args{commands};
    my $num_commands = @$commands;

    # calculate widths

    my $term_width0 = Term::App::Util::Size::term_width()->[2];
    my $linum = $args{linenum};
    my $linum_width = $args{linenum_width} // 4;
    my $term_width = $term_width0;
    if ($linum) {
        $term_width0 > $linum_width
            or return [412, "No horizontal room for line number"];
        $term_width -= $linum_width;
    }
    my $separator = $args{separator} // '|';
    my $separator_width = Text::WideChar::Util::mbswidth($separator);
    $term_width > $separator_width * ($num_commands-1)
        or return [412, "No horizontal room for separators"];
    $term_width -= $separator_width * ($num_commands-1);

    my $column_width = int($term_width / $num_commands);
    $per_column_width > 1 or return [412, "No horizontal room for the columns"];

    # start the programs and capture the output. for now we do this in a simple
    # way: one by one and grab the whole output. in the future we might do this
    # parallel and line-by-line.

    my $stdin_lines;
    unless (-t STDIN) {
        $stdin_lines = [<STDIN>];
    }

    my @command_outputs; # ([line1-from-cmd1, ...], [line1-from-cmd2, ...], ...)
    for my $i (0..$#{$commands}) {
        my $cmd = $commands->[$i];
        if ($args{args}) {
            $cmd .= " " . ShellQuote::Any::PERLANCAR::shell_quote(@{ $args{args} });
        }
        my ($chld_out, $chld_in);
        my $pid = IPC::Open2::open2($chld_out, $chld_in, $cmd);
        if ($stdin_lines) { print $chld_in $_ for @$stdin_lines }
        $command_outputs[$i] = [<$chld_out>];
    }

    use DD; dd \@command_outputs;
    [200];
}

1;
#ABSTRACT:

=cut
