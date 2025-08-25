package tools::IsNumeric;
################################################################################
# Birth:    08/2025
# Last Mod: 08/2025
# Purpose:  Tool to determine if argument is numeric or an IP address
################################################################################

use strict;
use warnings;
use Exporter 'import';
use Carp;

# Constants
use constant {
    TRUE  => 1,
    FALSE => 0,
};

# Exported symbols
our @EXPORT = qw(IsThisANumber IsThisAnIP);
our $VERSION = '1.3';
our $DEBUG   = 0;

################################################################################
# IsThisANumber
# Returns TRUE if input looks like a number (integer or float)
################################################################################
sub IsThisANumber {
    my ($value) = @_;
    return FALSE unless defined $value;

    # Match optional sign, digits, optional decimal, digits
    if ($value =~ /^[+-]?\d*\.?\d+$/) {
        return TRUE;
    }
    return FALSE;
}

################################################################################
# IsThisAnIP
# Returns TRUE if input looks like an IPv4 address
################################################################################
sub IsThisAnIP {
    my ($value) = @_;
    return FALSE unless defined $value;

    # Basic IPv4 pattern
    if ($value =~ /^(\d{1,3}\.){3}\d{1,3}$/) {
        return TRUE;
    }
    return FALSE;
}
1;