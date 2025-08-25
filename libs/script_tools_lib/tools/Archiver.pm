package tools::Archiver;
################################################################################
# Birth:    08/2025
# Last Mod: 08/2025
# Purpose:  To archive files and directories.
################################################################################
use strict;
use warnings;
use Carp;
use Cwd;
use FindBin qw($Bin);
use Exporter 'import';

our @EXPORT_OK = qw(Archive 
                    ArchiveNoCompression 
                    ArchiveRelative 
                    ArchiveRelativeNoCompression);
our $VERSION   = '1.0';

# Platform constants
use constant IS_WINDOWS => ($^O =~ /^(mswin)/oi);
use constant IS_CYGWIN  => ($^O =~ /^(cygwin)/oi);
use constant IS_LINUX   => ($^O =~ /^(linux)/oi);
use constant IS_SOLARIS => ($^O =~ /^(solaris)/oi);

###############################################################################
# Constructor
###############################################################################
sub new {
    my ($class, %args) = @_;
    my $self = {
        DEBUG         => $args{DEBUG} // 0,
        startDir      => getcwd,
        zipCmd        => undef,
        noCompressCmd => undef,
        devNull       => undef,
    };
    bless $self, $class;
    $self->_setup_zip_command;
    return $self;
}

################################################################################
# Internal: Setup zip/tar command based on platform
################################################################################
sub _setup_zip_command {
    my $self = shift;

    if (IS_WINDOWS() || IS_CYGWIN()) {
        my @candidates = (
            "$Bin/tools/helpers/zip.exe",
            substr($Bin, 0, 2) . "/perl_mods/tools_lib/tools/helpers/zip.exe",
            "./perl_mods/tools_lib/tools/helpers/zip.exe",
            "../perl_mods/tools_lib/tools/helpers/zip.exe",
            "../../perl_mods/tools_lib/tools/helpers/zip.exe",
            "../tools_lib/tools/helpers/zip.exe",
        );

        foreach my $path (@candidates) {
            if (-e $path) {
                my $dir = $path;
                $dir =~ s|/zip\.exe$||;
                chdir($dir);
                my $full = getcwd() . "/zip.exe";
                chdir($self->{startDir});
                $self->{zipCmd}        = "$full -qr";
                $self->{noCompressCmd} = "$full -0qr";
                $self->{devNull}       = "> NUL 2>NUL";
                return;
            }
        }

        croak "Unable to locate zip.exe in expected paths from $self->{startDir}";
    }
    elsif (IS_LINUX()) {
        $self->{zipCmd}        = "tar -czvf";
        $self->{noCompressCmd} = "tar -cvf";
        $self->{devNull}       = "> /dev/null 2>&1";
    }
    elsif (IS_SOLARIS()) {
        $self->{zipCmd}        = "gtar -czvf";
        $self->{noCompressCmd} = "gtar -cvf";
        $self->{devNull}       = "> /dev/null 2>&1";
    }
    else {
        croak "Unsupported operating system: $^O";
    }
}

################################################################################
# Archive with compression
################################################################################
sub Archive {
    my ($self, $target, $zipName) = @_;
    croak "usage: Archive(<target>, [<archive name>])" unless defined $target;
    $zipName ||= "archive.gz";

    my $cmd = $self->{DEBUG}
        ? "$self->{zipCmd} $zipName $target"
        : "$self->{zipCmd} $zipName $target $self->{devNull}";

    print "Running: $cmd\n" if $self->{DEBUG};
    return system($cmd);
}



################################################################################
# Absolute path Archive without compression
################################################################################
sub ArchiveNoCompression {
    my ($self, $target, $zipName) = @_;
    croak "usage: ArchiveNoCompression(<target>, [<archive name>])"
        unless defined $target;

    $zipName ||= "archive.gz";
    my $cmd = $self->{DEBUG}
        ? "$self->{noCompressCmd} $zipName $target"
        : "$self->{noCompressCmd} $zipName $target $self->{devNull}";

    print "ArchiveNoCompression -> $cmd\n" if $self->{DEBUG};
    return system($cmd);
}

################################################################################
# Relative path Archive with compression
################################################################################
sub ArchiveRelative {
    my ($self, $target, $zipName) = @_;
    croak "usage: ArchiveRelative(<target>, [<archive name>])"
        unless defined $target;

    $zipName ||= "archive.gz";
    chdir($target) or croak "Failed to chdir to $target: $!";

    my $cmd = $self->{DEBUG}
        ? "$self->{zipCmd} $zipName *"
        : "$self->{zipCmd} $zipName * $self->{devNull}";

    print "ArchiveRelative -> chdir to $target\n" if $self->{DEBUG};
    print "ArchiveRelative -> $cmd\n" if $self->{DEBUG};

    my $rc = system($cmd);

    chdir($self->{startDir}) or croak "Failed to chdir back to $self->{startDir}: $!";
    print "ArchiveRelative -> chdir back to $self->{startDir}\n" if $self->{DEBUG};
    print "ArchiveRelative -> Return Code = $rc\n" if $self->{DEBUG};

    return $rc;
}

################################################################################
# Relative path Archive without compression
################################################################################
sub ArchiveRelativeNoCompression {
    my ($self, $target, $zipName) = @_;
    croak "usage: ArchiveRelativeNoCompression(<target>, [<archive name>])"
        unless defined $target;

    $zipName ||= "archive.gz";
    chdir($target) or croak "Failed to chdir to $target: $!";

    my $cmd = $self->{DEBUG}
        ? "$self->{noCompressCmd} $zipName *"
        : "$self->{noCompressCmd} $zipName * $self->{devNull}";

    print "ArchiveRelativeNoCompression -> chdir to $target\n" if $self->{DEBUG};
    print "ArchiveRelativeNoCompression -> $cmd\n" if $self->{DEBUG};

    my $rc = system($cmd);

    chdir($self->{startDir}) or croak "Failed to chdir back to $self->{startDir}: $!";
    print "ArchiveRelativeNoCompression -> chdir back to $self->{startDir}\n" if $self->{DEBUG};
    print "ArchiveRelativeNoCompression -> Return Code = $rc\n" if $self->{DEBUG};

    return $rc;
}
1;