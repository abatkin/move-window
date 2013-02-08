#!/usr/bin/perl

# Move a window one monitor to the right or left

use strict;
use warnings;

if (@ARGV !=1) {
    usage();
}

my $direction = getDirection($ARGV[0]);
my $monitors = parseMonitors();
my $windowid = getActiveWindowId();
my $geometry = getWindowGeometry($windowid);
my $currentMonitorIndex = getCurrentMonitorForWindow($windowid, $monitors, $geometry);

if ($currentMonitorIndex == -1) {
    print "Unknown Monitor\n";
    exit(1);
}

my $newIndex = $currentMonitorIndex + $direction;

if ($newIndex < 0 || $newIndex >= @{$monitors}) {
    exit 0;
}

my $newGeometry = calculateMovedGeometry($geometry, $monitors->[$currentMonitorIndex], $monitors->[$newIndex]);
moveWindow($windowid, $newGeometry);

exit(0);

sub moveWindow {
    my $windowid = shift;
    my ($windowX, $windowY, $windowWidth, $windowHeight) = @{shift()};

    my @maxList = getMaximizedState($windowid);
    system('wmctrl', '-ir', $windowid, '-b', 'remove,' . join(',', @maxList)) if @maxList;
    system('xdotool', 'windowmove', $windowid, $windowX, $windowY);
    system('wmctrl', '-ir', $windowid, '-b', 'add,' . join(',', @maxList)) if @maxList;
}

sub getDirection {
    if ($_[0] eq 'left') {
        return -1;
    } elsif ($_[0] eq 'right') {
        return 1;
    }
    usage();
}

sub parseMonitors {
    my @monitors = ();
    foreach my $line (`xrandr --current`) {
        chomp $line;
        next if $line !~ / connected /;
        my $specString = (split(/ /, $line))[2];
        next if $specString !~ /^(\d+)x(\d+)([+-]\d+)([+-]\d+)$/;
        my $width = $1;
        my $height = $2;
        my $offsetX = $3;
        my $offsetY = $4;
        my $xStart = $offsetX + 0;
        my $xEnd = $xStart + $width;
        push @monitors, [$xStart, $xEnd];
    }
    @monitors = sort {$a->[0] <=> $b->[0]} @monitors;
    return \@monitors;
}

sub getActiveWindowId {
    my $windowid = `xdotool getactivewindow`;
    chomp($windowid);
    return $windowid;
}

sub getWindowGeometry {
    my $windowid = shift;
    my $positionString = `xwininfo -id $windowid`;
    my ($rawX) = $positionString =~ /Absolute upper-left X:\s+(-?\d+)/;
    my ($rawY) = $positionString =~ /Absolute upper-left Y:\s+(-?\d+)/;
    my ($offsetX) = $positionString =~ /Relative upper-left X:\s+(-?\d+)/;
    my ($offsetY) = $positionString =~ /Relative upper-left Y:\s+(-?\d+)/;
    my $windowX = $rawX - $offsetX;
    my $windowY = $rawY - $offsetY;

    my $geometryString = `xdotool getwindowgeometry -s $windowid`;
    my ($windowWidth) = $geometryString =~ /WIDTH=(\d+)/;
    my ($windowHeight) = $geometryString =~ /HEIGHT=(\d+)/;

    return [$windowX, $windowY, $windowWidth, $windowHeight];
}

sub getMaximizedState {
    my $windowid = shift;
    my $stateString = `xprop -id $windowid _NET_WM_STATE`;
    my @maxList = ();
    push @maxList, 'maximized_horz' if $stateString =~ /_NET_WM_STATE_MAXIMIZED_HORZ/;
    push @maxList, 'maximized_vert' if $stateString =~ /_NET_WM_STATE_MAXIMIZED_VERT/;
    return @maxList;
}

sub getCurrentMonitorForWindow {
    my $windowid = shift;
    my @monitors = @{shift()};
    my ($windowX, $windowY, $windowWidth, $windowHeight) = @{shift()};
    my $windowRight = $windowX + $windowWidth;

    my $monitorIndex = -1;
    my $maxPercent = 0;
    for (my $i = 0; $i < @monitors; $i++) {
        my ($monStart, $monEnd) = @{$monitors[$i]};
        my $xOnStart = $windowX;
        if ($xOnStart < $monStart) {
            $xOnStart = $monStart;
        }
        my $xOnEnd = $windowRight;
        if ($xOnEnd > $monEnd) {
            $xOnEnd = $monEnd;
        }
        my $onWidth = $xOnEnd - $xOnStart;
        next if $onWidth < 1;
        my $percentOn = $onWidth / $windowWidth;
        if ($percentOn > $maxPercent) {
            $monitorIndex = $i;
            $maxPercent = $percentOn;
        }
    }
    return $monitorIndex;
}

sub calculateMovedGeometry {
    my ($windowX, $windowY, $windowWidth, $windowHeight) = @{shift()};
    my ($oldMonStart, $oldMonEnd) = @{shift()};
    my ($newMonStart, $newMonEnd) = @{shift()};
    my $fromLeft = $windowX - $oldMonStart;
    my $newX = $newMonStart + $fromLeft;
    return [$newX, $windowY, $windowWidth, $windowHeight];
}

sub usage {
    print "Usage: $0 left|right\n";
    exit(1);
}


