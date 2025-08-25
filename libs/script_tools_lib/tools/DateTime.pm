package tools::DateTime;
################################################################################
# Birth:    08/2025
# Last Mod: 08/2025
# Purpose: Helper tool to provide date and time functions
################################################################################
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $VERSION);
use Time::HiRes qw(gettimeofday tv_interval);
use Carp;
use Exporter;

@ISA = qw(Exporter testToolsLib);
@EXPORT = qw(&new
             &SetDate
             &GetDate
             &GetDateTimeSeed
             &GetOrgDate
             &GetTime
             &GetOrgTime
             &GetStartTime
             &GetOrgStartTime
             &SetStartTime
             &GetElapsedTimeSeconds
             &GetElapsedTimeFormated
             &GetDateTime
             &FigureElapsedTimeSeconds
             &FigureElapsedTimeSecondsMilliseconds
             &FigureElapsedTimeFormated
             &GetFileDateStamp
             &GetStartTimeMilliseconds
             &GetOrgStartTimeMilliseconds
             &GetElapsedTimeMilliseconds
             &GetElapsedTimeSecondsMilliseconds
             &FigureElapsedTimeMilliseconds
             );

$VERSION = '1.0';

################################################################################
# Create an Object
################################################################################
sub new {
    my $class = shift;
    my $self = {
        DEBUG        => 0,
        dtDate       => undef,
        dtTime       => undef,
        dtStart      => undef,
        dtFileDate   => undef,
        dtOrgDate    => undef,
        dtOrgTime    => undef,
        dtOrgStart   => undef,
        dtMsStart    => undef,
        dtOrgMsStart => undef,
        dtSeed       => undef,
    };
    bless $self, $class;

    $self->SetDate;
    $self->SetStartTime;

    # Preserve original values
    $self->{dtOrgDate}    = $self->{dtDate};
    $self->{dtOrgTime}    = $self->{dtTime};
    $self->{dtOrgStart}   = $self->{dtStart};
    $self->{dtOrgMsStart} = $self->{dtMsStart};

    return $self;
}


################################################################################
# Set Date inits date time and filedate varaibles with current date/time
################################################################################
sub SetDate {
    my $self = shift;

    my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time);

    $year += 1900;
    $mon  += 1;

    # Pad hour, min, sec to two digits
    $hour = sprintf("%02d", $hour);
    $min  = sprintf("%02d", $min);
    $sec  = sprintf("%02d", $sec);

    # Store values in object
    $self->{dtDate}     = "$year-$mon-$mday";
    $self->{dtTime}     = "$hour:$min:$sec";
    $self->{dtFileDate} = "${year}_${mon}_${mday}_${hour}_${min}_${sec}";
    $self->{dtSeed}     = "$mon$mday$hour$min$sec";

    return;
}

################################################################################
# Returns date time seed in mmddhhmmss format
################################################################################
sub GetDateTimeSeed {
    my $self = shift;
    $self->SetDate;
    return $self->{dtSeed};
}

################################################################################
# Set current time in seconds and milliseconds from Epoch
################################################################################
sub SetStartTime {
    my $self = shift;
    $self->{dtStart}    = time;
    $self->{dtMsStart}  = [gettimeofday()];
}

################################################################################
# Get current time in seconds from Epoch
################################################################################
sub GetStartTime {
    my $self = shift;
    return time;
}

################################################################################
# Get current time in milliseconds
################################################################################
sub GetStartTimeMilliseconds {
    my $self = shift;
    return [gettimeofday()];
}

################################################################################
# Get original start time in seconds from Epoch
################################################################################
sub GetOrgStartTime {
    my $self = shift;
    return $self->{dtOrgStart};
}

################################################################################
# Get original start time in milliseconds
################################################################################
sub GetOrgStartTimeMilliseconds {
    my $self = shift;
    return $self->{dtOrgMsStart};
}

################################################################################
# Returns date set by SetDate
################################################################################
sub GetDate {
    my $self = shift;
    return $self->{dtDate};
}

################################################################################
# Returns original date set by new()
################################################################################
sub GetOrgDate {
    my $self = shift;
    return $self->{dtOrgDate};
}

################################################################################
# Returns time set by SetDate
################################################################################
sub GetTime {
    my $self = shift;
    return $self->{dtTime};
}

################################################################################
# Returns original time set by new()
################################################################################
sub GetOrgTime {
    my $self = shift;
    return $self->{dtOrgTime};
}

################################################################################
# Returns combined date and time set by SetDate
################################################################################
sub GetDateTime {
    my $self = shift;
    return "$self->{dtDate} $self->{dtTime}";
}

################################################################################
# Returns formatted date/time string for use in file names
################################################################################
sub GetFileDateStamp {
    my $self = shift;
    $self->SetDate;
    return $self->{dtFileDate};
}

################################################################################
# Returns elapsed time in seconds since SetStartTime
################################################################################
sub GetElapsedTimeSeconds {
    my $self = shift;
    return time - $self->{dtStart};
}

################################################################################
# Returns elapsed time in milliseconds since SetStartTime
################################################################################
sub GetElapsedTimeMilliseconds {
    my $self = shift;
    return sprintf("%u", tv_interval($self->{dtMsStart}) * 1000);
}

################################################################################
# Returns elapsed time in seconds.milliseconds since SetStartTime
################################################################################
sub GetElapsedTimeSecondsMilliseconds {
    my $self = shift;
    return sprintf("%.3f", tv_interval($self->{dtMsStart}));
}

################################################################################
# Returns seconds.milliseconds from provided start time (arrayref from gettimeofday)
################################################################################
sub FigureElapsedTimeSecondsMilliseconds {
    my ($self, $m_start) = @_;
    unless (defined $m_start) {
        carp "Start milliseconds not provided\n";
        return "ERROR";
    }
    return sprintf("%.3f", tv_interval($m_start));
}

################################################################################
# Returns milliseconds from provided start time (arrayref from gettimeofday)
################################################################################
sub FigureElapsedTimeMilliseconds {
    my ($self, $m_start) = @_;
    unless (defined $m_start) {
        carp "Start milliseconds not provided\n";
        return "ERROR";
    }
    return sprintf("%u", tv_interval($m_start) * 1000);
}

################################################################################
# Returns seconds from provided start time (epoch seconds)
################################################################################
sub FigureElapsedTimeSeconds {
    my ($self, $start) = @_;
    unless (defined $start) {
        carp "Start seconds from Epoch not provided\n";
        return "ERROR";
    }
    return time - $start;
}

################################################################################
# Returns formatted elapsed time since SetStartTime (e.g., "1 days 2 hours 3 minutes 4 seconds")
################################################################################
sub GetElapsedTimeFormated {
    my $self = shift;
    return _format_duration(time - $self->{dtStart});
}

################################################################################
# Returns formatted elapsed time from provided start time
################################################################################
sub FigureElapsedTimeFormated {
    my ($self, $start) = @_;
    unless (defined $start) {
        carp "Start seconds from Epoch not provided\n";
        return "ERROR";
    }
    return _format_duration(time - $start);
}

################################################################################
# Internal helper to format duration in days, hours, minutes, seconds
################################################################################
sub _format_duration {
    my $seconds = shift;
    my $days    = int($seconds / 86400); $seconds -= $days * 86400;
    my $hours   = int($seconds / 3600);  $seconds -= $hours * 3600;
    my $minutes = int($seconds / 60);    $seconds %= 60;

    return join('', 
        ($days    ? "$days days "    : ''),
        ($hours   ? "$hours hours "  : ''),
        ($minutes ? "$minutes minutes " : ''),
        "$seconds seconds"
    );
}
1;