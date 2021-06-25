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
# TODO: parallel execution
# TODO: streaming/immediate output

$SPEC{column_run} = {
    v => 1.1,
    summary => 'Run several commands and show their output in multiple columns',
    description => <<'_',

This utility is similar to using the Unix utility <prog:pr> to columnate output,
something like (in bash):

    % pr -T -m -w $COLUMNS <(command1 args...) <(command2 args...)

except with the following differences:

* commands are run in sequence, not in parallel (although parallel execution is
  a TODO list item);

* all output are collected first, then displayed (although streaming output is a
  TODO list item);

* multiplexing STDIN to all commands;

* ANSI color and wide character handling;

* passing adjusted COLUMNS environment to commands so they can adjust output;

* passing common arguments and environment variables to all commands (as well as
  allowing each command to have its unique arguments or environment variables).

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
        common_args => {
            summary => 'Common arguments to pass to each command',
            description => <<'_',

If `--args-arrays` is also set, then the common arguments will be added first,
then the per-command arguments.

_
            'x.name.is_plural' => 1,
            'x.name.singular' => 'common_arg',
            schema => ['array*', of=>'str*'],
        },
        args_arrays => {
            summary => 'Arguments to give to each command (an array of arrays of strings)',
            schema => ['array*', of=>'aos*'],
            description => <<'_',

If `--common-args` is also set, then the common arguments will be added first,
then the per-command arguments.

_
        },
        common_envs => {
            summary => 'Common environment variables to pass to each command',
            'x.name.is_plural' => 1,
            'x.name.singular' => 'common_env',
            schema => ['hash*', of=>'str*'],
        },
        envs_arrays => {
            summary => 'Environment variables to give to each command (an array of hashes of strings)',
            schema => ['array*', of=>'hos*'],
        },
    },
    'cmdline.skip_format' => 1,
    links => [
        {url=>'prog:pr', summary=>'Unix utility to format and columnate text'},
        {url=>'prog:column', summary=>'Unix utility to fill columns with list'},
        {url=>'prog:diff', summary=>'The --side-by-side (-y) option display files in two columns'},
    ],
    examples => [
        {
            summary => 'Compare JSON vs Perl Data::Dump vs YAML dump, side by side',
            src => 'cat ~/samples/bookstore.json | COLOR=1 column-run pp-json json2dd json2yaml',
            src_plang => 'bash',
            test => 0,
            'x.doc.show_result' => 0,
        },
        {
            summary => 'Compare different color themes',
            src => q(cat ~/samples/bookstore.json | COLOR=1 column-run --envs-arrays-json '[{"DATA_DUMP_COLOR_THEME":"Default256"},{"DATA_DUMP_COLOR_THEME":"Default16"}]' 'json2dd --dumper=Data::Dump::Color' 'json2dd --dumper=Data::Dump::Color'),
            src_plang => 'bash',
            test => 0,
            'x.doc.show_result' => 0,
        },
    ],
};
sub column_run {
    require IPC::Run;
    require ShellQuote::Any::PERLANCAR;

    my %args = @_;
    #use DD; dd \%args;
    my $commands = delete $args{commands};
    my $common_command_args = delete($args{common_args}) // [];
    my $command_args_arrays = delete($args{args_arrays}) // [];
    my $common_envs = delete($args{common_envs}) // {};
    my $command_envs_arrays = delete($args{envs_arrays}) // [];

    Text::Column::Util::show_texts_in_columns(
        %args,
        num_columns => scalar @$commands,
        gen_texts => sub {
            my %gargs = @_;
            # start the programs and capture the output. for now we do this in a
            # simple way: one by one and grab the whole output. in the future we
            # might do this parallel and line-by-line.

            my %orig_env = %ENV;

            my $stdin = "";
            unless (-t STDIN) {
                local $/;
                $stdin = <STDIN>;
            }

            my @texts; # ([line1-from-cmd1, ...], [line1-from-cmd2, ...], ...)
            for my $i (0..$#{$commands}) {
                my $cmd = $commands->[$i];
                if (@$common_command_args) {
                    $cmd .= " " . ShellQuote::Any::PERLANCAR::shell_quote(@{ $common_command_args });
                }
                if ($command_args_arrays->[$i] && @{ $command_args_arrays->[$i] }) {
                    $cmd .= " " . ShellQuote::Any::PERLANCAR::shell_quote(@{ $command_args_arrays->[$i] });
                }
                log_trace "Command[%d]: %s", $i, $cmd;

                %ENV = %orig_env;
                $ENV{COLUMNS} = $gargs{column_width};
                $ENV{$_} = $common_envs->{$_} for keys %$common_envs;
                log_trace("Setting env for command[%d]: %s=%s", $i, $_, $common_envs->{$_}, $i) for keys %$common_envs;
                $ENV{$_} = $command_envs_arrays->[$i]{$_} for keys %{ $command_envs_arrays->[$i] // {} };
                log_trace("Setting env for command[%d]: %s=%s", $i, $_, $command_envs_arrays->[$i]{$_}) for keys %{ $command_envs_arrays->[$i] // {} };

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

            %ENV = %orig_env;

            \@texts;
        }, # _gen_texts
    );
}

1;
#ABSTRACT:

=head1 DESCRIPTION

Sample screenshots:

# IMAGE: share/images/Screenshot_20210625_085610.png

# IMAGE: share/images/Screenshot_20210625_094844.png


=head1 SEE ALSO

Terminal multiplexers: B<tmux>, B<screen>.

Terminal emulator with multiple tabs, e.g. B<Konsole>, B<GNOME Terminal>.

=cut
