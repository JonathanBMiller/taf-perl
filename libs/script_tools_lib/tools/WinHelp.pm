package tools::WinHelp;
################################################################################
# Birth:    08/2025
# Last Mod: 08/2025
# Purpose: To have tools that help with Windows when there are no quick solutions
################################################################################

use strict;
use Carp;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $VERSION);
use File::Path qw(rmtree mkpath);
use Exporter;
use IO::File;
use FindBin qw($Bin);
use lib 'lib';
use lib "$Bin/";
use RemoveDir;

@ISA = qw(Exporter);
@EXPORT = qw(&win_path);

$VERSION = '1.0';

use constant IS_WINDOWS => ($^O =~ /^(mswin)/oi);
use constant OK    => 0;
use constant ERROR => 1;

our $DEBUG = 0;
################################################################################
# Create an Object
################################################################################
sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub win_path{
    my $class = shift;
    my $path = shift;
    ($path) =~ tr!/!\\!;
    if($DEBUG){
        print "win_path = $path\n";
    }
    return($path);
}
1;
