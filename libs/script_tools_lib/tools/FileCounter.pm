package tools::FileCounter;
################################################################################
# Birth:    08/2025
# Last Mod: 08/2025
# Purpose:  Tools to count files or directories
################################################################################

use strict;
use warnings;
use Exporter 'import';
use Carp;
use File::Basename;

our $VERSION = '1.0';
our @EXPORT  = qw(CountFiles CountDirs);

my $DEBUG = 0;

################################################################################
# Object Constructor
################################################################################
sub new {
    my ($class) = @_;
    return bless {}, $class;
}

################################################################################
# Ensure trailing slash
################################################################################
sub EnsureTrailingSlash {
    my ($path) = @_;
    return '' unless defined $path;
    $path .= '/' unless $path =~ /\/$/;
    return $path;
}

################################################################################
# Count files in a directory
################################################################################
sub CountFiles {
    my ($self, $targetDir) = @_;
    croak "CountFiles(<targetDir>)" unless defined $targetDir;

    $targetDir = EnsureTrailingSlash($targetDir);
    my $count = 0;

    print "STARTING CountFiles\n" if $DEBUG;
    opendir(my $dh, $targetDir) or croak "Cannot open directory: $targetDir";

    while (my $file = readdir($dh)) {
        next if $file =~ /^\.\.?$/;
        print "CountFiles $file\n" if $DEBUG;
        $count++ unless -d "$targetDir$file";
    }

    closedir($dh);
    print "CountFiles RETURNING a count of $count\n" if $DEBUG;
    return $count;
}

################################################################################
# Count files with a specific extension
################################################################################
sub CountFilesWExtensions {
    my ($self, $targetDir, $ext) = @_;
    croak "CountFiles(<targetDir, ext>)" unless defined $targetDir && defined $ext;

    $targetDir = EnsureTrailingSlash($targetDir);
    my $count = 0;

    print "STARTING CountFilesWExtensions\nDirectory = $targetDir\nExtension = $ext\n" if $DEBUG;
    opendir(my $dh, $targetDir) or croak "Cannot open directory: $targetDir";

    while (my $file = readdir($dh)) {
        next if $file =~ /^\.\.?$/;
        print "CountFiles $file\n" if $DEBUG;
        $count++ if $file =~ /\.\Q$ext\E$/ && !-d "$targetDir$file";
    }

    closedir($dh);
    print "CountFilesWExtension RETURNING a count of $count\n" if $DEBUG;
    return $count;
}

################################################################################
# Count subdirectories in a directory
################################################################################
sub CountDirs {
    my ($self, $targetDir) = @_;
    croak "CountDirs(<targetDir>)" unless defined $targetDir;

    $targetDir = EnsureTrailingSlash($targetDir);
    my $count = 0;

    print "STARTING CountDirs for $targetDir\n" if $DEBUG;
    opendir(my $dh, $targetDir) or croak "Cannot open directory: $targetDir";

    while (my $file = readdir($dh)) {
        next if $file =~ /^\.\.?$/;
        print "CountDirs $file\n" if $DEBUG;
        $count++ if -d "$targetDir$file";
    }

    closedir($dh);
    print "CountDirs RETURNING a count of $count\n" if $DEBUG;
    return $count;
}
1;