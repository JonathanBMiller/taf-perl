package tools::SecureCopy;
################################################################################
# Birth:    08/2025
# Last Mod: 08/2025
# Purpose:  Helper tool for copying files between hosts (cross-platform)
################################################################################

use strict;
use warnings;
use Carp;
use Exporter 'import';
use Cwd;
use FindBin qw($Bin);

our @ISA       = qw(Exporter testToolsLib);
our @EXPORT    = qw(new SCPTO SCPFROM ScpToRecursive);
our $VERSION   = '1.0';
our $DEBUG     = 0;
our $name      = __PACKAGE__;

use constant IS_WINDOWS => ($^O =~ /^(mswin)/oi);
use constant IS_LINUX   => ($^O =~ /^(linux)/oi);
use constant IS_SOLARIS => ($^O =~ /^(solaris)/oi);
use constant OK    => 0;
use constant ERROR => 1;

my ($scp, $scpr, $devNull);

################################################################################
# Locate SCP binary based on platform
################################################################################
BEGIN {
    if (IS_WINDOWS) {
    	$scp = "$Bin/tools/helpers/pscp.exe";
        $scpr    = "$scp -noagent -q -r -pw";
        $scp     = "$scp -noagent -q -pw";
        $devNull = "> NUL 2>NUL";
    }
    elsif (IS_LINUX || IS_SOLARIS) {
        $scp     = "scp";
        $scpr    = "scp -r";
        $devNull = "> /dev/null 2>&1";
    }
    else {
        croak "Unsupported OS platform";
    }
}

################################################################################
# Constructor
################################################################################
sub new {
    my ($class) = @_;
    return bless {}, $class;
}

################################################################################
# Debug print helper
################################################################################
sub DebugPrint {
    my ($msg) = @_;
    print "$name: $msg\n" if $DEBUG;
}

################################################################################
# Ensure trailing slash on path
################################################################################
sub EnsureSlash {
    my ($path) = @_;
    return $path =~ /\/$/ ? $path : "$path/";
}

################################################################################
# Copy file to remote host
################################################################################
sub SCPTO {
    my ($self, $targetFile, $user, $targetHost, $targetPath, $pass, $debug) = @_;
    $DEBUG = $debug;

    croak "Missing required arguments" unless defined $targetFile && defined $user && defined $targetHost && defined $targetPath;
    $targetPath = EnsureSlash($targetPath);

    DebugPrint("SCPTO: targetFile = $targetFile");
    DebugPrint("SCPTO: targetHost = $targetHost");
    DebugPrint("SCPTO: targetPath = $targetPath");
    DebugPrint("SCPTO: user       = $user");
    DebugPrint("SCPTO: pass       = $pass");

    my $cmd;
    if (IS_LINUX || IS_SOLARIS) {
        $cmd = "$scp $targetFile $user\@$targetHost:$targetPath";
        $cmd .= " $devNull" unless $DEBUG;
    }
    elsif (IS_WINDOWS || IS_CYGWIN) {
        croak "Missing password for Windows/Cygwin SCP" unless defined $pass;
        $cmd = "$scp $pass $targetFile $user\@$targetHost:$targetPath";
        $cmd .= " $devNull" unless $DEBUG;
    }
    else {
        DebugPrint("Unknown OS");
        return ERROR;
    }

    DebugPrint("Executing: $cmd");
    system($cmd);
    DebugPrint("system returned $?");
    return $?;
}

################################################################################
# SecureCopy: SCP TO and FROM remote hosts (recursive and single file)
################################################################################
sub ScpToRecursive {
    my ($self, $targetRootDir, $user, $targetHost, $targetPath, $pass, $debug) = @_;
    $DEBUG = $debug;

    croak "usage: ScpToRecursive(<targetRootDir>, <user>, <targetHost>, <targetPath>, [<pass> if windows])"
        unless defined $targetRootDir && defined $user && defined $targetHost && defined $targetPath;

    $targetRootDir = EnsureSlash($targetRootDir) . "*";
    $targetPath    = EnsureSlash($targetPath);

    DebugPrint("ScpToRecursive: targetRootDir = $targetRootDir");
    DebugPrint("ScpToRecursive: targetHost    = $targetHost");
    DebugPrint("ScpToRecursive: targetPath    = $targetPath");
    DebugPrint("ScpToRecursive: user          = $user");
    DebugPrint("ScpToRecursive: pass          = $pass");

    my $cmd;
    if (IS_LINUX || IS_SOLARIS) {
        $cmd = "$scpr $targetRootDir $user\@$targetHost:$targetPath";
        $cmd .= " $devNull" unless $DEBUG;
    }
    elsif (IS_WINDOWS || IS_CYGWIN) {
        croak "Missing password for Windows/Cygwin SCP" unless defined $pass;
        $cmd = "$scpr $pass $targetRootDir $user\@$targetHost:$targetPath";
        $cmd .= " $devNull" unless $DEBUG;
    }
    else {
        DebugPrint("ScpToRecursive: Unknown OS");
        return ERROR;
    }

    DebugPrint("ScpToRecursive: Executing -> $cmd");
    system($cmd);
    DebugPrint("ScpToRecursive: system returned $?");
    return $?;
}

sub SCPFROM {
    my ($self, $targetFile, $user, $targetHost, $targetPath, $pass, $localPath, $debug) = @_;
    $DEBUG = $debug;

    croak "usage: SCPFROM(<targetFile>, <user>, <targetHost>, <targetPath>, <localPath>, [<pass> if windows])"
        unless defined $targetFile && defined $user && defined $targetHost && defined $targetPath && defined $localPath;

    $targetPath = EnsureSlash($targetPath);
    my $remoteFile = "$targetPath$targetFile";

    DebugPrint("SCPFROM: targetFile  = $targetFile");
    DebugPrint("SCPFROM: targetHost  = $targetHost");
    DebugPrint("SCPFROM: targetPath  = $targetPath");
    DebugPrint("SCPFROM: localPath   = $localPath");
    DebugPrint("SCPFROM: user        = $user");
    DebugPrint("SCPFROM: pass        = $pass");

    my $cmd;
    if (IS_LINUX || IS_SOLARIS) {
        $cmd = "$scp $user\@$targetHost:$remoteFile $localPath";
    }
    elsif (IS_WINDOWS || IS_CYGWIN) {
        croak "Missing password for Windows/Cygwin SCP" unless defined $pass;
        $cmd = "$scp $pass $user\@$targetHost:$remoteFile $localPath";
    }
    else {
        DebugPrint("SCPFROM: Unknown OS");
        return ERROR;
    }

    DebugPrint("SCPFROM: Executing -> $cmd");
    system($cmd);
    DebugPrint("SCPFROM: system returned $?");
    return $?;
}
1;