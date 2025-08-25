package tools::Trim;
################################################################################
# Birth:    08/2025
# Last Mod: 08/2025
# Purpose: Tools to remove leading/trailing whitespace and optionally all spaces
################################################################################

use strict;
use warnings;
use Exporter 'import';

our $VERSION = '1.0';
our @EXPORT  = qw(trim trimLite);

################################################################################
# trim
# Removes leading/trailing whitespace and all internal spaces
################################################################################
sub trim {
    my ($string) = @_;
    return '' unless defined $string;

    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    $string =~ s/ //g;
    return $string;
}

################################################################################
# trimLite
# Removes only leading/trailing whitespace
################################################################################
sub trimLite {
    my ($string) = @_;
    return '' unless defined $string;

    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}
1;