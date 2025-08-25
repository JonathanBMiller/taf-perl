###############################################################################
# Birth:      08/2025
# Last Mod:   08/2025
# Purpose:    Basic Testing Automation Framework
################################################################################
our $framework         = "taf-perl";
our $frameworkVersion  = "1";
our $frameworkRevision = "0";

#############################################################################
# Includes
#############################################################################
use strict;
use Getopt::Long;
use Cwd;
use File::Path;
use File::Copy;
use File::Spec;
use FindBin qw($Bin);
use Sys::Hostname;
use Carp;
use File::Basename;
use threads;
use List::Util qw(any);
use lib 'lib';
use lib $Bin."/libs/";
use lib $Bin."/libs/script_tools_lib/";
use lib $Bin."/libs/script_tools_lib/tools/";
use lib $Bin."/test_suites/";
use toolsLib;
require propertiesParser;

#############################################################################
# Globals Constants
#############################################################################
use constant OK         => 0;
use constant ERROR      => 1;
use constant KILLED     => 2;
use constant TRUE       => 1;
use constant FALSE      => 0;
use constant ZERO       => 0;
use constant IS_CYGWIN  => ($^O =~ /^(cygwin)/oi);
use constant IS_LINUX   => ($^O =~ /^(linux)/oi);
use constant IS_SOLARIS => ($^O =~ /^(solaris)/oi);
use constant IS_WINDOWS => ($^O =~ /^(mswin)/oi);
use constant MIN_PERL_THREAD_SUPPORTED => 5.016003;

#############################################################################
# Globals Variables
#############################################################################
our $commandLine = "perl ./taf.pl";
foreach my $arg (@ARGV){
    $commandLine .= " ".$arg;
}
our $originalCommandLine = $commandLine;

############################
# Perl Objects and loggers #
############################
our $dateObj      = toolsLib::GetDateObject();
our $logger       = undef; # used to hold logger object
our $readMeWriter = undef; # used to hold logger object

#############
# Date,time #
#############
our $startTime    = $dateObj->GetOrgStartTime();

####################
# Results and misc #
####################
our $msg = undef;
our $results            = OK;
our $returnCode         = OK;
our $runCount           = ZERO;
our $test               = undef;
our $testVariableValue  = undef;
our $thread             = ZERO;

####################
# Hashes && Arrays #
####################
our @warningsIssued    = ();
our @errorsIssued      = ();
our @tests             = ();
our @threads           = ();

# Action is what drives the script
our %action =
(
    "archive"         => "Used to acrhive run data",
    "run"             => "Used call RunTest directly",
    "setup"           => "Used to setup clients and backend",
    "setup-client"    => "Used to only setup clients ",
    "setup-backend"   => "Used to only setup backend",
    "setup-run"       => "Used to setup both client and backend, and to run test",
    "test_cleanup"    => "Used call Test Cleanup directly",
    "test_post"       => "Used call Test Post directly",
    "test_setup  "    => "Used call Test Setup directly"
);

# Directories
our %dirs =
(
    "current_archive_dir"    => undef,
    "results"                => undef,
    "test_suite_source_code" => $Bin."/client_source/",
    "test_suites"            => $Bin."/test_suites/",
    "working"                => $Bin
);

# Directories to init from properties
our @initOptDirs =
(
    "archive_path",
    "logs_dir",
    "results_root_dir",
 );

my $propDefaultDir = $dirs{working}."/properties/default/";
our %files =
(
    "default_taf_properties"        => $propDefaultDir."taf_default.properties",
    "read_me"                      => undef,
    "run_count"                    => $dirs{working}."/.run_count.txt",
    "run_logs"                     => undef,
    "test_lock"                    => $dirs{working}."/TAF.LOCK",
    "user_property"                => undef,
    "help_file"                    => $dirs{working}."/help/taf_usage.txt"
);

if(IS_WINDOWS){
    foreach my $key (keys %files) {
        next unless defined $files{$key};  # Skip undefined entries
        $files{$key} = ConvertPathsToWindows($files{$key});
    }
}

our %flags =
(
    "firstTimeInTestsLoop"         => TRUE,
    "intialSetupDone"              => FALSE,
    "initialTestSetupDone"         => FALSE,
    "testSuiteCapabilitiesChecked" => FALSE,
    "testsuiteLoaded"              => FALSE,
    "testsuiteSoruceBuilt"         => FALSE
);

our %testTypes =
(
    "adhoc"         => "All misc runs",
    "investigation" => "investigation runs",
    "production"    => "regular runs",
    "rerun"         => "regression verification runs",
    "release"       => "release testing"
);

# This hash holds all the options from property file or by command-line.
our %options =
(
    "action"                   => undef,
    "archive_host"             => undef,
    "archive_path"             => undef,  # What path to store the result files
    "comments"                 => undef,
    "do_test_setup_every_test" => undef,
    "duration"                 => undef,  # How long to run test. Note ts gives default if none is passed
    "environment_variables"    => undef,  # List of env var needing to be set
    "exit_if_test_lock_exists" => undef,  # Flag to exit if TEST.LOCK file already exists
    "host"                     => undef,  # The host running this test
    "instances"                => undef,  # Number of instances to spawn for ts that support instances
    "iterations"               => undef,  # Number of iterations to run the test(s)
    "logs_dir"                 => undef,  # The dir where to write the logs
    "pass"                     => undef,
    "results_root_dir"         => undef,  # Where the results dirs get created
    "skip_client_builds"       => undef,  # Skip building clients...
    "skip_test_cleanup"        => undef,  # Skip cleaning up test artifacts
    "skip_test_post"           => undef,  # Skip running test post
    "skip_test_setup"          => undef,
    "sleep_after_test_run"     => undef,  # Sleep x seconds after test run completes
    "sleep_after_test_setup"   => undef,  # Sleep x seconds after test setup completes
    "sleep_before_test_run"    => undef,  # Sleep x seconds before test run completes
    "test_suite"               => undef,  # What ts are we going to use? no defaults defined!
    "test_type"                => undef,
    "tests"                    => undef,  # Command-delimited list of tests to run
    "threads"                  => undef,  # Command-delimited list of threads to run
    "tmp_dir"                  => undef,  # The temp directory taf is to use
    "tools_debug"              => undef,  # Flag to turn on tools debug for those that support
    "verbose"                  => undef,  # Flag: print a bunch of junk/stuff to stdout
);

# Function legacy compatibility prototypes
sub TAFEnd;                        # Saves off log and makes sure TEST.LOCK is not left over
sub ArchiveRunLog;                # Archive run log
sub ArchiveResults;               # Archive all current sub results dirs
sub CallTestSuiteHelp;            # Small sub to help reuse code for for calling help
sub CheckForLegalTests;           # Ensures test entered on commandline is a legal test
sub CheckPerlVersion;             # As of this addition, perl 5.16 or greater is needed for supporting perl threading
sub CheckTestSuiteCapabilities;   # Here we do little test to ensure TS is capable of doing what is being asked.
sub ClientBuild;                  # Calls TS BuildClient to build test executables
sub ClientSetup;                  # Handles setting up the client executables
sub PreActionTasks;               # Handles all checks and setups before we invoke action
sub CompressArchiveAndMove;       # Handles compressing and move the archived results
sub CreateArchiveName;            # Creates a file name for archiving
sub CreateTestLock;               # Creates a file "TEST.LOCK" for testQueueManager.pl to use
sub EnsureDirectory;              # shorten test tools lib call
sub EnsureFrameworkSubDirs;       # Make sure taf sub dirs are inplace
sub EnsureTrailingPm;             # Ensures test suite names end in ".pm"
sub GetRunCount;                  # used for results subDirs
sub GetTestSuiteList;             # returns an array of the installed TS PMs
sub InitLogging;                  # Setup logger and print header
sub Interrupt;                    # Used to catch CTL-C
sub ListActions;                  # List all possible actions
sub ListSuites;                   # lists all installed suites
sub ListSuitesHelp;               # lists installed suites help()
sub ListTestTypes;                # list all test types
sub LoadTestSuite;                # Imports the TestSuite PerlModule
sub LoggerSetup;                  # Creates a logger object
sub Main;                         # Script driver
sub MainGetThreads;               # Used to return thread counts
sub MainGetTests;                 # Ensures we have tests to process, otherwise it ask ts for default list
sub MainTestCleanup;              # Calls test suite cleanup
sub MainTestPost;                 # Calls test suite post
sub MainTestRun;                  # 
sub MainTestSetup;                # Calls test suite setup
sub MakeResultsSubDir;            # Creates the $dirs{results} for current run
sub MoveArchive;                  # Move Archived results
sub ParsePropertyFile;            # Generic function for processing property files
sub PrintAllVariables;            # Prints all the vars to log and screen if verbose;
sub PrintHeader;                  # Pretty print log start and end of major sections
sub PrintVerbose;                 # Wrap $logger
sub PrintError;                   # Wrap $logger
sub PrintErrorArray;              # Prints out all error issues during run.
sub PrintFileContents;            # Prints whats in a file.
sub PrintWarning;                 # Wrap $logger
sub PrintWarningsArray;           # Print all the warning issued during run.
sub PrintLine;                    # Wrap $logger
sub Print;                        # Wrap $logger
sub PrintArray;                   # Wrap $logger
sub PrintVerbose;                 # Wrap $logger
sub PrintDumpDebugVerbose;        # Wrap $logger
sub PrintTestRunDetails;          # prints test details to the run.log
sub ProcessRequest;               # Collects args passed in and calls subs
sub QuickExit;                    # removes lock file and exits 0
sub RemoveFile;                   # Removes a single file
sub RunTests;                     # Excutes the test perl modules
sub SetEnvironmentVariables;      # allows user to set environment vars
sub SetupArrayVariables;          # populates arrays from lists passed in
sub SetupVariables;               # Set defaults for any not passed in on commandline
sub TrailingSlash;                # Make call to tools lib shorter
sub TurnOffRestore;               # Small function to turn of restore vars. Code reuse.
sub UnloadTestSuite;              # Remove module to keep from having name space issues
sub Usage;                        # Prints usage information
sub UsageError;                   # Prints usage error information
sub ValidateTestType;             # Validated test type.
sub WriteReadmeStart;             # create a readme about the test for xml writer
sub WriteReadmeEnd;               # finish readme.txt after test is done

#############################################################################
# MAIN
#############################################################################
# This calls the inital script driver
#############################################################################
Main;
#############################################################################
sub Main{
    # Setup to catch interrupts
    $SIG{'INT'}  = \&Interrupt;
    $SIG{'TERM'} = \&Interrupt;
    $SIG{'STOP'} = \&Interrupt;
    if(CreateTestLock == OK){
        TAFEnd(ProcessRequest());
    } else{
        Print("************************");
        Print("TAF-> Main -> CreateTestLock FAILED !!");
        Print("************************");
        TAFEnd(ERROR);
    }
}

#############################################################################
# Sub Functions
#############################################################################

#-----------------------------------------------------------------------------
# TAFEnd
#   Logs the end of the automation framework (TAF) run.
#   Reports elapsed time, errors, warnings, and key metadata.
#   Archives the run log.
#   Removes lock file.
#   Exits with the provided status code.
#-----------------------------------------------------------------------------
sub TAFEnd{
    my $end = SetTAFSectionMsg("TAFEnd");
    my $dateTime = $dateObj->GetDateTime();
    my $elapsed = $dateObj->FigureElapsedTimeFormated($startTime);
    my $errorsCount = @errorsIssued;
    PrintHeader("== STAGE: TAF END ===============================","=",71);
    PrintLine("*",71);
    PrintWarningsArray();
    PrintLine("*",71);
    PrintErrorArray();
    PrintLine("*",71); 
    PrintVerbose("Date: ".$dateTime);
    PrintVerbose("Original Commandline used: ".$originalCommandLine);
    PrintVerbose("User Properties File: ".$files{user_property});
    PrintVerbose("Last Archive Directory: ".$dirs{current_archive_dir});
    PrintVerbose("TAF Took ".$elapsed." to complete request(s)");
    PrintVerbose("TAF Exit Code: ".$_[0]);
    PrintLine("*",71);
    ArchiveRunLog();
    RemoveFile($files{test_lock});
    exit($_[0]);
}

#-----------------------------------------------------------------------------
# ArchiveRunLog:
#   Logs the end of the TAF process.
#   Summarizes warnings and errors.
#   Logs metadata like timestamps, command line, and file paths.
#   Archives the run log.
#   Removes a lock file.
#   Exits with the appropriate status code.
#-----------------------------------------------------------------------------
sub ArchiveRunLog{
    my $arl = SetTAFSectionMsg("ArchiveRunLog");
    PrintVerbose($arl."Called");

    if(defined $logger){
    	my $_logArchiveName = CreateArchiveName(".log");
        PrintVerbose($arl."Logs archive name = ".$_logArchiveName);
        # If we have an archive path we use it,
        if(defined $dirs{current_archive_dir} && -e $dirs{current_archive_dir}){
            $_logArchiveName = $dirs{current_archive_dir}.$_logArchiveName;
        } else {
            # else we leave the log in the logs directory and just rename it.
            $_logArchiveName = $options{logs_dir}.$_logArchiveName;
        }
        $logger->RenameLog($_logArchiveName);
        PrintVerbose($arl."Archived run log:");
        PrintVerbose($arl."".$_logArchiveName);
    }

    PrintVerbose($arl."Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# ArchiveResults
#   Counts subdirectories to determine if there's anything to archive.
#   Prepares the archive path and name.
#   Creates the archive directory locally if needed.
#   Compresses or moves the archive based on configuration.
#   Removes original result files after archiving.
#-----------------------------------------------------------------------------
sub ArchiveResults{
    my $ar = SetTAFSectionMsg("ArchiveResults");
    PrintVerbose($ar."Called");

    unless (toolsLib::DoesDirectoryExist($options{results_root_dir})) {
        PrintError($ar."Results directory not found!");
        PrintVerbose($ar."results_root_dir: ".$options{results_root_dir});
        return ERROR;
    }

    my $tmpCnt = toolsLib::DirCounter($options{results_root_dir});
    if ($tmpCnt <= ZERO) {
        PrintVerbose($ar."No directories found!");
        PrintVerbose($ar."Looking under ".$options{results_root_dir});
        PrintWarning($ar."Aborting request..");
        PrintVerbose($ar."Complete");
        return OK;
    }

    PrintVerbose($ar."Number of sub result directories to archive: ".$tmpCnt);
    $options{archive_path} = TrailingSlash($options{archive_path});

    if ($options{archive_host} eq "localhost") {
        return ERROR unless EnsureDirectory($options{archive_path}) == TRUE;
    }

    my $tmpName = CreateArchiveName;
    my $tmpPath = $options{archive_path}.$tmpName;
    $dirs{current_archive_dir} = TrailingSlash($tmpPath);
    PrintVerbose($ar."Archive directory: ".$dirs{current_archive_dir});

    if ($options{archive_host} eq "localhost" || $options{archive_host} eq "127.0.0.1") {
        PrintVerbose($ar."Creating archive directory.");
        return ERROR unless EnsureDirectory($dirs{current_archive_dir}) == TRUE;
    }

    if ($options{compress_archive}) {
        PrintVerbose($ar."Compressing results");
        return ERROR unless CompressArchiveAndMove($tmpName) == OK;
    } else {
        PrintVerbose($ar."Moving Archive");
        return ERROR unless MoveArchive() == OK;
    }

    return ERROR unless RemoveResultFiles() == OK;
    PrintVerbose($ar."Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# CheckForLegalTests
#   Validates each test in  against a list of legal tests from .
#   Supports a fallback mode via  that allows unknown tests with a warning.
#   Logs detailed debug and verbose messages.
#   Returns  if any test is invalid and strict validation is enabled.
#-----------------------------------------------------------------------------
sub CheckForLegalTests {
    my $cflt = SetTAFSectionMsg("CheckForLegalTests");
    PrintVerbose($cflt."Called");

    # Get legal tests and normalize to lowercase for fast lookup
    my $legal_tests_ref = main::GetLegalTests();
    my %legal_tests = map { lc($_) => 1 } @$legal_tests_ref;

    foreach my $testIn (@tests) {
        my $test_lc = lc($testIn);
        PrintVerbose($cflt."Checking if '$testIn' is a legal test");
        if (exists $legal_tests{$test_lc}) {
            PrintVerbose($cflt."'$testIn' found");
            next;
        }
        if (!main::StrictTestValidation()) {
            PrintWarning($cflt."Strict Test Validation = FALSE");
            PrintVerbose($cflt."Test '$testIn' unknown, good luck!!");
            next;
        }
        # Invalid test and strict validation is enabled
        PrintError($cflt."'$testIn' NOT FOUND!!");
        PrintVerbose($cflt."Legal tests for: ".$options{test_suite});
        PrintVerbose($_) for @$legal_tests_ref;
        return ERROR;
    }

    PrintVerbose("$cflt Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# CheckPerlVersion
#   Compares the current Perl version () against a minimum required version ().
#   Checks if any user options that require threading are enabled.
#   Logs warnings or errors accordingly.
#   Returns  if threading is required but unsupported; otherwise returns .
#-----------------------------------------------------------------------------
sub CheckPerlVersion {
    my $cpv = SetTAFSectionMsg("CheckPerlVersion");
    PrintVerbose($cpv."Called");

    my $mini = "Minimum version ".MIN_PERL_THREAD_SUPPORTED;
    my $install = "Installed version ".$];
    PrintVerbose($cpv."Checking revision and version");
    PrintVerbose($cpv."Perl version found = ".$install);
    if( $] < MIN_PERL_THREAD_SUPPORTED) {
        if($options{instances}){
            PrintVerbose($cpv."Perl threads required");
            PrintVerbose($msg);
            PrintVerbose($cpv."".$mini." is required for threads");
            PrintError($cpv."".$install." is current version.");
            PrintVerbose("Either use supported version, or remove usage of the listed options");
            return ERROR;
        }
        $msg = $cpv."Lower version found than required to support threads!";
        PrintWarning($msg);
        $msg = $cpv."There are no user options selected requiring threads";
        $msg .= " support. But issues could still arise.";
        PrintWarning($msg);
    }
    PrintVerbose($cpv."Complete, happy testing!");
    return OK;
}

#-----------------------------------------------------------------------------
# CheckTestSuiteCapabilities
#   Validates whether the test suite supports multiple instances.
#   Checks if threading is allowed and properly configured.
#   Verifies that a specified test variable description is supported.
#   Logs detailed diagnostics and returns  if any capability is unsupported.� 	Validates whether the test suite supports multiple instances.
#   Checks if threading is allowed and properly configured.
#   Verifies that a specified test variable description is supported.
#   Logs detailed diagnostics and returns  if any capability is unsupported.
#-----------------------------------------------------------------------------
sub CheckTestSuiteCapabilities {
    my $ctsc = SetTAFSectionMsg("CheckTestSuiteCapabilities -> ".$options{test_suite});
    PrintVerbose($ctsc."Called");

    # Instance support
    if ($options{instances}) {
        PrintVerbose($ctsc."Checking if Instances Enabled");
        unless (main::InstancesEnabled()) {
            PrintError($ctsc."does not support multiple instances.");
            return ERROR;
        }
    }

    # Threading support
    PrintVerbose($ctsc."Checking Threading Support");
    unless (main::MultiThreadEnabled()) {
        if (defined $options{threads} && $options{threads} ne "1") {
            PrintError($ctsc."Does not support threading");
            PrintVerbose($ctsc."Please set threads = 1");
            return ERROR;
        }
    }

    PrintVerbose($ctsc." Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# Client Builds is driver for building test suite clients source code
#-----------------------------------------------------------------------------
sub ClientBuild {
    my $cb = SetTAFSectionMsg("ClientBuild");
    PrintHeader("== STAGE: CLIENT SOURCE BUILDING ==================", "=", 71);

    return ERROR if main::BuildClient() != OK;

    PrintVerbose($cb."Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# Setup Clients
#-----------------------------------------------------------------------------
sub ClientSetup {
    my $cs = SetTAFSectionMsg("ClientSetup");
    PrintHeader("== STAGE: CLIENT SETUP ===========================", "=", 71);
  
    $dateObj->SetStartTime();
    my $setupStartTime = $dateObj->GetStartTime();

    unless (toolsLib::DoesDirectoryExist($dirs{test_suite_source_code})) {
        UsageError($cs."Directory check failed: $dirs{test_client_src}");
    }

    if (!$options{skip_client_builds}) {
        PrintVerbose($cs."Starting client builds...");

        if (ClientBuild() != OK) {
            my $elapsed = $dateObj->FigureElapsedTimeFormated($setupStartTime);
            PrintError($cs."ClientBuild Failed!");
            PrintVerbose($cs."Elapsed time: $elapsed");
            return ERROR;
        }
    } else {
        PrintVerbose($cs."'skip_client_builds' option detected");
        PrintVerbose($cs."Skipping client builds");
    }

    my $setupElapsed = $dateObj->FigureElapsedTimeFormated($setupStartTime);
    PrintVerbose($cs."Completed in: $setupElapsed");

    return OK;
}

#-----------------------------------------------------------------------------
# Compress and Move Archive
#-----------------------------------------------------------------------------
sub CompressArchiveAndMove {
    my $caam = SetTAFSectionMsg("CompressArchiveAndMove");
    PrintVerbose($caam."Called");

    my ($archiveBaseName) = @_;
    unless (defined $archiveBaseName && $archiveBaseName ne '') {
        PrintError($caam."Invalid archive name provided");
        return ERROR;
    }

    my $tmpFile = $archiveBaseName.".tgz";
    $options{tmp_dir} = TrailingSlash($options{tmp_dir});

    unless (EnsureDirectory($options{tmp_dir})) {
        PrintError($caam."EnsureDirectoryExists returned ERROR");
        PrintVerbose($caam."Please check directory: ".$options{tmp_dir});
        return ERROR;
    }

    my $compressFile = $options{tmp_dir} . $tmpFile;
    PrintVerbose($caam."Compressing to $compressFile");

    my $returnCode = toolsLib::Zipper(
        $options{results_root_dir},
        $compressFile,
        $options{tools_debug}
    );

    if ($returnCode != OK) {
        PrintError($caam."Zipper Failed");
        return ERROR;
    }

    unless (-e $compressFile) {
        PrintError($caam."$compressFile does not exist, please investigate");
        return ERROR;
    }

    if ($options{archive_host} eq "localhost" || $options{archive_host} eq "127.0.0.1") {
        $returnCode = toolsLib::MV(
            $compressFile,
            $dirs{current_archive_dir},
            $options{tools_debug}
        );
        if ($returnCode != OK) {
            PrintError($caam."MV Failed");
            return ERROR;
        }
        PrintVerbose($caam."Moved ".$compressFile." to ".$dirs{current_archive_dir});
    } else {
        PrintVerbose($caam."SCP archive to $options{user}\@$options{archive_host}:$options{archive_path}");
        $returnCode = toolsLib::SCopyTo(
            $compressFile,
            $options{user},
            $options{archive_host},
            $options{archive_path},
            $options{pass}
        );
        if ($returnCode != OK) {
            PrintError($caam."SCopyTo Failed");
            return ERROR;
        }
    }

    PrintVerbose($caam."Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# Create archive name
#-----------------------------------------------------------------------------
sub CreateArchiveName{
    my $_dateStamp     = $dateObj->GetFileDateStamp();
    my $_endFileName   = $_[0];
    my $_host          = GetHostName();
    my $_tmpArchiveName = undef;
    my $_action        = $options{action};
    #$_action =~ s/_/ /g;
    my $can = SetTAFSectionMsg("CreateArchiveName");
    PrintVerbose($can."Called");

    if(defined $options{host}){
        if(defined $options{test_suite}){
            $_tmpArchiveName = "${_host}_${options{test_suite}}_${_action}_${_dateStamp}${_endFileName}";
        } else {
            $_tmpArchiveName = "${_host}_${_action}_${_dateStamp}${_endFileName}";
       }
    } elsif(defined $options{test_suite}) {
        $_tmpArchiveName = "UNKNOWN_HOST_${options{test_suite}}_${_action}_${_dateStamp}${_endFileName}";
    } else {
        $_tmpArchiveName = "UNKNOWN_HOST_${_action}_${_dateStamp}${_endFileName}";
    }

    if($results != OK){
        if($results == ERROR){
            $_tmpArchiveName = "Error_".$_tmpArchiveName;
        } elsif($results == KILLED) {
            $_tmpArchiveName = "Killed_".$_tmpArchiveName;
        }
    }

    PrintVerbose($can."Archive name = ".$_tmpArchiveName);

    PrintVerbose($can."Complete");
    return($_tmpArchiveName);
}

#-----------------------------------------------------------------------------
# Procress the requested testing.
#-----------------------------------------------------------------------------
sub ProcessRequest {
    SetTAFSectionMsg("ProcessRequest");
    my %tmpoptions = InitTempOptions();
    my %flags;
    ParseCommandLineOptions(\%tmpoptions, \%flags);
    HandleInfoFlags(\%flags) if HandleInfoFlags(\%flags);
    return ERROR if LoadDefaultProperties() != OK;
    return ERROR if LoadUserProperties()    != OK;
    ApplyOverrides(\%tmpoptions);
    PrintVerbose("******************************");
    PrintVerbose("Automation Framework starting.");
    PrintVerbose("Processing request");
    PrintVerbose("******************************");
    return ERROR if ValidateTestSuite()     != OK;
    return ERROR if PreActionTasks()        != OK;
    return DispatchAction($options{action});
}

#-----------------------------------------------------------------------------
sub InitTempOptions {
    return map { $_ => undef } keys %options;
}

#-----------------------------------------------------------------------------
sub ParseCommandLineOptions {
    my ($tmp_ref, $flags_ref) = @_;

    GetOptions(
        "action:s"                    => \$tmp_ref->{action},
        "comments:s"                  => \$tmp_ref->{comments},
        "environment-variables:s"     => \$tmp_ref->{environment_variables},
        "exit-if-test-lock-exists"    => \$tmp_ref->{exit_if_test_lock_exists},
        "host:s"                      => \$tmp_ref->{host},
        "instances:i"                 => \$tmp_ref->{instances},
        "iterations:i"                => \$tmp_ref->{iterations},
        "logs-dir:s"                  => \$tmp_ref->{logs_dir},
        "property-file:s"             => \$files{user_property},
        "sleep-before-test-run:i"     => \$tmp_ref->{sleep_before_test_run},
        "skip-test-cleanup"           => \$tmp_ref->{skip_test_cleanup},
        "skip-test-post"              => \$tmp_ref->{skip_test_post},
        "skip-test-setup"             => \$tmp_ref->{skip_test_setup},
        "test-suite:s"                => \$tmp_ref->{test_suite},
        "test-type:s"                 => \$tmp_ref->{test_type},
        "tests:s"                     => \$tmp_ref->{tests},
        "threads:s"                   => \$tmp_ref->{threads},
        "tmp-dir:s"                   => \$tmp_ref->{tmp_dir},
        "tools-debug"                 => \$tmp_ref->{tools_debug},
        "verbose"                     => \$tmp_ref->{verbose},
        "duration:s"                  => \$tmp_ref->{duration},
        # Info flags
        "help"                        => \$flags_ref->{help},
        "list-actions"                => \$flags_ref->{list_actions},
        "list-test-suites"            => \$flags_ref->{list_suites},
        "list-test-suites-help"       => \$flags_ref->{list_suites_help},
        "list-test-types"             => \$flags_ref->{list_test_types},
        "version"                     => \$flags_ref->{list_version}
    ) || UsageError("Check for mistake in option spelling");
    if ($tmp_ref->{verbose}){$options{verbose} = $tmp_ref->{verbose};}
    if(IS_WINDOWS){
        if(defined $tmp_ref->{logs_dir}){
           $tmp_ref->{logs_dir} = ConvertPathsToWindows($tmp_ref->{logs_dir});
        }
        if(defined $tmp_ref->{user_property}){
            $tmp_ref->{$files{user_property}} =
                ConvertPathsToWindows($files{user_property});
        }
        if(defined $tmp_ref->{tmp_dir}){
        $tmp_ref->{$files{tmp_dir}} = 
            ConvertPathsToWindows($tmp_ref->{$files{tmp_dir}});
        }
    }
}

#-----------------------------------------------------------------------------
sub LoadDefaultProperties {
        print("here $files{default_taf_properties}\n");
    return ERROR unless -e $files{default_taf_properties};

    my $hash = ParsePropertyFile("taf", \%options, $files{default_taf_properties});
    return ERROR if $hash == ERROR;
    %options = (%options, %{$hash});
    return OK;
}

#-----------------------------------------------------------------------------
sub LoadUserProperties {
    return OK unless defined $files{user_property} && -e $files{user_property};
 
    my $hash = ParsePropertyFile("taf", \%options, $files{user_property});
    return ERROR if $hash == ERROR;
    %options = (%options, %{$hash});

    open(my $fh, "<", $files{user_property}) or return ERROR;
    my @lines = <$fh>;
    close($fh);
    $commandLine .= " :: prop file contents -> ";
    foreach my $line (@lines) {
        next if $line =~ /#/;
        chomp($line);
        $commandLine .= " $line";
    }
    return OK;
}

#-----------------------------------------------------------------------------
sub ApplyOverrides {
    my ($tmp_ref) = @_;
    foreach my $key (sort keys %{$tmp_ref}) {
        $options{$key} = $tmp_ref->{$key} if defined $tmp_ref->{$key};
    }
}

#-----------------------------------------------------------------------------
sub HandleInfoFlags {
    my ($flags_ref) = @_;

    if ($flags_ref->{list_version}) {
        PrintVerbose("TAF version: $frameworkVersion.$frameworkRevision");
        QuickExit();
    }
    Usage()         if $flags_ref->{help};
    ListSuites()    if $flags_ref->{list_suites};
    ListTestTypes() if $flags_ref->{list_test_types};
    ListActions()   if $flags_ref->{list_actions};
    ListSuitesHelp()if $flags_ref->{list_suites_help};
}

#-----------------------------------------------------------------------------
sub ValidateTestSuite {
    return LoadTestSuite($options{test_suite});
}

#-----------------------------------------------------------------------------
sub DispatchAction {
    my ($action) = @_;
    my %dispatch = (
        archive        => \&ArchiveResults,
        run            => \&RunTests,
        setup          => sub {
            return ERROR if ClientSetup() != OK;
            return BackendSetup();
        },
        setup_client   => \&ClientSetup,
        setup_backend  => \&BackendSetup,
        setup_run      => sub {
            return ERROR if ClientSetup() != OK;
            return ERROR if BackendSetup() != OK;
            return RunTests();
        },
        test_cleanup   => \&MainTestCleanup,
        test_post      => \&MainTestPost,
        test_setup     => \&MainTestSetup,
    );

    if (exists $dispatch{$action}) {
        return $dispatch{$action}->();
    } else {
        UsageError("Action '$action' not found");
    }
}

#-----------------------------------------------------------------------------
# Setup and checks to perform before invoking action
#-----------------------------------------------------------------------------
sub PreActionTasks{
    my $pt = SetTAFSectionMsg("PreActionTasks");
    PrintVerbose($pt."Start...");
    return ERROR if CheckPerlVersion() != OK;
    SetEnvironmentVariables();
    return ERROR if SetupVariables() != OK;
    ValidateTestType();
    return ERROR if EnsureFrameworkSubDirs() != OK;
    InitLogging();
    SetupArrayVariables();
    PrintAllVariables();
    PrintVerbose($pt."Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# Create the test lock file
#-----------------------------------------------------------------------------
sub CreateTestLock{
	my $ctl = SetTAFSectionMsg("CreateTestLock");
    PrintVerbose($ctl."Start");

    if(-e $files{test_lock}){
        if($options{exit_if_test_lock_exists}){
            PrintError("LOCK File already exists... ".$files{test_lock});
            PrintVerbose("exit_if_test_lock_exists = true");
            return ERROR;
        } else {
            PrintWarning("LOCK File already exists... ".$files{test_lock});
            PrintVerbose("exit_if_test_lock_exists = false");
            PrintVerbose("Running mutiple instances of TAF is not supported");
            PrintVerbose("Overwritting ".$files{test_lock}.", good luck!");
        }
    }

    open FILE, ">$files{test_lock}" || return ERROR;
    print FILE $commandLine;
    close(FILE);
    
    PrintVerbose($ctl."Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# Ensure Framework Sub Directories are in place
#-----------------------------------------------------------------------------
sub EnsureFrameworkSubDirs{
    my $efsd = SetTAFSectionMsg("EnsureFrameworkSubDirs");
    PrintVerbose($efsd."Start");
    #use Data::Dumper;
    #print Dumper(\@initOptDirs);
    
    foreach (@initOptDirs){
        if(defined $options{$_}){
            PrintVerbose($efsd."Current directory key ".$_);
            PrintVerbose($efsd."Current directory target ".$options{$_});
            $options{$_} = TrailingSlash($options{$_});
            if (!EnsureDirectory($options{$_})){
                PrintError($efsd."EnsureDirectoryExists failed!");
                return ERROR;
            }
        }
    }

    PrintVerbose($efsd."Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# Handling .pm
#-----------------------------------------------------------------------------
sub EnsureTrailingPm {
    my ($filename) = @_;
    return ($filename =~ /\.pm$/i) ? $filename : "${filename}.pm";
}

sub RemoveTrailingPm {
    my ($filename) = @_;
    $filename =~ s/\.pm$//i;  # Strip trailing .pm (case-insensitive)
    return $filename;
}

#-----------------------------------------------------------------------------
# Returns a list of the test suites
#-----------------------------------------------------------------------------
sub GetTestSuiteList {
    my @list;

    my $dir = $dirs{test_suites};

    unless (-d $dir) {
        PrintError("Directory not found: $dir");
        return ();
    }

    opendir(my $dh, $dir) or do {
        PrintError("Failed to open directory: $dir");
        return ();
    };

    while (my $file = readdir($dh)) {
        next if $file =~ /^\.\.?$/;     # Skip . and ..
        next unless $file =~ /\.pm$/i;  # Match .pm files (case-insensitive)
        push @list, $file;
    }

    closedir($dh);
    return sort @list;
}

#-----------------------------------------------------------------------------
# Run count is used for creating results sub directories
#-----------------------------------------------------------------------------
sub GetRunCount {
    my $grc = SetTAFSectionMsg("GetRunCount");
    PrintVerbose($grc."Called");

    my $runCount;

    if (-e $files{run_count}) {
        PrintVerbose($grc."$files{run_count} exists");
        open(my $fh, '<', $files{run_count}) or do {
            PrintError($grc."Failed to read $files{run_count}: $!");
            return ERROR;
        };
        while (<$fh>) {
            chomp;
            $_ =~ s/\D//g;
            $runCount = $_;
        }
        close($fh);
    } else {
        PrintWarning($grc."Run count file not found!");
        PrintVerbose($grc."Assuming new install, creating file.");
    }

    if (defined $runCount && $runCount ne '') {
        PrintVerbose($grc."Current run count: $runCount");
        $runCount++;
    } else {
        $runCount = 1;
        PrintVerbose($grc."New installation detected, count = $runCount");
    }

    PrintVerbose($grc."Writing run count to $files{run_count}");
    open(my $fh, '>', $files{run_count}) or do {
        PrintError($grc."Failed to write to $files{run_count}: $!");
        return ERROR;
    };
    print $fh "$runCount";
    close($fh);

    PrintVerbose($grc."Run count $runCount written to $files{run_count}");
    PrintVerbose($grc."Complete");

    return $runCount;
}

#-----------------------------------------------------------------------------
# Host Name
#-----------------------------------------------------------------------------
sub GetHostName{
    my $_host = $options{host};
    if(defined $_host){
        if($_host eq 'localhost' ||  $_host eq '127.0.0.1'){
           $_host = hostname();
        }
    }
    return $_host;
}

#-----------------------------------------------------------------------------
# Handles Interrupt
#-----------------------------------------------------------------------------
sub Interrupt{
    PrintWarning("TAF Interrupt: Caught CTL-C, doing clean up");
    TAFEnd(KILLED);
}

#-----------------------------------------------------------------------------
# List help
#-----------------------------------------------------------------------------
sub ListActions {
    Print("\n\t--action= must contain one of the following");
    Print("\t--------------------------");

    foreach my $type (sort keys %action) {
        Print("\t$type : $action{$type}");
    }

    Print("\t--------------------------");
    Print("\tUse --help for a complete listing of help options");
    Print("\t--------------------------");

    QuickExit;
}

#-----------------------------------------------------------------------------
sub ListSuites {
    my @testSuiteList = GetTestSuiteList();

    Print("\n\tSuites currently installed");
    Print("\t---------------------------------");

    foreach my $suite (@testSuiteList) {
        my ($tmpSuite) = $suite =~ /(.*)\.pm$/;
        Print("\t$tmpSuite");
        Print("\t---------------------------------");

        LoadTestSuite($suite);

        my $defaultTests = main::GetDefaultTests();
        if (@$defaultTests) {
            Print("\tContains following default tests");
            Print("\t---------------------------------");
            foreach my $test (@$defaultTests) {
                Print("\t$test");
            }
        }

        my $legalTests = main::GetLegalTests();
        if (@$legalTests) {
            Print("\t---------------------------------");
            Print("\tContains following legal tests");
            Print("\t---------------------------------");
            foreach my $test (@$legalTests) {
                Print("\t$test");
            }
        }
        UnloadTestSuite($suite);
    }
    QuickExit;
}

#-----------------------------------------------------------------------------
sub ListSuitesHelp{
    my @testSuiteList = GetTestSuiteList;
    if(!defined $options{test_suite}){
        foreach(@testSuiteList){
            PrintTestSuiteHelp($_);
         }
    } else{
        $options{test_suite} = EnsureTrailingPm($options{test_suite});
        my $_found = FALSE;
        foreach(@testSuiteList){
            if(lc($options{test_suite}) eq lc($_)){
                PrintTestSuiteHelp($_);
                $_found = TRUE;
             }
        }
        if(!$_found){
            print("Error: Test Suite ".$options{test_suite}." not found");
        }
    }
    QuickExit;
}

#-----------------------------------------------------------------------------
sub ListTestTypes {
    Print("\nThe following types may be used with --test-type=<type>");
    Print("\t-----------------------------");

    if (!%testTypes) {
        Print("\tNo test types are currently defined.");
        QuickExit;
    }

    foreach my $key (sort keys %testTypes) {
        Print("\t\"$key\" used for $testTypes{$key}");
    }

    Print("\nNote: This information is only used by the results database");
    Print(" and has no effect on actual test execution.\n");

    QuickExit;
}

#-----------------------------------------------------------------------------
# Get thread count(s)
#-----------------------------------------------------------------------------
sub MainGetThreads {
    my $mgth = SetTAFSectionMsg("MainGetThreads");
    PrintVerbose($mgth."Starting");

    if (@threads) {
        PrintVerbose($mgth."Thread count(s) given via command-line/properties.");
    } else {
        PrintWarning($mgth."Threads not given on command-line.");
        my $suite = $options{test_suite} // 'unknown';
        PrintVerbose($mgth."Getting them from $suite");

        my $tmpGetThreads = main::GetThreads($test);
        if (defined $tmpGetThreads && ref($tmpGetThreads) eq 'ARRAY') {
            foreach my $item (@$tmpGetThreads) {
                PrintVerbose($mgth."Adding Thread Count $item to the threads array");
                push(@threads, $item);
            }
        } else {
            PrintWarning($mgth."Failed to retrieve threads from test suite.");
        }
    }
    PrintVerbose($mgth."Threads: ".join(", ", @threads));

    PrintVerbose($mgth."Complete");
}

#-----------------------------------------------------------------------------
# Get tests
#-----------------------------------------------------------------------------
sub MainGetTests{
    my $mgt = SetTAFSectionMsg("MainGetTests");
    PrintVerbose($mgt."Starting");

    if(@tests){
        PrintVerbose($mgt."The following tests where given on the commandline.");
        PrintVerbose($mgt."Tests: ".join(", ", @tests));
        return ERROR if CheckForLegalTests() != OK;
    } else{
        PrintWarning($mgt."Test(s) not given on command-line or property file");
        PrintVerbose($mgt."Getting default tests from ".$options{test_suite});
        my $tmpGetTests = main::GetDefaultTests();
        if (defined $tmpGetTests && ref($tmpGetTests) eq 'ARRAY') {
            foreach (@$tmpGetTests) {
                push(@tests, $_);
                PrintVerbose($mgt."Added test $_");
            }
        } else {
            PrintError($mgt."GetDefaultTests returned invalid data.");
            return ERROR;
       }
    }

    PrintVerbose($mgt."Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# Call test suite TestCleanup
#-----------------------------------------------------------------------------
sub MainTestCleanup {
    my $mtc = SetTAFSectionMsg("MainTestCleanup");
    PrintHeader("== STAGE: TEST CLEAN UP ==========================", "=", 71);
    PrintVerbose($mtc."Starting");

    # Check if cleanup should be skipped
    if ($options{skip_test_cleanup}) {
        PrintVerbose($mtc."Skip flag = true, skipping...");
        PrintVerbose($mtc." Complete");
        return OK;
    }

    # Run cleanup and check for errors
    if (main::TestCleanup() != OK) {
        PrintError($mtc."$options{test_suite} clean up returned an error");
        return ERROR;
    }

    PrintVerbose($mtc." Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# Call ts TestPost
#-----------------------------------------------------------------------------
sub MainTestPost {
    my ($iter,$thread) = @_;
    my $mtp= SetTAFSectionMsg("MainTestPost");
    $mtp .= " $test -> Thread(s): $thread -> Iter: $iter -> ";

    PrintHeader("== STAGE: TEST POST ==============================", "=", 71);
    PrintVerbose($mtp."Starting");

    # Check if post-processing should be skipped
    if ($options{skip_test_post}) {
        PrintVerbose($mtp."Skip Test Post detected.");
        PrintVerbose($mtp."Complete");
        return OK;
    }

    # Run post-processing and check for errors
    if (main::TestPost() != OK) {
        PrintError($mtp."TestPost() returned an error");
        return ERROR;
    }

    # Log completion
    PrintVerbose($mtp."Complete");
    PrintLine("=", 71);

    return OK;
}

#-----------------------------------------------------------------------------
# Main Test Run, calls Test Run in the test suite.
# � Logging and setup
# � Sleep delays before and after the test
# � Execution of the test suite
# � Error handling and cleanup
# � Final reporting
#-----------------------------------------------------------------------------
sub MainTestRun {
    my ($test,$iter,$thread) = @_;
    my $mtr = SetTAFSectionMsg("MainTestRun");
    $mtr .= "$test -> Thread(s): $thread -> Iter: $iter -> ";

    my $mainTestRunTime = $dateObj->GetStartTime();
    PrintHeader("== STAGE: MAIN TEST RUN ==========================", "=", 71);

    PrintVerbose("$mtr Starting test run's readme.txt");
    WriteReadmeStart($iter,$thread,$test);
    PrintTestRunDetails($test,$iter,$thread);

    PrintHeader("== STAGE: RUN ====================================", "=", 71);
    PrintVerbose($mtr."Sleep before, sleeping for $options{sleep_before_test_run} seconds");
    sleep($options{sleep_before_test_run});

    my $msg = "Calling $options{test_suite} TestRun($test,$thread)";
    PrintVerbose($mtr."$msg");

    my $dateTime = $dateObj->GetDateTime();
    PrintVerbose($mtr."Start date & time $dateTime");

    my $runStart = $dateObj->GetStartTime();
    my $returnCode = main::TestRun($test,$thread);
    my $runDuration = $dateObj->FigureElapsedTimeSeconds($runStart);

    if ($returnCode != OK) {
        PrintError($mtr."$options{test_suite} returned an error, trying to do clean up");
        PrintVerbose($mtr."Test ran for $runDuration (seconds) before failure");
        WriteReadmeEnd($runDuration);
        return ERROR;
    }

    WriteReadmeEnd($runDuration);
    SleepWithLog("sleep_after_test_run",$options{sleep_after_test_run});
    my $formattedElapsed = $dateObj->FigureElapsedTimeFormated($mainTestRunTime);
    $dateTime = $dateObj->GetDateTime();
    PrintVerbose(sprintf("TestRun completed in: %d seconds", $runDuration));
    PrintVerbose(sprintf("Elapsed time:         %s", $formattedElapsed));
    PrintVerbose(sprintf("RUN Complete:         %s", $dateTime));

    return OK;
}

#-----------------------------------------------------------------------------
# Call test suite's TestSetup
#-----------------------------------------------------------------------------
sub MainTestSetup {
    my ($iter,$thread) = @_;
    my $mts = SetTAFSectionMsg("MainTestSetup");
    $mts .= "$test -> Thread(s): $thread -> Iter: $iter -> ";
    PrintHeader("== STAGE: TEST SETUP =============================", "=", 71);
    PrintVerbose($mts."Starting");

    my $startTime = $dateObj->GetStartTime();
    my $startDateTime = $dateObj->GetDateTime();
    PrintVerbose(sprintf("%sStart date/time: %s", $mts, $startDateTime));

    my $returnCode = main::TestSetup($test, $dirs{results});
    if ($returnCode != OK) {
        PrintError($mts."TestSetup() failed for test '$test' with results dir '$dirs{results}'");
        return ERROR;
    }

    my $elapsedTime = $dateObj->FigureElapsedTimeSeconds($startTime);
    my $endDateTime = $dateObj->GetDateTime();

    SleepWithLog("sleep_after_test_setup",$options{sleep_after_test_setup});

    PrintVerbose(sprintf("%sEnd date/time:   %s", $mts, $endDateTime));
    PrintVerbose(sprintf("%sDuration:        %d seconds", $mts, $elapsedTime));
    PrintVerbose($mts."Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# Import test suites 
#-----------------------------------------------------------------------------
sub LoadTestSuite{
    my ($suiteName) = @_;
    my $ltspm = SetTAFSectionMsg("LoadTestSuite");
    unless (defined $suiteName) {
        PrintError("$ltspm test_suite not defined");
        return ERROR;
    }
    PrintVerbose($ltspm."Called");
    my $testLib = lc(EnsureTrailingPm($_[0]));
    my $testLibFullPath = $dirs{test_suites}.$testLib;
    if(-e $testLibFullPath){
        PrintVerbose($ltspm."Attempting to load test suite ".$testLib."...");
        require $testLib;
        import $testLib;
        PrintVerbose($ltspm."Imported...");
        $flags{tsmpLoaded} = TRUE;
    } else{
        PrintError($ltspm."Path ".$testLibFullPath." not found, check args");
        return ERROR;
    }
    if(main::TSParseProperty($files{user_property}) != OK){
        PrintError($ltspm."TSParseProperty Failed!");
        return ERROR;
    }
    PrintVerbose($ltspm."Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# Logger Object Setup
#-----------------------------------------------------------------------------
sub LoggerSetup {
    my $logFile = shift;

    unless (defined $logFile) {
        PrintError("LoggerSetup called without a log file path");
        return undef;
    }

    return toolsLib::GetLogger($logFile);
}

#-----------------------------------------------------------------------------
# Make a sub directory for current results
#-----------------------------------------------------------------------------
sub MakeResultsSubDir {
	my ($iter,$thread,$test) = @_;
    my $mrsd = SetTAFSectionMsg("MakeResultsSubDir");
    PrintVerbose("$mrsd Called");

    my $runCount = GetRunCount();
    my $_host = GetHostName();
    $_host = "UNKNOWN_SERVER" unless defined $_host;

    # Validate required options
    foreach my $key (qw(results_root_dir test_suite)) {
        unless (defined $options{$key}) {
            PrintError("$mrsd Missing required option: $key");
            return ERROR;
        }
    }

    # Construct results directory path
    $dirs{results} = join('_',
        $options{results_root_dir} . $_host,
        $options{test_suite},
        $test,
        $runCount,
        $iter,
        $thread
    );

    PrintVerbose("$mrsd Attempting to create results dir:");
    PrintVerbose("$mrsd $dirs{results}");

    return ERROR unless EnsureDirectory($dirs{results});

    $dirs{results} = TrailingSlash($dirs{results});
    PrintVerbose("$mrsd Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# Property File Parsing
#-----------------------------------------------------------------------------
sub ParsePropertyFile {
    my $ppf = SetTAFSectionMsg("ParsePropertyFile");
    # Parameters
    my ($prefix, $hashRef, $filePath) = @_;
    PrintVerbose("$ppf Parsing $filePath for prefix $prefix");
    if (-e $filePath) {
        my $returnedHash =
            PropertiesParser->ParseProperties($prefix, $hashRef, $filePath);
         if (defined $returnedHash) {
            return $returnedHash;  # Already a hash reference
        } else {
            PrintError("$ppf Issues processing $filePath");
        }
    } else {
        PrintError("$ppf $filePath does not exist");
    }
    return ERROR;
}

#-----------------------------------------------------------------------------
# Remove subs
#-----------------------------------------------------------------------------
sub RemoveFile {
    my $rf   = SetTAFSectionMsg("RemoveFile");
    my $file = $_[0];

    PrintVerbose($rf."Called to remove $file");

    if (-e $file) {
        if (unlink($file)) {
            PrintVerbose($rf."File has been removed");
        } else {
            PrintError($rf."Failed to remove file: $file ($!)");
        }
    } else {
        PrintVerbose($rf."File does NOT exist, nothing to do.");
    }

    PrintVerbose($rf."Complete");
}

#-----------------------------------------------------------------------------
sub RemoveResultFiles {
    my $rrf = SetTAFSectionMsg("RemoveResultFiles");
    PrintVerbose("$rrf Called");

    my $returnCode = toolsLib::RemoveSubTree($options{"results_root_dir"});
    if ($returnCode != OK) {
        PrintError("$rrf RemoveSubTree($options{'results_root_dir'}) Failed");
        return ERROR;
    }

    PrintVerbose("$rrf Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# Run test case
#-----------------------------------------------------------------------------
sub RunTests{
    my $rth = SetTAFSectionMsg("RunTests");
    # There are 3 loops in this function
    # 1) Test Case looping
    # 2) Thread count looping
    # 3) Iteration looping
    my $testTime = ZERO;
    PrintHeader("== STAGE: RUN TESTS ===============================","=",71);
    PrintVerbose($rth."TestSuite = ".$options{test_suite});

    return ERROR if MainGetTests() != OK;

    PrintHeader("== STAGE: PRE TEST SETUP =========================","=",71);
    return ERROR if main::PreTestSetup() != OK;
    PrintVerbose("STAGE: PRE TEST SETUP Complete");

    # TEST LOOP START
    foreach my $test(@tests){
        if($options{do_test_setup_every_test}){
            $flags{initialTestSetupDone} = FALSE;
        }
        my $_tmpHeader = $rth.$test." -> ";
        PrintHeader("== STAGE: TEST LOOP STARTING =====================","=",71);
        my $tmpCurrentRows = ZERO;
        MainGetThreads;
        $testTime = $dateObj->GetStartTime();
        foreach my $thread (@threads){
            PrintVerbose($_tmpHeader."Starting Threads loop");
            PrintVerbose($_tmpHeader."Looping for ".$thread." threads..");
            for(my $iter = 1; $iter < $options{iterations}+1; $iter++){
                my $loopHeader = $_tmpHeader."Thread(s): ".$thread." -> Iter: ";
                 $loopHeader .= $iter." -> ";
                 my $msg = $loopHeader." Starting loop for ".$iter." of ";
                 $msg .= $options{iterations}." iterations";
                 PrintVerbose($msg);
                 PrintVerbose($loopHeader." Creating results directory.");
                 if(MakeResultsSubDir($iter,$thread,$test) != OK){
                     PrintError($loopHeader."MakeResultsSubDir returned an error");
                     PrintVerbose($loopHeader."Failed trying to create ".$dirs{results});
                     return ERROR;
                 }
                 PrintVerbose($loopHeader." TEST SETUP");
                 if(!$options{skip_test_setup}){
                     if($flags{firstTimeInTestsLoop} && !$flags{initialTestSetupDone}){
                         $flags{firstTimeInTestsLoop} = FALSE;
                         return ERROR if MainTestSetup($iter,$thread) != OK;
                         $flags{initialTestSetupDone} = TRUE;
                     }
                 } else{
                     PrintVerbose($loopHeader." Skip TestSetup detected.");
                     PrintWarning($loopHeader." Skipping TestSetup");
                 }
                 return ERROR if MainTestRun($test,$iter,$thread) != OK;
                 return ERROR if MainTestPost($iter,$thread) != OK;
            }
        } 
        $testTime = $dateObj->FigureElapsedTimeFormated($testTime);
        PrintVerbose($_tmpHeader." Completed in ".$testTime);
    }
    PrintVerbose("STAGE: TEST LOOP Complete");
    return ERROR if MainTestCleanup != OK;
    PrintVerbose("STAGE: RUN TESTS Complete");
    ArchiveResults();
    return OK;
}

#-----------------------------------------------------------------------------
# Shorten test tool lib calls
#-----------------------------------------------------------------------------
sub EnsureDirectory{
    return toolsLib::EnsureDirectoryExists($_[0]);
}

sub TrailingSlash{
    return toolsLib::EnsureTrailingSlash($_[0]);
}

#-----------------------------------------------------------------------------
# Setup Server
#-----------------------------------------------------------------------------
sub BackendSetup{
    PrintHeader("== STAGE: BACKEND SETUP ============================","=",71);
    
    PrintVerbose("Setting ups BACK SETUP!");
    # This is where logic goes to setup anything considered back end,
    # like a database, doc store, etc...
    
    PrintVerbose("STAGE: BACKEND SETUP Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# Wrap sleep 
#-----------------------------------------------------------------------------
sub SleepWithLog {
    my ($prefix, $seconds) = @_;
    PrintVerbose("$prefix Sleeping for $seconds seconds");
    sleep($seconds);
}

#-----------------------------------------------------------------------------
# Environment variables setup
#-----------------------------------------------------------------------------
sub SetEnvironmentVariables {
    my $setev = SetTAFSectionMsg("SetEnvironmentVariables");
    PrintVerbose($setev."Called");

    if (defined $options{environment_variables} && $options{environment_variables} ne '') {
        my @envList = split(',', $options{environment_variables});
        foreach (@envList) {
            my ($key, $value) = split(';', $_, 2);
            if (defined $key && defined $value) {
                $ENV{$key} = $value;
                PrintVerbose($setev."Environment Variable $key set with value $value");
            } else {
                PrintWarning($setev."Malformed environment variable entry: $_");
            }
        }
    } else {
        PrintVerbose($setev."No environment variables defined in options.");
    }

    PrintVerbose($setev."Complete");
}

#-----------------------------------------------------------------------------
# Setup our arrays from lists options
#-----------------------------------------------------------------------------
sub SetupArrayVariables {
    # Helper to split and clean comma-separated strings
    sub CleanSplit {
        my ($str) = @_;
        return map { s/ //g; $_ } split(',', $str);
    }

    # Setup threads array
    @threads = CleanSplit($options{threads}) if defined $options{threads};
 
    # Setup tests array (uppercase)
    @tests = CleanSplit(uc($options{tests})) if defined $options{tests};
}

#-----------------------------------------------------------------------------
# Setup our defaults if not set by command line / properties
#-----------------------------------------------------------------------------
sub SetupVariables {
    PrintVerbose("SetupVariables...Start");

    $dirs{working} = TrailingSlash($dirs{working});

    # Directory-related defaults
    $options{archive_path}     //= $dirs{working}."archive/";
    $options{logs_dir}         //= $dirs{working}."logs/";
    $options{results_root_dir} //= $dirs{working}."results/";
    $options{tmp_dir}          //= $dirs{working}."tmp/";

    # Credentials and runtime
    $options{pass}       //= "not_defined_please_set_user_password";
    $options{user}       //= "jeb";
    $options{iterations} //= 1;
    $options{duration}   //= main::GetTestDuration();

    # File paths
    $files{run_log}   //= "run.log";

    # Host fallback
    $options{host} = toolsLib::GetCurrentHostName()
        if !defined $options{host} || $options{host} eq "localhost";

    # Normalize paths
    $options{archive_path}     = TrailingSlash($options{archive_path});
    $options{logs_dir}         = TrailingSlash($options{logs_dir});
    $options{results_root_dir} = TrailingSlash($options{results_root_dir});
    $options{tmp_dir}          = TrailingSlash($options{tmp_dir});

    if(IS_WINDOWS){
        $options{archive_path} = ConvertPathsToWindows($options{archive_path});
        $options{logs_dir} = ConvertPathsToWindows($options{logs_dir});
        $options{results_root_dir} = ConvertPathsToWindows($options{results_root_dir});
        $options{tmp_dir} = ConvertPathsToWindows($options{tmp_dir});
    }
    PrintVerbose("SetupVariables...Complete");
    return OK;
}

sub ConvertPathsToWindows{
    my $path = shift;
    my $new = toolsLib::ConvertToWinPath($path);
    return $new;
}

#-----------------------------------------------------------------------------
# Start the logger
#-----------------------------------------------------------------------------
sub InitLogging{
    unless (defined $options{logs_dir} && defined $files{run_log}) {
        PrintError("Missing log directory or run log filename");
        QuickExit();
    }
    $options{logs_dir} = TrailingSlash($options{logs_dir});
    my $tmpLogVar = $options{logs_dir}.$files{run_log};
    RemoveFile($tmpLogVar);
    $logger = LoggerSetup($tmpLogVar);
    my $dateTime = $dateObj->GetDateTime();
    PrintLine("*",71);
    PrintVerbose("Framework  :       $framework");
    PrintVerbose("Framework Version: $frameworkVersion.$frameworkRevision ");
    PrintVerbose("Date:              $dateTime");
    PrintVerbose("Logging initialized at: $tmpLogVar");
    PrintLine("*",71);
}

#-----------------------------------------------------------------------------
# Move Archived
#-----------------------------------------------------------------------------
sub MoveArchive{
    my $ma = SetTAFSectionMsg("MoveArchive");
    PrintVerbose($ma."Called");

    unless ($options{results_root_dir} && $dirs{current_archive_dir}) {
        PrintError($ma."Missing required directory paths");
        return ERROR;
    }
    
    unless (-d $options{results_root_dir}) {
        PrintError($ma."Source directory does not exist: ".$options{results_root_dir});
        return ERROR;
   }

    PrintVerbose("Attempting to move ".$options{results_root_dir});
    PrintVerbose("contents to ".$dirs{current_archive_dir});
    if(toolsLib::MVSubs($options{results_root_dir}, $dirs{current_archive_dir},
                        $options{tools_debug}) != OK){
        PrintError($ma."MVSubs Failed");
        return ERROR;
    }

    PrintVerbose($ma."Complete");
    return OK;
}

#-----------------------------------------------------------------------------
# Remove lock and exit
#-----------------------------------------------------------------------------
sub QuickExit{
    if(-e $files{test_lock}){
        RemoveFile($files{test_lock});
    }
    exit OK;
}

#-----------------------------------------------------------------------------
# Writing of test runs README
#-----------------------------------------------------------------------------
sub WriteReadmeStart{
    my ($iter,$thread,$test) = @_;
    my $wrass = SetTAFSectionMsg("WriteReadmeStart");
    PrintVerbose($wrass."Start");
    $dirs{results} = TrailingSlash($dirs{results});
    $files{read_me} = $dirs{results}."readme.txt";
    $readMeWriter = LoggerSetup($files{read_me});
    my $dateTime = $dateObj->GetDateTime();
    my $time = $dateObj->GetTime();
    $readMeWriter->LogMessage("------------------ Test Details ------------------");
    $readMeWriter->LogMessage("Date of test:              ".$dateTime);
    $readMeWriter->LogMessage("Time of test:              ".$time);
    $readMeWriter->LogMessage("Framework:                 ".$framework);
    $readMeWriter->LogMessage("Framework Version:         ".$frameworkVersion);
    $readMeWriter->LogMessage("Framework Rev:             ".$frameworkRevision);
    $readMeWriter->LogMessage("TAF Commandline:           ".$commandLine);
    $readMeWriter->LogMessage("Test Suite:                ".$options{test_suite});
    my $tmpCnfg = $options{test_suite};
    $tmpCnfg = EnsureTrailingPm($tmpCnfg);
    $readMeWriter->LogMessage("Test Suite source file:    ".$tmpCnfg);
    $readMeWriter->LogMessage("Test Suite Version:        ".main::GetTestSuiteVersion());
    $readMeWriter->LogMessage("Test Suite Revision:       ".main::GetTestSuiteRevision());
    $readMeWriter->LogMessage("Test Client Version:       ".main::GetTestClientVersion());
    $readMeWriter->LogMessage("Test Name:                 ".$test);
    $readMeWriter->LogMessage("Duration(seconds):         ".$options{duration});
    $readMeWriter->LogMessage("Iteration:                 ".$iter);
    $readMeWriter->LogMessage("Threads:                   ".$thread);
    $readMeWriter->LogMessage("Comments:                  ".$options{comments});
    $readMeWriter->LogMessage("Test Type:                 ".$options{test_type});
    $readMeWriter->LogMessage("Log Directory:             ".$options{logs_dir});
     PrintVerbose($wrass."Complete");
}

#-----------------------------------------------------------------------------
sub WriteReadmeEnd{
    my ($duration) = @_;
    my $wreass = SetTAFSectionMsg("WriteReadmeEnd");
    PrintVerbose($wreass."Start");

    $readMeWriter->LogMessage("Run Duration Seconds:      ".$duration);

    my $dateTime = $dateObj->GetDateTime();
    $readMeWriter->LogMessage("Test end Date-time:        ".$dateTime);

    $readMeWriter->LogMessage(" _EOF_");

    PrintVerbose($wreass."Complete");
}

#-----------------------------------------------------------------------------
# Unload the test suite 
#-----------------------------------------------------------------------------
sub UnloadTestSuite{
    my $module = shift;
    PrintVerbose("TAF UnLoadTestSuite: Called on $module");

    if (exists $INC{$module}) {
        delete $INC{$module};
        PrintVerbose("Module $module successfully removed from \%INC");
    } else {
        PrintVerbose("Module $module was not found in \%INC");
    }

    $flags{tsmpLoaded} = FALSE;
    $flags{checkTestSuiteCapabilitiesDone} = FALSE;
}

#-----------------------------------------------------------------------------
# USAGE
#-----------------------------------------------------------------------------
sub Usage {
    if (-e $files{help_file}) {
        open my $fh, '<', $files{help_file} or do {
            PrintError("\n\nUSAGE DISPLAY ERROR: Cannot open ".$files{help_file}.": $!");
            TAFEnd(ERROR);
        };
        while (<$fh>) {
            chomp;
            print "$_\n";
        }
        close($fh);
    } else {
        PrintError("\n\nUSAGE DISPLAY ERROR: ".$files{help_file}." is missing!!!");
    }
    QuickExit(OK);
}

#-----------------------------------------------------------------------------
sub UsageError {
    my $message = shift;
    PrintError("\n\nUSAGE ERROR: $message");
    PrintVerbose("Run \"perl taf.pl --help\" for usage options.");
    TAFEnd(ERROR);
}

#-----------------------------------------------------------------------------
# Print Functions and logger wappers.
#-----------------------------------------------------------------------------
sub Print {
    my $msg = $_[0] // '';
    print "$msg\n";
}

#-----------------------------------------------------------------------------
sub PrintAllVariables {
    my $msg = "Harness: $framework version: $frameworkVersion.$frameworkRevision $dirs{working}";
    PrintHeader($msg, "-", 71);
    PrintVerbose("Status of all Framework Variables");

    PrintHeader("#         Option          #", "-", 47);
    PrintHashVerbose(\%options, 38, "Not yet defined");

    PrintHeader("#      Command Line       #", "-", 47);
    PrintVerbose($commandLine);

    PrintHeader("#          Flags          #", "-", 47);
    foreach my $flag (sort keys %flags) {
        my $str = sprintf("%-30s", $flag);
        PrintVerbose("$str = " . ($flags{$flag} ? "TRUE" : "FALSE"));
    }

    PrintHeader("#  Framework Directories  #", "-", 47);
    PrintHashVerbose(\%dirs, 20, "Not yet defined");

    PrintHeader("#   Framework Files       #", "-", 47);
    PrintHashVerbose(\%files, 38, "Not yet defined");

    PrintLine("-", 47);
    PrintVerbose("Framework Print Variables END");
    PrintLine("-", 47);
}

#-----------------------------------------------------------------------------
sub PrintArray{
    PrintVerbose("Array named ".$_[0]);
    foreach(@{$_[1]}){
        PrintVerbose($_);
    }
}

#-----------------------------------------------------------------------------
sub PrintError {
    my $dateTime = $dateObj->GetDateTime();
    my $message  = $_[0] // '';
    my $fullMessage = "$dateTime : ERROR: $message";

    push(@errorsIssued, $fullMessage);

    if (defined $logger) {
        $logger->LogErrorVPlus($options{verbose}, $fullMessage);
    } elsif ($options{verbose}) {
        print "$fullMessage\n";
    }
}

#-----------------------------------------------------------------------------
sub PrintErrorArray {
    my $errorsCount = scalar @errorsIssued;
    PrintVerbose("Number of errors issued: $errorsCount");

    if ($errorsCount > 0) {
        PrintVerbose("List of errors:");
        my $index = 1;
        foreach my $error (@errorsIssued) {
            PrintVerbose("  $index. $error");
            $index++;
        }
    }
}

#-----------------------------------------------------------------------------
sub PrintFileContents {
    my $filename = $_[0];
    open my $fh, '<', $filename or UsageError("Cannot open file '$filename': $!");
    my @lines = <$fh>;
    close $fh;

    PrintVerbose("Dumping file contents for: $filename");
    foreach my $line (@lines) {
        chomp($line);
        PrintVerbose($line);
    }
}

#-----------------------------------------------------------------------------
sub PrintHashVerbose {
    my ($hashRef, $width, $undefMsg) = @_;
    foreach my $key (sort keys %{$hashRef}) {
        my $str = sprintf("%-${width}s", $key);
        my $val = defined $hashRef->{$key} ? $hashRef->{$key} : $undefMsg;
        PrintVerbose("$str = $val");
    }
}

#-----------------------------------------------------------------------------
sub PrintHeader{
    PrintLine($_[1],$_[2]);
    PrintVerbose($_[0]);
    PrintLine($_[1],$_[2]);
}

#-----------------------------------------------------------------------------
sub PrintLine {
    if (defined $logger) {
        $logger->LogLineVPlus($options{verbose}, $_[0], $_[1]);
    } elsif ($options{verbose}) {
        my $line = '';
        for (my $i = 0; $i < $_[1]; $i++) {
            $line .= $_[0];
        }
        Print($line);
    }
}

#-----------------------------------------------------------------------------
sub PrintTestRunDetails {
    my ($test,$iter,$thread) = @_;
    #print("PrintTestRunDetails $test,$iter,$thread\n");
    my $dateTime = $dateObj->GetDateTime();
    PrintLine("-",60);
    PrintVerbose("TEST RUN DETAILS:");
    PrintLine("-",60);
    PrintVerbose("DATE:                 " . ($dateTime            // "N/A") );
    PrintVerbose("HOST:                 " . ($options{"host"}     // "N/A"));
    PrintVerbose("LOCAL RESULT DIR:     " . ($dirs{"results"}     // "N/A"));
    PrintVerbose("TEST_NAME:            " . ($test                // "N/A"));
    PrintVerbose("THREADS:              " . ($thread              // "N/A"));
    PrintVerbose("TEST ITERATION:       " . ($iter                // "N/A"));
    PrintVerbose("DURATION:             " . ($options{"duration"} // "N/A"));
    PrintLine("-",60);
}

#-----------------------------------------------------------------------------
sub PrintTestSuiteHelp {
    my $test_suite = shift;

    unless (LoadTestSuite($test_suite) == OK) {
        PrintError("Failed to load test suite: $test_suite");
        return ERROR;
    }

    main::Help();

    unless (UnloadTestSuite($test_suite) == OK) {
        PrintError("Failed to unload test suite: $test_suite");
        # Optionally return ERROR here if unloading is critical
    }

    return OK;
}

#-----------------------------------------------------------------------------
sub PrintWarning {
    my $dateTime = $dateObj->GetDateTime();
    my $message  = $_[0] // '';
    my $fullMessage = "$dateTime : WARNING: $message";

    push(@warningsIssued, $fullMessage);

    if (defined $logger) {
        $logger->LogWarnVPlus($options{verbose}, $fullMessage);
    } elsif ($options{verbose}) {
        Print($fullMessage);
    }
}

#-----------------------------------------------------------------------------
sub PrintWarningsArray {
    my $warningsCount = scalar @warningsIssued;
    PrintVerbose("Number of warnings issued: $warningsCount");

    if ($warningsCount > 0) {
        PrintVerbose("List of warnings:");
        my $index = 1;
        foreach my $warning (@warningsIssued) {
            PrintVerbose("  $index. $warning");
            $index++;
        }
    }
}

#-----------------------------------------------------------------------------
sub PrintVerbose{
    my $dateTime = $dateObj->GetDateTime();
    my $message  = $_[0] // '';

    if(defined $logger){
        $logger->LogMessageVPlus($options{verbose},$dateTime." : ".$message);
    } else {
        if($options{verbose}){
            Print($dateTime." : ".$message);
        }
    }
}

#-----------------------------------------------------------------------------
# Setup section messgaes.
#-----------------------------------------------------------------------------
sub SetTAFSectionMsg{
    return "TAF ".$_[0].": ";
}

#-----------------------------------------------------------------------------
# Validations subs
#-----------------------------------------------------------------------------
sub ValidateComments(){
    if($options{comments} ne "none"){
        my $size = length($options{comments});
        if($size > 150){
            UsageError("--comments is limited to 150 char");
        } else{
            $options{comments} =~ s/"//g;
        }
    }
	
}

#-----------------------------------------------------------------------------
sub ValidateTestType {
    if (defined $options{test_type}) {
        $options{test_type} = lc($options{test_type});

        unless (exists $testTypes{$options{test_type}}) {
            ListTestTypes;
            UsageError("Invalid test_type: '$options{test_type}' is not recognized.");
        }
    } else {
        ListTestTypes;
        UsageError("--test-type=<type> is undefined but required.");
    }
}
__END__
