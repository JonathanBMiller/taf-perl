package tools::FileOps;
################################################################################
# Birth:    08/2025
# Last Mod: 08/2025
# Purpose:  Cross-platform file and directory operations without File::Copy::Recursive
################################################################################

use strict;
use warnings;
use Carp;
use Exporter 'import';
use File::Path qw(mkpath rmtree);
use File::Basename;
use FindBin qw($Bin);

use lib 'lib';
use lib ".";
use RemoveDir;
use WinHelp;

our $VERSION = '1.0';
our @EXPORT  = qw(
    ListFilesWithExtension
    Move
    MoveSubs
    CopyR
    CopyRfromCurrent
    DeleteFilesWExtension
);

use constant IS_WINDOWS => ($^O =~ /^(mswin)/oi);
use constant OK         => 0;
use constant ERROR      => 1;

our $DEBUG = 0;
our $name  = __PACKAGE__;

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
# Move subdirectories only (non-recursive)
################################################################################
sub MoveSubs {
    my ($self, $currentDir, $targetDir, $debug) = @_;
    $DEBUG = $debug;

    unless (-d $targetDir) {
        DebugPrint("MoveSubs: Creating target directory $targetDir");
        mkpath($targetDir);
    }

    if (IS_WINDOWS) {
        return $self->Move($currentDir, $targetDir, $DEBUG);
    }

    opendir(my $dh, $currentDir) or croak "Cannot open $currentDir: $!";
    my @subdirs = grep { !/^\./ } readdir($dh);
    closedir($dh);

    foreach my $item (@subdirs) {
        my $source = "$currentDir$item";
        DebugPrint("MoveSubs: Moving $source to $targetDir");
        return ERROR if $self->Move($source, $targetDir, $DEBUG) != OK;
    }

    return OK;
}

################################################################################
# Move files and directories recursively
################################################################################
sub Move {
    my ($self, $currentDir, $targetDir, $debug) = @_;
    $DEBUG = $debug;

     if(!defined $currentDir or !defined $targetDir){
        DebugPrint("Move() Current Dir = $currentDir");
        DebugPrint("Move() Target Dir  = $targetDir");
        return(ERROR);
    }

    if(IS_WINDOWS){
        # XCOPY had issues with trailing slashes wrt the copy from path
        $currentDir =~ s[/$][];
        my $newWinPath = new tools::WinHelp;
        $currentDir = $newWinPath->win_path($currentDir);
        $targetDir  = $newWinPath->win_path($targetDir);
        DebugPrint("Move() Current Dir = $currentDir");
        DebugPrint("Move() Target Dir  = $targetDir");
        my $rc = 0;
         if($DEBUG){
            $rc = system("xcopy $currentDir $targetDir /E /Y /J");
        } else{
            $rc = system("xcopy $currentDir $targetDir /Q /E /Y /J > nul 2>&1");
        }
        if($rc != OK){
            return($rc);
        } else{
            my $myRemove = new tools::RemoveDir;
            return $myRemove->RemoveSub($currentDir, 50);
        }
    }else{
      return system( "mv $currentDir $targetDir");
    }
}

################################################################################
# Copy files and directories recursively
################################################################################
sub CopyR {
    my ($self, $currentDir, $targetDir, $debug) = @_;
    $DEBUG = $debug;

    unless (defined $currentDir && defined $targetDir) {
        DebugPrint("CopyR: Missing arguments");
        return ERROR;
    }

    my $cmd = "cp -r $currentDir $targetDir";

    if (IS_WINDOWS) {
        $currentDir =~ s[/$][];
        my $winPath = tools::WinHelp->new;
        $currentDir = $winPath->win_path($currentDir);
        $targetDir  = $winPath->win_path($targetDir);

        my $subdirName = basename($currentDir);
        my $newTarget  = "$targetDir$subdirName";
        mkpath($newTarget);

        $cmd = $DEBUG
            ? "xcopy $currentDir $newTarget /E /Y /J"
            : "xcopy $currentDir $newTarget /Q /E /Y /J > nul 2>&1";

        DebugPrint("CopyR: Windows paths -> $currentDir => $newTarget");
    }

    DebugPrint("CopyR: Executing -> $cmd");
    return system($cmd);
}

################################################################################
# Copy files and subdirectories from current location recursively
################################################################################
sub CopyRfromCurrent {
    my ($self, $targetDir, $debug) = @_;
    $DEBUG = $debug;

    unless (defined $targetDir) {
        DebugPrint("CopyRfromCurrent: Missing target directory");
        return ERROR;
    }

    my $cmd = "cp -r ./* $targetDir";

    if (IS_WINDOWS) {
        my $winPath = tools::WinHelp->new;
        $targetDir  = $winPath->win_path($targetDir);

        $cmd = $DEBUG
            ? "xcopy * $targetDir /E /Y /J"
            : "xcopy * $targetDir /Q /E /Y /J > nul 2>&1";
    }

    DebugPrint("CopyRfromCurrent: Executing -> $cmd");
    return system($cmd);
}

################################################################################
# Delete files with a specific extension from a directory
################################################################################
sub DeleteFilesWExtension {
    my ($self, $targetDir, $targetExt, $debug) = @_;
    $DEBUG = $debug;

    DebugPrint("DeleteFilesWExtension: dir = $targetDir, ext = $targetExt");

    unless (-d $targetDir) {
        DebugPrint("DeleteFilesWExtension: Directory does not exist");
        return ERROR;
    }

    opendir(my $dh, $targetDir) or return ERROR;
    while (my $file = readdir($dh)) {
        next unless $file =~ /\.\Q$targetExt\E$/;

        my $fullPath = IS_WINDOWS
            ? "$targetDir\\$file"
            : "$targetDir/$file";

        DebugPrint("DeleteFilesWExtension: Removing $fullPath");
        unlink $fullPath or return ERROR;
    }
    closedir($dh);

    return OK;
}

################################################################################
# List files with a specific extension from a directory
################################################################################
sub ListFilesWithExtension {
    my ($self, $targetDir, $targetExt, $debug) = @_;
    $DEBUG = $debug;
    my @fileList;

    DebugPrint("ListFilesWithExtension: dir = $targetDir, ext = $targetExt");

    unless (-d $targetDir) {
        DebugPrint("ListFilesWithExtension: Directory does not exist");
        return ERROR;
    }

    opendir(my $dh, $targetDir) or return ERROR;
    while (my $file = readdir($dh)) {
        next unless $file =~ /\.\Q$targetExt\E$/;
        DebugPrint("ListFilesWithExtension: Found $file");
        push @fileList, $file;
    }
    closedir($dh);

    return @fileList;
}
1;