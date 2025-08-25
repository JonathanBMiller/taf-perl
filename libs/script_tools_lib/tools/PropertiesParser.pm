package PropertiesParser;
################################################################################
# Birth:    08/2025
# Last Mod: 08/2025
# Purpose: Helper tool to parse properties files using a hash of script 
# variables passed in.
################################################################################
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $VERSION);

@ISA = qw(Exporter);
@EXPORT = qw(&ParseProperties);
$VERSION = '1.0';

# Autobench tools include
use FindBin qw($Bin);
use lib 'lib';
use lib "$Bin"; 
require Properties;
require toolsLib;

our $debug  = 0;
our $propSearch = undef;

################################################################################
# Return Properties File Errors
################################################################################
sub ReturnError {
    my ($propertiesFile) = @_;
    print "ERROR: Unable to open or locate '$propertiesFile'\n" if $debug;
    return undef;
}

################################################################################
# Parse Properties File
################################################################################
sub ParseProperties {
    my $self           = shift;
    my $prefix         = shift;
    my $varList        = shift;
    my %listOfVars     = %$varList;
    my $propertiesFile = shift;

    # Check if file exists and open safely
    unless (-e $propertiesFile) {
        print "ERROR!!! $propertiesFile does not exist\n" if $debug;
        return undef;
    }

    open my $fh, '<', $propertiesFile or return ReturnError($propertiesFile);

    print "\n**********************************\n" .
          "Current file = $propertiesFile\n" .
          "**********************************\n\n" if $debug;

    # Load properties
    my $properties = Properties->new();
    $properties->load($fh);
    my %propertiesList = $properties->properties();

    # Walk through each expected variable
    VAR: foreach my $var (sort keys %listOfVars) {
        print "\nVariable = $var\n" if $debug;

        my $propSearch = defined $prefix ? "$prefix.$var" : $var;
        print "Search = $propSearch\n" if $debug;

        foreach my $prop (sort keys %propertiesList) {
            print "Property = $prop\n" if $debug;

            my $value = trimLite($propertiesList{$prop});
            next unless $prop eq $propSearch;

            if (lc($value) eq 'null') {
                print "\t NULL, skipping\n\n" if $debug;
                next VAR;
            }

            $listOfVars{$var} = lc($value) eq 'true'  ? 1
                              : lc($value) eq 'false' ? 0
                              : $value;

            if ($debug) {
                print "\tVariable = $var, Property Search = $prop :\n";
                print "\tpropertiesList{propSearch} = $value\n";
                print "\tlistOfVars{var} = $listOfVars{$var}\n\n";
            }

            next VAR;
        }
    }
    return \%listOfVars;
}
sub trimLite {
    my ($string) = @_;
    return '' unless defined $string;

    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}
1;