use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromString);
use feature qw(switch);
use Irssi;

our $VERSION = '1.00';
our %IRSSI = (
    authors     => 'Kamal Galrani',
    contact     => 'kamalgalrani@gmail.com',
    name        => 'Facebook Script',
    description => 'Description',
    license     => 'Public Domain',
    path        => '/home/singularity/.irssi/'
);
our %AUTH = (
    "100001114411312\@chat.facebook.com" => "Kamal Galrani"
);

sub bashify {
    my ( $server, $command, $nick, $timeout ) = @_;
    my $script = $IRSSI{'path'} . '.' . substr( $nick, 0, index( $nick, '@' ) ) . '_' . time();
    `echo "$command" > $script`;

    my $pid = fork();
    if (!$pid) {
        setpgrp(0,0);
        exec "bash $script | cat > $script.out";
    }
    else {
        local $SIG{ALRM} = sub { `kill -9 $pid`; `echo "\n_TIMEOUT\n" >> $script.out`;};
        alarm $timeout;
        `ln -s $script.out $IRSSI{'path'}$pid`;
        if ( $timeout > 5 ) { $server->command("MSG $nick To check progress, type /monitor $pid"); }
        waitpid( $pid, 0 );
        alarm 0;
        local $/ = undef;
        open FILE, "$script.out";
        binmode FILE;
        my $response = <FILE>;
        close FILE;
        $server->command("MSG $nick ($pid)\t$response");
        `rm $script`;
        `rm $script.out`;
        `rm $IRSSI{'path'}$pid`;
    }
}
sub event_privmsg {
    my ( $server, $data, $nick, $address ) = @_;
    $nick = substr $nick, 1;
    print "nick: $nick\n";
    if (exists $AUTH{$nick}) {
        my $timeout = 5;
        my ( $command, $stream ) = GetOptionsFromString($data,"timeout=i" => \$timeout );
        $command = @{$stream}[0];
        shift @{$stream};
        $stream = join( ' ', @{$stream} );
        given ( $command ) {
            when("exec") {
                $server->command('MSG ' . $nick . bashify( $server, $stream, $nick, $timeout ) );
                $stream =~ tr{\n}{;};
                my $log = localtime() . "\t" . $AUTH{$nick} . "\tSHELL\t$stream\n";
                print "$log";
                `echo "$log" >> /home/singularity/.irssi/mobileconnect.log`;
                return;
            }
            when("monitor") {
                $server->command('MSG ' . $nick . bashify( $server, "cat $IRSSI{'path'}$stream", $nick, 3 ) );
                return;
            }
            default {
                $server->command("MSG $nick Invalid Command!!!");
                return;
            }
        }
    }
    else {
        print "$nick\n";
        $server->command("MSG $nick Unauthorised Access!!!");
    }
}

Irssi::signal_add_last("message private", "event_privmsg")
