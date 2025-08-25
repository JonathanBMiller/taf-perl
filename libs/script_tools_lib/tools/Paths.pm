package tools::Paths;
################################################################################
# Birth:    08/2025
# Last Mod: 08/2025
# Purpose:  Helper tool to work with the trailing slashes of paths
################################################################################

use strict;
use warnings;
use Carp;
use Exporter 'import';
use File::Path qw(mkpath);

our $VERSION = '1.0';
our @EXPORT = qw(
    EnsureSlashTrailing
    RemoveSlashTrailing
    EnsureDirectoryExists
    DirExists
);

# Constants
use constant {
    FALSE => 0,
    TRUE  => 1,
};

# Module-level debug flag
our $DEBUG = 0;

################################################################################
# EnsureSlashTrailing
# Normalizes slashes and ensures a trailing slash
################################################################################
sub EnsureSlashTrailing {
    my ($path) = @_;
    return '' unless defined $path;

    $path =~ s#\\#/#g;
    $path .= '/' unless $path =~ m{/$};
    return $path;
}

################################################################################
# RemoveSlashTrailing
# Removes trailing slash or backslash
################################################################################
sub RemoveSlashTrailing {
    my ($path) = @_;
    return '' unless defined $path;

    $path =~ s{[\\/]+$}{};
    return $path;
}

################################################################################
# EnsureDirectoryExists
# Creates directory if it doesn't exist
################################################################################
sub EnsureDirectory {
    my ($dir) = @_;
    print "Paths: Ensuring $dir\n" if $DEBUG;

    unless (DirExists($dir)) {
        eval { mkpath($dir) };
        if ($@ && !DirExists($dir)) {
            print "Paths: Failed to create $dir : $@  $^E\n" if $DEBUG;
            return FALSE;
        }
    }
    return TRUE;
}

################################################################################
# DirExists
# Checks if a path exists and is a directory
################################################################################
sub DirExists {
    my ($dir) = @_;
    print "Paths: Looking at $dir\n" if $DEBUG;

    unless (defined $dir) {
        print "Paths: Variable not defined\n" if $DEBUG;
        return FALSE;
    }

    unless (-e $dir) {
        print "Paths: $dir does not exist\n" if $DEBUG;
        return FALSE;
    }

    unless (-d $dir) {
        print "Paths: $dir not a directory\n" if $DEBUG;
        return FALSE;
    }

    print "Paths: $dir exists\n" if $DEBUG;
    return TRUE;
}

1;