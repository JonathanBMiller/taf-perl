package tools::RemoveDir;
################################################################################
# Birth:    08/2025
# Last Mod: 08/2025
# Purpose: Helper tool for removing files and directories 
################################################################################
#use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $VERSION);
use Carp;
use Exporter;
use Cwd;
use File::Path qw(rmtree mkpath);

@ISA = qw(Exporter);
@EXPORT = qw(&new &RemoveDirectory &RemoveSub &PurgeDir);
$VERSION = '1.0';

our $DEBUG = 0;

use constant IS_WINDOWS => ($^O =~ /^(mswin)/oi);
use constant IS_LINUX   => ($^O =~ /^(linux)/oi);
use constant IS_SOLARIS => ($^O =~ /^(solaris)/oi);
use constant OK    => 0;
use constant ERROR => 1;


################################################################################
# Create an Object
################################################################################
sub new {
    my ($class, %args) = @_;
    my $self = {};
    bless $self, $class;
    return $self;
}

################################################################################
# Internal Sub
################################################################################
sub CountSubs {
    my $target = shift;
    my $count = 0;
    opendir(DIR,$target);
    LINE: while(my $FILE = readdir(DIR)){
        next LINE if($FILE =~ /^\.\.?/);
        $count++;
    }
    close(DIR);
    return $count;
}

################################################################################
# Remove Directory
################################################################################
sub RemoveDirectory {
    my ($self, $targetDir, $maxLoops, $DEBUG) = @_;
    my $retry     = 0;
    my $sleepTime = 1;
    my $err;

    croak "usage: RemoveDirectory(<targetDir>, [<Max Loops>])" unless defined $targetDir;
    $maxLoops = 120 unless defined $maxLoops;

    my $version = $File::Path::VERSION;

    if ($DEBUG) {
        print "RemoveDirectory => Removing: $targetDir\n";
        print "RemoveDirectory => Max Loops: $maxLoops\n";
        print "RemoveDirectory => File::Path Version: $version\n";
    }

    unless (-e $targetDir) {
        carp "RemoveDirectory => Directory '$targetDir' not found" if $DEBUG;
        return ERROR;
    }

    while ($retry < $maxLoops && -e $targetDir) {
        print "RemoveDirectory => Attempt: $retry\n" if $DEBUG;
        $err = [];

        if ($version > 2) {
            rmtree($targetDir, { error => $err, verbose => $DEBUG ? 1 : 0 });

            if (@$err) {
                foreach my $diag (@$err) {
                    while (my ($file, $message) = each %$diag) {
                        my $prefix = "RemoveDirectory => ";
                        print $file eq ''
                            ? "${prefix}General error: $message\n"
                            : "${prefix}Problem unlinking '$file': $message\n";
                    }
                }
                $retry++;
                sleep $sleepTime;
            }
        } else {
            eval { rmtree($targetDir) };
            if ($@) {
                print "RemoveDirectory => rmtree failed: $@\n" if $DEBUG;
                $retry++;
                sleep $sleepTime;
            }
        }
    }

    if ($retry >= $maxLoops) {
        carp "RemoveDirectory => Max retries ($maxLoops) exceeded" if $DEBUG;
        return ERROR;
    }

    return OK;
}

################################################################################
# Remove Sub Directories
################################################################################
sub RemoveSub{
    my $self = shift;  
    my $targetDir = undef;
    my $maxLoops  = undef;
    my $retry     = 0;
    my $sleepTime = 1;
    my $err        = undef;
    my $currentCount = 0;

    ($targetDir, $maxLoops)= @_; 

    if(!defined $targetDir){
        croak "usage: RemoveSub(<targetDir>, [<Max Loops>])";
    }
    if(!defined $maxLoops){
        $maxLoops = 120;
     }
     my $version = $File::Path::VERSION;
     if ($DEBUG){
        print("RemoveDir->RemoveSub-> Removing everything below $targetDir\n");
        print("RemoveDir->RemoveSub-> Max Loops = $maxLoops\n");
        print("RemoveDir->RemoveSub-> File::Path returned a version of = $version\n");
     }
     if (-e "$targetDir"){
        $currentCount = CountSubs($targetDir);
        while($retry < $maxLoops && $currentCount > 0){
            if ($DEBUG){
                print("RemoveDir->RemoveSub-> Current looping   = $retry\n");
                print("RemoveDir->RemoveSub-> Current sub count = $currentCount\n");
             }
             $err = "";
             # This requires version 2.08 of File::Path
             if($version > 2){
                 if($DEBUG){
                     print "RemoveDir->RemoveSub-> Inside routine for > 2.0 version ($version)\n";
                     rmtree("$targetDir", {error => \$err, keep_root => 1, verbose => 1});
                  } else{
                     rmtree("$targetDir", {error => \$err, keep_root => 1});
                  }
                  if (@{$err}){
                      if($DEBUG){
                          for my $diag (@{$err}) {
                              my ($file, $message) = %$diag;
                              if ($file eq '') {
                                  print("RemoveDir->RemoveSub->  General error: $message\n");
                              } else {
                                  print("RemoveDir->RemoveSub->  Problem unlinking $file: $message\n");
                              }
                          }
                      }
                      $retry++;
                      sleep $sleepTime;
                  } else{
                      $currentCount = CountSubs($targetDir);
                  }
             } else{
                 if($DEBUG){print "RemoveDir->RemoveSub->  Inside routine for < 2.0 version ($version)\n";}
                 eval { rmtree($targetDir) };
                 if ($@) {
                      if($DEBUG){print "RemoveDir->RemoveSub-> rmtree failed with $@\n"}
                      $retry++;
                      sleep $sleepTime;
                 } else{
                     if(!-d $targetDir){
                         if($DEBUG){print "RemoveDir->RemoveSub-> mkpath $targetDir\n"}
                         eval { mkpath("$targetDir") };
                         if ($@) {
                             if($DEBUG){carp("RemoveDir->RemoveSub-> mkpath failed with $@\n");}
                             return(ERROR);
                         } else{
                             return(OK);
                         }
                     } else{
                         $currentCount = CountSubs($targetDir);
                     }
                 }
            }
        }
        if ($retry >= $maxLoops) {
            if($DEBUG){carp("RemoveDir->RemoveSub-> looping hit $retry and max is set to $maxLoops, failing process\n");}
            return(ERROR);
        }
    }else{
        if($DEBUG){carp("RemoveDir->RemoveSub-> Directory $targetDir  not found");}
        return(ERROR);
    }
    return(OK);
}

################################################################################
# Purge Directory
################################################################################
sub PurgeDir {
    my ($self, $directoryToPurge, $daysToKeep, $DEBUG) = @_;
    my $purgeCommand;

    croak "usage: tools::RemoveDir::PurgeDir(<directoryToPurge>, [<daysToKeep>, <debug>])"
        unless defined $directoryToPurge;

    unless (-e $directoryToPurge) {
        carp "PurgeDir => Directory '$directoryToPurge' does not exist!" if $DEBUG;
        return ERROR;
    }

    print "PurgeDir => Called for: $directoryToPurge\n" if $DEBUG;

    if (!defined $daysToKeep || $daysToKeep < 1) {
        print "PurgeDir => WARNING: Invalid daysToKeep '$daysToKeep', defaulting to 7\n" if $DEBUG;
        $daysToKeep = 7;
    }

    print "PurgeDir => Retention threshold: $daysToKeep days\n" if $DEBUG;

    if (IS_WINDOWS) {
        $directoryToPurge =~ s{/}{\\}g;
        $directoryToPurge =~ s{\\$}{};  # Remove trailing backslash

        $purgeCommand = "forfiles /P \"$directoryToPurge\" /S /M *.* /D -$daysToKeep /C \"cmd /c del \@path\"";
        $purgeCommand .= " > NUL 2>NUL" unless $DEBUG;
    }
    elsif (IS_LINUX || IS_SOLARIS) {
        if ($directoryToPurge eq '' || $directoryToPurge eq '\\') {
            carp "PurgeDir => Empty or unsupported directory: '$directoryToPurge'" if $DEBUG;
            return ERROR;
        }

        $purgeCommand = "find \"$directoryToPurge\" -mtime +$daysToKeep -type d -exec rm -rf {} \\;";
        $purgeCommand .= " > /dev/null 2>&1" unless $DEBUG;
    }
    else {
        carp "PurgeDir => Unsupported operating system!" if $DEBUG;
        return ERROR;
    }

    print "PurgeDir => Executing: $purgeCommand\n" if $DEBUG;
    return system($purgeCommand);
}
1;