################################################################################
# Birth:    08/2025
# Last Mod: 08/2025
# Purpose:  Template for creating a test suite module
# Note:     Copy, rename, and customize this file for your own suite
################################################################################

use FindBin qw($Bin);
use warnings;
use Cwd;
use constant OK    => 0;
use constant ERROR => 1;
use constant TRUE  => 1;
use constant FALSE => 0;

#-----------------------------------------------------------------------------
# Global Configuration
#-----------------------------------------------------------------------------

our $TS_prefix        = "template";
our $TS_version       = 1;
our $TS_revision      = 0;
our $TS_defaults_file = $Bin."/properties/default/template_default.properties";

# Default options hash — customize as needed
our %tsOptions = (
    clean_args          => undef,
    client_args         => undef,
    client_executable   => undef,
    default_duration    => undef,
    load_args           => undef,
    source              => undef,
    test_client_version => undef,
);

#-----------------------------------------------------------------------------
# Test Suite private sub functions declaration
#-----------------------------------------------------------------------------
sub Hello;
sub Jeb;
sub OlesTest;
sub BigTest;

#-----------------------------------------------------------------------------
# Required AF Sub Functions
#-----------------------------------------------------------------------------

sub BuildClient {
    PrintVerbose("Template -> BuildClient Called");
    # Implement build logic here if needed for make, ant, etc...
    PrintVerbose("Template -> Building $tsOptions{source}");
    return OK;
}

#-----------------------------------------------------------------------------
sub GetDefaultTests {
    PrintVerbose("template -> GetDefaultTests called.");
    # This returns a list of default test case to be execute if no test(s)
    # were given in users properties or commandline.
    my @defaultTests = qw(HelloWorld JebsTest OlesTest);
    return \@defaultTests;
}

#-----------------------------------------------------------------------------
sub GetLegalTests {
    PrintVerbose("template -> GetLegalTests called.");
    # Return all known legal tests to validate ones passed in if
    # Test Suite strict is true
    # Legal could be same as default e.g. return GetDefaultTests();
    my @legalTests = qw(BigTest HelloWorld JebsTest OlesTest);
    return \@legalTests;
}

#-----------------------------------------------------------------------------
sub GetTestClientVersion {
    PrintVerbose("template -> GetTestClientVersion called.");
    # If client has version, should be listed in test suite's default properties.
    return %tsOptions{test_client_version};
}

#-----------------------------------------------------------------------------
sub GetTestDuration {
    PrintVerbose("template -> GetTestDuration called.");
    # If no duration for running test case(s) passed in by user properties or
    # command line, we use the default duration value from test suite's
    # default properties
    return %tsOptions{default_duration};
}

#-----------------------------------------------------------------------------
sub GetTestSuiteRevision {
    PrintVerbose("template -> GetTestSuiteRevision called.");
    return $TS_revision;
}

#-----------------------------------------------------------------------------
sub GetTestSuiteVersion{
    PrintVerbose("template -> GetTestSuiteVersion called.");
    return $TS_version;
}

#-----------------------------------------------------------------------------
sub GetThreads{
    PrintVerbose("template -> GetThreads called.");
    my $_test = shift;
    # Name of tests is passed in so that different tests can have different
    # threads returned.
    # This is default if none are passed in.
    my @_threads = qw(1 4 8 16 32 64 128 256);
    return \@_threads;
}

#-----------------------------------------------------------------------------
sub InstancesEnabled{
    PrintVerbose("template -> InstancesEnabled called.");
    # Can more than 1 instnace of client be running at one time?
    return FALSE;
}

#-----------------------------------------------------------------------------
sub MultiThreadEnabled{
    PrintVerbose("template -> MultiThreadEnabled called.");
    # Can the client handle more than 1 thread at a time?
    return TRUE;
}


#-----------------------------------------------------------------------------
sub PreTestSetup{
    # Code to be executed before the testing loops are started
    PrintVerbose("template -> PreTestSetup called.");
    return OK;
 }

#-----------------------------------------------------------------------------
sub StrictTestValidation{
    PrintVerbose("template -> StrictTestValidation called.");
    # If TRUE, tests passed in must match exactly all legal. 
    # Some test suite might have many test case, too many to have all
    # added.
    return TRUE;
}

#-----------------------------------------------------------------------------
sub TestCleanup(){
    PrintVerbose("template -> TestCleanup called.");
    # This function is used as testing completes. Finial cleanup etc.
    PrintVerbose($tsOptions{client_executable}." ".$tsOptions{clean_args});
    return OK;
}

#-----------------------------------------------------------------------------
sub TestPost(){
    PrintVerbose("template -> TestPost called.");
    # This function cleanup happens right after a run has completed.
    return OK;
}

#-----------------------------------------------------------------------------
sub TestRun(){
    PrintVerbose("template -> TestRun called.");
    # Here is the meat of the TSPM. This is what invokes and runs your test.
    my ($testCase, $threadCount) =  @_;
    print("test run threads = $threadCount\n");
    $testCase = lc($testCase);
    if($testCase eq "helloworld"){
        return Hello($threadCount);
    } elsif($testCase eq "jebstest"){
        return Jeb($threadCount);
    } elsif($testCase eq "olestest"){
        return OlesTest($threadCount);
    } elsif($testCase eq "bigtest"){
        return BigTest($threadCount);
    } else{
        # Should never get here since we are strict.
        PrintError("Unknown test: $testCase");
        return ERROR;
    }
}

#-----------------------------------------------------------------------------
sub TestSetup(){
    PrintVerbose("template -> TestRun TestSetup.");
    # Code to setup test case/test suite
    # Setup can happen every iteration, or just the first.
    PrintVerbose($tsOptions{client_executable}." ".$tsOptions{load_args});
    return OK;
}

#-----------------------------------------------------------------------------
sub TSParseProperty {
    PrintVerbose("TSParseProperty: Starting");
    my $users_properties = shift;
    # Parse defaults file
    PrintVerbose("TSParseProperty: Parsing defaults file -> $TS_defaults_file");
    my $returnedHash = ParsePropertyFile($TS_prefix, \%tsOptions, $TS_defaults_file);

    unless ($returnedHash && ref $returnedHash eq 'HASH') {
        PrintError("TSParseProperty: Failed to parse defaults file");
        return ERROR;
    }
    %tsOptions = %{$returnedHash};

    # Parse user property file if defined
    if (defined $users_properties) {
        PrintVerbose("TSParseProperty: Parsing user property file -> $users_properties");
        $returnedHash = ParsePropertyFile($TS_prefix, \%tsOptions, $users_properties);

        unless ($returnedHash && ref $returnedHash eq 'HASH') {
            PrintError("TSParseProperty: Failed to parse user property file");
            return ERROR;
        }
        %tsOptions = %{$returnedHash};
    }

    # Parse command-line overrides
    if (defined $options{test_suite_properties}) {
        PrintVerbose("TSParseProperty: Command-line options detected");
        for my $pair (split(',', $options{test_suite_properties})) {
            my ($key, $value) = split('=', $pair, 2);
            PrintVerbose("TSParseProperty: Overriding $key = $value");
            $tsOptions{$key} = $value;
        }
    }
    PrintTsOptions();
    PrintVerbose("TSParseProperty: Complete");
    return OK;
}

#-----------------------------------------------------------------------------
sub Help(){
    # Help should provide useful information to anyone wanting to use test suite
    PrintLine("=",78);
    Print("====================== Test Suite template HELP ===========================");
    PrintLine("=",78);
    Print("Contains following default tests");
    Print("---------------------------------");
    foreach(@{GetDefaultTests()}){
        Print("$_");
    }
    Print("---------------------------------");
    Print("Contains following legal tests");
    Print("---------------------------------");
    foreach(@{GetLegalTests()}){
        Print("$_");
    }
    PrintLine("=",78);
    Print("DEFAULTS:");
    foreach(sort keys %tsOptions){
        if(!defined $tsOptions{$_}){
            Print("$TS_property_prefix."."$_"."="."not defined");
        } else {
            Print("$TS_property_prefix."."$_"."="."$tsOptions{$_}");
        }
    }
    PrintLine("=",78);
    Print("================= Test Suite template HELP END===================");
    PrintLine("=",78);
}

############# Test suite's private sub functions ###############################

sub Hello{
    my $threads = shift;
    Print("Hellworld is running.... with ".$threads." threads");

    sleep($options{duration});

    return OK;
}

#-----------------------------------------------------------------------------
sub Jeb{
    my $threads = shift;
    Print("Jeb's Test is running.... with ".$threads." threads");

    sleep($options{duration});

    return OK;
}

#-----------------------------------------------------------------------------
sub OlesTest{
    my $threads = shift;
    Print("Ole's Test is running.... with ".$threads." threads but will fail");

    sleep($options{duration});

    return ERROR;
}

#-----------------------------------------------------------------------------
sub BigTest {
	my $threads = shift;
    Print("Big Test is running... with $threads threads");

    my $cmd = join ' ', $tsOptions{client_executable}, $tsOptions{client_args};
    #PrintVerbose($cmd);

    if ($options{instances} > 1) {
        for my $num (0 .. $options{instances} - 1) {
            my $msg = "Instance $num: $cmd";
            PrintVerbose($msg);
        }
    }

    sleep($options{duration});
    return OK;
}
#-----------------------------------------------------------------------------
sub PrintTsOptions {
    my ($label) = @_;
    $label ||= 'tsOptions';

    PrintVerbose("$label contents:");

    for my $key (sort keys %tsOptions) {
        my $val = defined $tsOptions{$key} ? $tsOptions{$key} : '<undef>';
        PrintVerbose("template -> $key => $val");
    }
}


# NOTE: Must end in true (i.e. 1;)
1;