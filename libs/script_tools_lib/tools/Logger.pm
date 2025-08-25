package tools::Logger;
################################################################################
# Birth:    08/2025
# Last Mod: 08/2025
# Purpose:  Tools to aid in mysql test automation in logging
################################################################################

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $VERSION);

use Exporter;
use IO::File;

@ISA = qw(Exporter testToolsLib);
@EXPORT = qw(
    &LogDebug
    &LogDebugSwtch
    &LogDebugVerbose
    &LogError
    &LogErrorVPlus
    &LogWarn
    &LogWarnVPlus
    &LogMessage
    &LogMessageV
    &LogMessageVPlus
    &LogMessageVOnly
    &LogLine
    &LogLineVPlus
    &LogLineDebugVerbose
    &RenameLog
);

$VERSION = '3.02';

our $fh;
our $error = 0;
use Data::Dumper;

################################################################################
# Create an Object
################################################################################
sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->SetName(@_);
    return $self;
}

################################################################################
# Set file name and path
################################################################################
sub SetName(){
    my $self = shift;
    my %fileIn = @_;
    $self -> {'file'}  = $fileIn{'file'} || "./default.log";
}

################################################################################
# I/O Utilites 
################################################################################
#--- Append ---
sub OpenFileAppend (){
    my $self  = shift;
    if (-e $self->{'file'})  {
        $fh = IO::File->new("$self->{'file'}", O_WRONLY|O_APPEND) or $error = 1;
        if($error){
            print("ERROR: could not append to $self->{'file'}: $!\n");
        }
    } else{
        $self->OpenFileForWrite();
    }
}

#--- Write ---
sub OpenFileForWrite (){
    my( $self ) = @_;
    $fh = IO::File->new("$self->{'file'}", O_WRONLY|O_TRUNC|O_CREAT) or $error = 1;
    if ($error){  
        print "ERROR: could not open $self->{'file'} $! for write\n";
    }
}

#--- Close ---
sub CloseFile (){
    my $pos = $fh->getpos;
    $fh->setpos($pos);
    undef $fh;       # automatically closes the file
}

################################################################################
# Write to file functions
################################################################################
sub LogMessage($){
    # All messages get logged to logfile
    my( $self ) = @_;
    $self->OpenFileAppend ();
    if(!$error){
        print $fh "$_[1]\n";
        CloseFile ();
    }
}

#-----------------------------------------------------------------------------
sub LogMessageV($){
    # All messages get logged to STOUT
    my( $self ) = @_;
    print "$_[1]\n";
    $self->LogMessage($_[1]);
}

#-----------------------------------------------------------------------------
sub LogMessageVOnly($$){
    # $_[1] if Verbose
    # $_[2] Message
    my( $self ) = @_;
    if($_[1]){
        print "$_[2]\n";
        $self->LogMessage($_[2]);
    }
}
#-----------------------------------------------------------------------------
sub CreateLine{
    my( $char ) = $_[0];
    my( $size ) = $_[1];
    my( $line ) = undef;
    $line = $char;
    for(my $i = 1; $i < $size; $i++){
        $line = "$line"."$char"; 
    }
    return $line;
}
#-----------------------------------------------------------------------------
sub LogLine($$){
    # All messages get logged to logfile
    my( $self )    = $_[0];
    my( $char )    = $_[1];
    my( $size )    = $_[2];
    my( $line ) = undef;
    $line = CreateLine($char,$size);
    $self->LogMessage($line);
}
#-----------------------------------------------------------------------------
sub LogLineVPlus($$$){
    my( $self )    = $_[0];
    my( $verbose ) = $_[1];
    my( $char )    = $_[2];
    my( $size )    = $_[3];
    my( $line ) = undef;
    $line = CreateLine($char,$size);
    $self->LogMessage($line);
    if($verbose){
        print "$line\n";
    }
}
#-----------------------------------------------------------------------------
sub LogLineDebugVerbose($$$$){
    my( $self )    = $_[0];
    my( $verbose ) = $_[1];
    my( $debugIn ) = $_[2];
    my( $char )    = $_[3];
    my( $size )    = $_[4];
    my( $line ) = undef;
    $line = CreateLine($char,$size);
    if($debugIn){
        $self->LogMessage($line);
    }
    if($verbose){
        print "$line\n";
    }
}

#-----------------------------------------------------------------------------
sub LogDebugVerbose($$$){
    # $_[1] if Verbose
    # $_[2] if debug
    # $_[3] Message
    # print screen if verbose
    # Log to file if debug
    my( $self ) = @_;
    if($_[1]){
      print "$_[3]\n";
    }
    if($_[2]){
      $self->LogDebug("$_[3]");
    }
}

#-----------------------------------------------------------------------------
sub LogMessageVPlus($$){
    # Log message, and print screen if verbose
    my( $self ) = @_;
    if($_[1]){
      print "$_[2]\n";
    }
    $self->LogMessage($_[2]);
}

#-----------------------------------------------------------------------------
sub LogDebug($){
    my( $self ) = @_;
    $self->LogMessage("DEBUG: $_[1]");
}

#-----------------------------------------------------------------------------
sub LogDebugSwtch($$){
    my( $self ) = @_;
    if($_[1]){
        $self->LogDebug("$_[2]");
    }
}

#-----------------------------------------------------------------------------
sub LogError($){
    my( $self ) = @_;
    $self->LogMessage("ERROR: $_[1]");
}

#-----------------------------------------------------------------------------
sub LogErrorVPlus($$){
    # Log message, and print screen if verbose
    my( $self ) = @_;
    if($_[1]){
        print "ERROR: $_[2]\n";
    }
    $self->LogError("$_[2]");
}

#-----------------------------------------------------------------------------
sub LogWarn($){
    my( $self ) = @_;
    $self->LogMessage("WARNING: $_[1]");
}

#-----------------------------------------------------------------------------
sub LogWarnVPlus($$){
    # Log message, and print screen if verbose
    my( $self ) = @_;
    if($_[1]){
        print "WARNING: $_[2]\n";
    }
    $self->LogWarn("$_[2]");
}

################################################################################
# Rename and or move file
################################################################################
sub RenameLog($){
    my( $self ) = @_;
    if (-e $self->{'file'}){
        rename($self->{'file'},$_[1]) || print "Rename of $self->{'file'} failed, do you have permission to rename?";
        $self -> {'file'}  = $_[1] || "./default.log";
    } else{
        print "RenameLog failed as the given log does not exist!\n";
    }
}
1;