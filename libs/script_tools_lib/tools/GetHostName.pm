package tools::GetHostName;
################################################################################
# Birth:    08/2025
# Last Mod: 08/2025
# Purpose: Helper tool for getting a host name on all platforms w/o having to use 
# "Sys::Hostname" 
################################################################################
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $VERSION);
use Exporter;

@ISA = qw(Exporter toolsLib);
@EXPORT = qw(&GetName &GetByIP);
$VERSION = '1.0';

use constant IS_WINDOWS => ($^O =~ /^(mswin)/oi);
use constant IS_CYGWIN  => ($^O =~ /^(cygwin)/oi);
use constant IS_LINUX   => ($^O =~ /^(linux)/oi);
use constant IS_SOLARIS => ($^O =~ /^(solaris)/oi);

################################################################################
# Create an Object
################################################################################
sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

################################################################################
# Get current hosts name and return it
################################################################################
sub GetName {
    my $hostName = `hostname`;
    return "Unknown_Host" unless defined $hostName;

    if (IS_SOLARIS || IS_LINUX) {
        if ($hostName =~ /has address/) {
            ($hostName) = split(/has address/, $hostName);
        }
    }

    return Trim($hostName);
}

################################################################################
# Try to get current hosts name by ip return it
################################################################################
sub GetByIP {
    my ($ip) = @_;
    return unless defined $ip;

    use Socket;  # Move this to the top of the file ideally
    my $packed_ip = inet_aton($ip);
    return unless $packed_ip;

    my $name = gethostbyaddr($packed_ip, AF_INET);
    return unless defined $name;

    $name = (split(/\./, $name))[0] if $name =~ /\./;
    return $name;
}


################################################################################
# Get rid of whitespace
################################################################################
sub Trim($){
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return($string);
}
1;