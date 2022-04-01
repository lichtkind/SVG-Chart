use v5.18;
use warnings;

package Plot::Coords;
our $VERSION = 0.1;
use Scalar::Util qw/looks_like_number/;
use List::Util qw/min max/;

sub new {
    my ($pkg, $param) = @_; # 
    
    if (ref $param->{'data'} eq 'ARRAY'){
        for my $p (@{$param->{'data'}}){
            if (ref $p eq 'ARRAY'){
                $param->{'xmax'} = $p->[0] if $p->[0] > $param->{'xmax'};
                $param->{'ymax'} = $p->[1] if $p->[1] > $param->{'ymax'};
                $param->{'xmin'} = $p->[0] if $p->[0] < $param->{'xmin'};
                $param->{'ymin'} = $p->[1] if $p->[1] < $param->{'ymin'};
            } elsif (ref $p eq 'HASH'){
                $param->{'xmax'} = $p->{'x'} if $p->{'x'} > $param->{'xmax'};
                $param->{'ymax'} = $p->{'y'} if $p->{'y'} > $param->{'ymax'};
                $param->{'xmin'} = $p->{'x'} if $p->{'x'} < $param->{'xmin'};
                $param->{'ymin'} = $p->{'y'} if $p->{'y'} < $param->{'ymin'};
            } else { }
        }
    }
    my $self = {};
    $self->{$_} = $param->{$_} for qw/margin/;

    $self->{'scale'}       =  {x => substr($param->{'xscale'}, 0, 3), 
                               y => substr($param->{'yscale'}, 0, 3) };
    $self->{'px'} = { size => {x => $param->{'xsize'},  y => $param->{'ysize'} },
                   visible => {x => $param->{'xsize'} - (2* $param->{'margin'}),
                               y => $param->{'ysize'} - (2* $param->{'margin'}) },
                       min => {x => $param->{'margin'}, y => $param->{'margin'}}, # 0 = left upper
                       max => {x => $param->{'xsize'} - $param->{'margin'},
                               y => $param->{'ysize'} - $param->{'margin'} },  
    };
    $self->{'coor'} ={size => {x => $param->{'xmax'}  - $param->{'xmin'},
                               y => $param->{'ymax'}  - $param->{'ymin'} },
                       min => {x => $param->{'xmin'},   y => $param->{'ymin'}},
                       max => {x => $param->{'xmax'},   y => $param->{'ymax'}},
              axis_visible => {x =>($param->{'ymin'} <= 0 and $param->{'ymax'} >= 0),
                               y =>($param->{'xmin'} <= 0 and $param->{'xmax'} >= 0)},
    };
    $self->{'coor'}{'visible'} = $self->{'coor'}{'size'};

    return if $self->{'px'}{'visible'}{'x'} <= 0 or $self->{'px'}{'visible'}{'y'} <= 0
           or $self->{'coor'}{'visible'}{'x'} <= 0 or $self->{'coor'}{'visible'}{'y'} <= 0;

    # compute constants for coordinate transformation into pixel
    my ($coorlenx, $coorleny);
    if ($self->{'scale'}{'x'} eq 'log'){
        my $logmin = log (1 + abs($self->{'coor'}{'min'}{'x'}));
        my $logmax = log (1 + abs($self->{'coor'}{'max'}{'x'}));
        my $minmax_signum = ($self->{'coor'}{'min'}{'x'} <=> 0) * ($self->{'coor'}{'max'}{'x'} <=> 0); # 1 if min & max value have same sign else -1
        $coorlenx = $logmin == 0 ? $logmax :
                    $logmax == 0 ? $logmin : abs($logmax - ($minmax_signum * $logmin));
        $self->{'c2p_offset'}{'x'} = $self->{'px'}{'min'}{'x'} - (($self->{'coor'}{'min'}{'x'} <=> 0) * $logmin / $coorlenx * $self->{'px'}{'visible'}{'x'});
    } else {
        $coorlenx = $self->{'coor'}{'size'}{'x'};
        $self->{'c2p_offset'}{'x'} = $self->{'px'}{'min'}{'x'} - ($self->{'coor'}{'min'}{'x'} / $coorlenx * $self->{'px'}{'visible'}{'x'});
    }
    if ($self->{'scale'}{'y'} eq 'log'){
        my $logmin = log (1 + abs($self->{'coor'}{'min'}{'y'}));
        my $logmax = log (1 + abs($self->{'coor'}{'max'}{'y'}));
        my $minmax_signum = ($self->{'coor'}{'min'}{'y'} <=> 0) * ($self->{'coor'}{'max'}{'y'} <=> 0);
        $coorleny = $logmin == 0 ? $logmax :
                    $logmax == 0 ? $logmin : abs($logmax - ($minmax_signum * $logmin));
        $self->{'c2p_offset'}{'y'} = $self->{'px'}{'min'}{'y'} + (($self->{'coor'}{'max'}{'y'} <=> 0) * $logmax / $coorleny * $self->{'px'}{'visible'}{'y'});
    } else {
        $coorleny = $self->{'coor'}{'size'}{'y'};
        $self->{'c2p_offset'}{'y'} = $self->{'px'}{'min'}{'y'} + ($self->{'coor'}{'max'}{'y'} / $coorleny * $self->{'px'}{'visible'}{'y'});
    }
    $self->{'c2p_factor'} = { x => $self->{'px'}{'visible'}{'x'} / $coorlenx,
                              y => $self->{'px'}{'visible'}{'y'} / $coorleny, };
    bless $self;

    # Marker & label pos
    my ($x_step, $x_abs_max) = (1, max( abs($param->{'xmin'}), abs($param->{'xmax'}) ) );
    my ($y_step, $y_abs_max) = (1, max( abs($param->{'ymin'}), abs($param->{'ymax'}) ) );
    if ($x_abs_max > 10){
        $x_step *= 10 while $x_abs_max / $x_step > 10;
        $x_step /= 2  if $x_abs_max / $x_step < 4;
    } elsif ($x_abs_max < 4){
        $x_step /= 10 while $x_abs_max / $x_step < 4;
        $x_step *= 2  if $x_abs_max / $x_step > 10;
    }
    if ($y_abs_max > 10){
        $y_step *= 10 while $y_abs_max / $y_step > 10;
        $y_step /= 2  if $y_abs_max / $y_step < 4;
    } elsif ($y_abs_max < 4){
        $y_step /= 10 while $y_abs_max / $y_step < 4;
        $y_step *= 2  if $y_abs_max / $y_step > 10;
    }
    my $xmin_mark = int($param->{'xmin'} / $x_step) * $x_step;
    $xmin_mark += $x_step if $param->{'xmin'} > 0;
    my $xmax_mark = int($param->{'xmax'} / $x_step) * $x_step;
    $xmax_mark -= $x_step if $param->{'xmax'} < 0;

    for (my $x = $xmin_mark; $x <= $xmax_mark; $x += $x_step) {
        push @{$self->{'marker'}{'pos'}{'x'}}, $self->x_to_px( $x );
        push @{$self->{'label'}{'pos'}{'x'}}, [$x, $self->{'marker'}{'pos'}{'x'}[-1]] if substr(($x / $x_step), -1) == 5 and $x != $xmax_mark;
    }
    push @{$self->{'label'}{'pos'}{'x'}}, [$xmin_mark, $self->{'marker'}{'pos'}{'x'}[0]]
                                        , [$xmax_mark, $self->{'marker'}{'pos'}{'x'}[-1]];
    push @{$self->{'label'}{'pos'}{'x'}}, [0, $self->{'c2p_offset'}{'x'}] if $param->{'xmin'} < 0 and $param->{'xmax'} > 0 ;

    my $x1_pos = $self->x_to_px($x_step);
    my $x_1_pos = $self->x_to_px(-$x_step);
    push @{$self->{'label'}{'pos'}{'x'}}, [$x_step, $x1_pos] if defined $x1_pos;
    push @{$self->{'label'}{'pos'}{'x'}}, [-$x_step, $x_1_pos] if defined $x_1_pos;
    
    my $ymin_mark = int($param->{'ymin'} / $y_step) * $y_step;
    $ymin_mark += $y_step if $param->{'ymin'} > 0;
    my $ymax_mark = int($param->{'ymax'} / $y_step) * $y_step;
    $ymax_mark -= $y_step if $param->{'ymax'} < 0;
    for (my $y = $ymin_mark; $y <= $ymax_mark; $y += $y_step) {
        push @{$self->{'marker'}{'pos'}{'y'}}, $self->y_to_px( $y );
        push @{$self->{'label'}{'pos'}{'y'}}, [$y, $self->{'marker'}{'pos'}{'y'}[-1]] if substr(($y / $y_step), -1) == 5 and $y != $ymax_mark;
    }
    push @{$self->{'label'}{'pos'}{'y'}}, [$ymin_mark, $self->{'marker'}{'pos'}{'y'}[0]]
                                        , [$ymax_mark, $self->{'marker'}{'pos'}{'y'}[-1]];
    push @{$self->{'label'}{'pos'}{'y'}}, [0, $self->{'c2p_offset'}{'y'}] if $param->{'ymin'} < 0 and $param->{'ymax'} > 0;
    my $y1_pos = $self->y_to_px($y_step);
    my $y_1_pos = $self->y_to_px(-$y_step);
    push @{$self->{'label'}{'pos'}{'y'}}, [$y_step, $y1_pos] if defined $y1_pos;
    push @{$self->{'label'}{'pos'}{'y'}}, [-$y_step, $y_1_pos] if defined $y_1_pos;
    $self;
}

########################################################################

sub min_x_px { $_[0]->{'px'}{'min'}{'x'} }
sub min_y_px { $_[0]->{'px'}{'min'}{'x'} }
sub x0_px    { $_[0]->{'c2p_offset'}{'x'} }
sub y0_px    { $_[0]->{'c2p_offset'}{'y'} }
sub max_x_px { $_[0]->{'px'}{'max'}{'x'} }
sub max_y_px { $_[0]->{'px'}{'max'}{'x'} }

sub min_x { $_[0]->{'coor'}{'min'}{'x'} }
sub min_y { $_[0]->{'coor'}{'min'}{'y'} }
sub max_x { $_[0]->{'coor'}{'max'}{'x'} }
sub max_y { $_[0]->{'coor'}{'max'}{'y'} }

sub x_axis_visible { $_[0]->{'coor'}{'axis_visible'}{'x'} }
sub y_axis_visible { $_[0]->{'coor'}{'axis_visible'}{'y'} }

sub x_marker_pos { @{$_[0]->{'marker'}{'pos'}{'x'}} }
sub y_marker_pos { @{$_[0]->{'marker'}{'pos'}{'y'}} }
sub x_label_pos  { @{$_[0]->{'label'}{'pos'}{'x'}} }
sub y_label_pos  { @{$_[0]->{'label'}{'pos'}{'y'}} }

########################################################################

sub x_to_px {
    my ($self, $x) = @_;
    return if not looks_like_number($x) or $x < $self->{'coor'}{'min'}{'x'} or $x > $self->{'coor'}{'max'}{'x'};
    $self->{'scale'}{'x'} eq 'log' 
        ? $self->{'c2p_offset'}{'x'} + (($x <=> 0) * log(1 + abs $x) * $self->{'c2p_factor'}{'x'})
        : $self->{'c2p_offset'}{'x'} +  $x * $self->{'c2p_factor'}{'x'};
}
sub y_to_px {
    my ($self, $y) = @_;
    return if not looks_like_number($y) or $y < $self->{'coor'}{'min'}{'y'} or $y > $self->{'coor'}{'max'}{'y'};
    $self->{'scale'}{'y'} eq 'log' 
        ? $self->{'c2p_offset'}{'y'} - (($y <=> 0) * log(1 + abs $y) * $self->{'c2p_factor'}{'y'})
        : $self->{'c2p_offset'}{'y'} -  $y * $self->{'c2p_factor'}{'y'};
}
sub pair_to_px {
    my ($self, $x, $y) = @_;
    ($x, $y) = @$x if ref $x eq 'ARRAY';
    my $rx = $self->x_to_px($x);
    my $ry = $self->y_to_px($y);
    return [$rx, $ry] if defined $rx and defined $ry;
}

########################################################################
1;

my $e = 2.718281828459045;
my $log_rebase = log 10;
