package toolsLib;
################################################################################
# Created:  08/2025
# Last Mod: 08/2025
# Purpose:  Interface to the tools in script_tools_lib
################################################################################

use strict;
use warnings;
use FindBin qw($Bin);
use lib 'lib', "$Bin/tools";

use Exporter 'import';
use Data::Dumper;

# Tool modules
use DateTime;
use FileCounter;
use FileOps;
use IsNumeric;
use Logger;
use Paths;
use Trim;

# Required modules (non-importing)
require tools::Archiver;
require tools::GetHostName;
require tools::RemoveDir;
require tools::SecureCopy;
no warnings 'redefine';

# Constants and globals
our $VERSION = '1.0';
our @EXPORT = qw(
    CopyRecursive
    CopyRecursiveFromCurrent
    ConvertToWinPath
    DeleteFilesWExt
    DirCounter
    DoesDirectoryExist
    EnsureDirectoryExists
    EnsureTrailingSlash
    FileCounter
    FileCounterWithExt
    GetCurrentHostName
    GetDateObject
    GetHostNameByIP
    GetListOfFilesWithExt
    GetLogger
    IsANumber
    IsThisAnIpAddress
    MV
    MVSubs
    NoCompressArchiveAbsolute
    NoCompressArchiveRelative
    PurgeDirectory
    RemoveSubTree
    RemoveTrailingSlash
    RemoveTree
    SCopyFrom
    SCopyTo
    SCopyToRecursive
    Trim
    TrimLite
    Zipper
    ZipRelative
);


our $DEBUG = 0;
use constant {
    OK    => 0,
    ERROR => 1,
};

# Optional prototypes (if needed for legacy compatibility)
BEGIN {
    sub CopyRecursive;
    sub CopyRecursiveFromCurrent;
    sub ConvertToWinPath;
    sub DeleteFilesWExt;
    sub DirCounter;
    sub DoesDirectoryExist;
    sub EnsureDirectoryExists;
    sub EnsureTrailingSlash;
    sub FileCounter;
    sub FileCounterWithExt;
    sub GetCurrentHostName;
    sub GetDateObject;
    sub GetHostNameByIP;
    sub GetListOfFilesWithExt;
    sub GetLogger($);
    sub IsANumber;
    sub IsThisAnIpAddress;
    sub MV;
    sub MVSubs;
    sub NoCompressArchiveAbsolute;
    sub NoCompressArchiveRelative;
    sub PurgeDirectory;
    sub RemoveSubTree;
    sub RemoveTrailingSlash;
    sub RemoveTree;
    sub SCopyFrom;
    sub SCopyTo;
    sub SCopyToRecursive;
    sub Trim;
    sub TrimLite;
    sub Zipper;
    sub ZipRelative;
}
1;


sub DebugPrint($){
    print "$_[0]\n" if $DEBUG;
}

################################################################################
# Test sub function (can ignore) 
################################################################################
sub here{
    print "here tools\n";
}

################################################################################
# Interface for tools_lib::tools::Archiver.pm
################################################################################

sub Zipper {
    return _run_archiver('Archive', @_);
}

sub ZipRelative {
    return _run_archiver('ArchiveRelative', @_);
}

sub NoCompressArchiveRelative {
    return _run_archiver('ArchiveRelativeNoCompression', @_);
}

sub NoCompressArchiveAbsolute {
    return _run_archiver('ArchiveNoCompression', @_);
}

#---------------------------------------------
sub _run_archiver {
    my ($method, $targetDir, $myFile, $debugWanted) = @_;

    if ($DEBUG || $debugWanted) {
        print "$method\n";
        print "target  = " . (defined $targetDir   ? $targetDir   : 'undef') . "\n";
        print "archive = " . (defined $myFile      ? $myFile      : 'undef') . "\n";
        print "debug   = " . (defined $debugWanted ? 'TRUE'       : 'undef') . "\n";
    }

    unless (ABadDir($targetDir)) {
        my $zipper = tools::Archiver->new();
        return $zipper->$method($targetDir, $myFile, $debugWanted);
    }

    print "the dir $targetDir is a bad dir!!\n" if $DEBUG || $debugWanted;
    return 1;
}

################################################################################
# Interface for tools_lib::tools::DateTime
################################################################################
sub GetDateObject {
    return tools::DateTime->new();
}

################################################################################
# sub function to ensure good directories are passed in as much as possible.
################################################################################
sub ABadDir {
    my ($dir) = @_;

    DebugPrint("ABadDir: Checking directory = $dir");

    unless (defined $dir) {
        print "ABadDir Error: No directory provided. Please check your parameters.\n";
        return 1;
    }

    unless (-e $dir) {
        print "ABadDir Error: '$dir' does not exist. Please check your parameters.\n";
        return 1;
    }

    unless (-d $dir) {
        print "ABadDir Error: '$dir' is not a directory. Please check your parameters.\n";
        return 1;
    }

    return 0;
}

################################################################################
# Interface for tools_lib::tools::FileCounter
################################################################################
sub FileCounter{
    my ($target)= @_;
    my $counter = tools::FileCounter->new();
    return($counter->CountFiles($target));
}

sub FileCounterWithExt{
    my ($target,$ext)= @_;
    my $counter = tools::FileCounter->new();
    return($counter->CountFilesWExtensions($target,$ext));
}

#---------------------------------------------
sub DirCounter{
    my ($target)= @_;
    my $counter = tools::FileCounter->new();
    return($counter->CountDirs($target));
}

################################################################################
# Interface for tools_lib::tools::FileOps
################################################################################
sub MV {
    my ($base, $target, $debug) = @_;
    $DEBUG = $debug;

    DebugPrint("MV: base = $base, target = $target");
    return tools::FileOps->new->Move($base, $target, $DEBUG);
}

sub MVSubs {
    my ($base, $target, $debug) = @_;
    $DEBUG = $debug;

    DebugPrint("MVSubs: base = $base, target = $target");
    return tools::FileOps->new->MoveSubs($base, $target, $DEBUG);
}

sub CopyRecursive {
    my ($base, $target, $debug) = @_;
    $DEBUG = $debug;

    DebugPrint("CopyRecursive: base = $base, target = $target");
    return tools::FileOps->new->CopyR($base, $target, $DEBUG);
}

sub CopyRecursiveFromCurrent {
    my ($target, $debug) = @_;
    $DEBUG = $debug;

    DebugPrint("CopyRecursiveFromCurrent: target = $target");
    return tools::FileOps->new->CopyRfromCurrent($target, $DEBUG);
}

sub DeleteFilesWExt {
    my ($dir, $ext, $debug) = @_;
    $DEBUG = $debug;

    DebugPrint("DeleteFilesWExt: dir = $dir, ext = $ext");
    return tools::FileOps->new->DeleteFilesWExtension($dir, $ext, $DEBUG);
}

sub GetListOfFilesWithExt {
    my ($dir, $ext, $debug) = @_;
    $DEBUG = $debug;

    DebugPrint("GetListOfFilesWithExt: dir = $dir, ext = $ext");
    return tools::FileOps->new->ListFilesWithExtension($dir, $ext, $DEBUG);
}

################################################################################
# Interface for tools_lib::tools::GetHostName
################################################################################

sub GetCurrentHostName {
    my $hostname = tools::GetHostName->new;
    return $hostname->GetName;
}

sub GetHostNameByIP {
    my ($ip) = @_;
    my $hostname = tools::GetHostName->new;
    return $hostname->GetByIP($ip);
}


################################################################################
#  Interface for tools_lib::tools::IsNumeric
################################################################################
sub IsANumber {
    my ($value) = @_;
    return tools::IsNumeric->IsThisANumber($value);
}

sub IsThisAnIpAddress {
    my ($value) = @_;
    return tools::IsNumeric->IsThisAnIP($value);
}

################################################################################
# Interface for tools_lib::tools::Logger
################################################################################
sub GetLogger($) {
    my ($logfile) = @_;
    return tools::Logger->new( file => $logfile );
}

################################################################################
#  Interface for tools_lib::tools::Paths
################################################################################
sub EnsureTrailingSlash{
    return(tools::Paths::EnsureSlashTrailing($_[0]));
}

#---------------------------------------------
sub RemoveTrailingSlash{
    return(tools::Paths::RemoveSlashTrailing($_[0]));
}

#---------------------------------------------
sub EnsureDirectoryExists{
    return(tools::Paths::EnsureDirectory($_[0]));
}

#---------------------------------------------
sub DoesDirectoryExist{
    return(tools::Paths::DirExists($_[0]));
}


################################################################################
# Interface for tools_lib::tools::RemoveDir
################################################################################
# Remove subdirectories only
sub RemoveSubTree {
    my ($targetDir, $maxLoops) = @_;

    if ($DEBUG) {
        print "RemoveSubTree\n";
        print "targetDir = " . (defined $targetDir ? $targetDir : 'undef') . "\n";
        print "maxLoops  = " . (defined $maxLoops  ? $maxLoops  : 'undef') . "\n";
    }

    unless (ABadDir($targetDir)) {
        my $remover = tools::RemoveDir->new();
        return $remover->RemoveSub($targetDir, $maxLoops);
    }

    print "the dir $targetDir is a bad dir!!\n" if $DEBUG;
    return 1;
}

# Remove directory and all contents
sub RemoveTree {
    my ($targetDir, $maxLoops, $debugWanted) = @_;

    if ($debugWanted) {
        print "RemoveTree\n";
        print "targetDir = " . (defined $targetDir ? $targetDir : 'undef') . "\n";
        print "maxLoops  = " . (defined $maxLoops  ? $maxLoops  : 'undef') . "\n";
    }

    unless (ABadDir($targetDir)) {
        my $remover = tools::RemoveDir->new();
        return $remover->RemoveDirectory($targetDir, $maxLoops, $debugWanted);
    }

    print "the dir $targetDir is a bad dir!!\n" if $debugWanted;
    return 1;
}

# Purge files and subdirectories older than N days
sub PurgeDirectory {
    my ($purgeDir, $daysToKeep, $debugWanted) = @_;

    if ($debugWanted) {
        print "tools_lib::PurgeDirectory\n";
        print "Target Directory = $purgeDir\n";
        print "Days to keep     = $daysToKeep\n";
    }

    unless (ABadDir($purgeDir)) {
        my $purger = tools::RemoveDir->new();
        return $purger->PurgeDir($purgeDir, $daysToKeep, $debugWanted);
    }

    print "the dir $purgeDir is a bad dir!!\n" if $debugWanted;
    return 1;
}

################################################################################
# Interface for tools_lib::tools::SecureCopy
################################################################################

sub SCopyTo {
    my ($targetFile, $user, $targetHost, $targetPath, $pass, $debug) = @_;

    unless (-e $targetFile) {
        print "SCopyTo Error: File '$targetFile' does not exist\n";
        return ERROR;
    }

    my $scp = tools::SecureCopy->new;
    return $scp->SCPTO($targetFile, $user, $targetHost, $targetPath, $pass, $debug);
}

sub SCopyToRecursive {
    my ($baseDir, $user, $targetHost, $targetPath, $pass, $debug) = @_;

    unless (-e $baseDir && -d $baseDir) {
        print "SCopyToRecursive Error: Directory '$baseDir' does not exist or is not a directory\n";
        return ERROR;
    }

    my $scp = tools::SecureCopy->new;
    return $scp->ScpToRecursive($baseDir, $user, $targetHost, $targetPath, $pass, $debug);
}

sub SCopyFrom {
    my ($targetFile, $user, $targetHost, $targetPath, $pass, $localPath, $debug) = @_;

    unless (defined $localPath) {
        print "SCopyFrom Error: Missing local path\n";
        return ERROR;
    }

    my $scp = tools::SecureCopy->new;
    return $scp->SCPFROM($targetFile, $user, $targetHost, $targetPath, $pass, $localPath, $debug);
}
################################################################################
#  Interface for tools_lib::tools::Trim
################################################################################
sub Trim {
    my ($string) = @_;
    return tools::Trim->trim($string);
}

sub TrimLite {
    my ($string) = @_;
    return tools::Trim->trimLite($string);
}

################################################################################
# Interface for tools_lib::tools::WinHelp
################################################################################
sub ConvertToWinPath{
    my $newWinPath = new tools::WinHelp;
    return($newWinPath->win_path($_[0]));
}