use v5.18;
use warnings;
use SVG;

package Plot;
our $VERSION = 0.41;
use Scalar::Util qw/looks_like_number/;
use List::Util qw/min max/;
use Plot::Color;
use Plot::Coords;

# default settings
my %default = ( xsize => 600, ysize => 600, margin => 40,
                axis => 1, grid => 1, ticks => 1, dot_radius => 2,
                grid_color => 'rgb(210,210,255)', coor_color => 'rgb(0,15,110)',         # darkblue = 'rgb(0,0,130)'
                xmin => -10, xmax => 10, xlabel => 'X', xscale => 'linear',
                ymin => -10, ymax => 10, ylabel => 'Y', yscale => 'linear'); # or log


sub new {
    my $pkg = shift;
    my $param = (@_ == 1 and ref $_[0] eq 'HASH') ? $_[0] : (@_ % 2) ? {} : {@_};
    for my $key (qw/coor_color grid_color/){
        next unless exists $param->{ $key };
        $param->{ $key } = Plot::Color::fmt( @{$param->{ $key }} ) if ref $param->{ $key } eq 'ARRAY';
        delete $param->{ $key } unless Plot::Color::is( $param->{ $key } );
    }
    for (keys %default) { $param->{$_} //= $default{$_} } # fill missing values with defaults

    my $self = bless { svg => SVG->new( width => $param->{'xsize'}, height => $param->{'ysize'}) };
    $self->{'svgroup'} = $self->{'svg'}->group(
        id => 'group',
        style => {
            stroke => $param->{'coor_color'},
            fill   => $param->{'coor_color'},
            'stroke-width'   => '1',
            'stroke-opacity' => '1',
        },
    );
    $self->{'coords'} = Plot::Coords->new( $param );
    return $self->{'coords'} unless ref $self->{'coords'};
    for (keys %$param, qw/xlabel ylabel/) { $self->{'param'}{$_} = $param->{$_} } # copy

    my $coor = $self->{'coords'};
    state $idnr = 0;
    my $arrow_width = 4;
    my $axis_marker_size = 5;
    my %label_font = ('font-family' => 'Arial', 'font' => ['Arial'], 'letter-spacing' => 3,'font-size' => 14, ); # Arial Helvetica Times Courier Verdana  Menlo ui-monospace

    # background grid
    my $grid_style = { stroke => $self->{'param'}{'grid_color'}  };
    if ($self->{'param'}{'grid'} eq 1 or $self->{'param'}{'grid'} eq 'yes'){
        for my $x ($coor->x_marker_pos) {
            $self->{'svgroup'}->line( id => 'gx'.$x, x1 => $x, y1 => $coor->min_y_px, x2 => $x, y2 => $coor->max_y_px, style => $grid_style);
        }
        for my $y ($coor->y_marker_pos) {
            $self->{'svgroup'}->line( id => 'gy'.$y, x1 => $coor->min_x_px, y1 => $y, x2 => $coor->max_x_px, y2 => $y, style => $grid_style);
        }
    }
    # graph box with marker
    my $box_style = { 'stroke-width' => 2,};
    $self->{'svgroup'}->line( id =>'boxttop',   x1 => $coor->min_x_px, y1 => $coor->min_y_px, x2 => $coor->max_x_px, y2 => $coor->min_y_px, style => $box_style,);
    $self->{'svgroup'}->line( id =>'boxbottom', x1 => $coor->min_x_px, y1 => $coor->max_y_px, x2 => $coor->max_x_px, y2 => $coor->max_y_px, style => $box_style,);
    $self->{'svgroup'}->line( id =>'boxleft',   x1 => $coor->min_x_px, y1 => $coor->min_y_px, x2 => $coor->min_x_px, y2 => $coor->max_y_px, style => $box_style,);
    $self->{'svgroup'}->line( id =>'boxright',   x1 => $coor->max_x_px, y1 => $coor->min_y_px, x2 => $coor->max_x_px, y2 => $coor->max_y_px, style => $box_style,);
    my $marker_style = { stroke => $self->{'param'}{'coor_color'} };
    if ($self->{'param'}{'ticks'} eq 1 or $self->{'param'}{'ticks'} eq 'yes'){
        for my $x ($coor->x_marker_pos) {
            $self->{'svgroup'}->line( id => 'mx'.$x, x1 => $x, y1 => $coor->max_y_px - $axis_marker_size, x2 => $x, y2 => $coor->max_y_px + $axis_marker_size, style => $marker_style);
        }
        for my $y ($coor->y_marker_pos) {
            $self->{'svgroup'}->line( id => 'my'.$y, x1 => $coor->min_x_px - $axis_marker_size, y1 => $y, x2 => $coor->min_x_px + $axis_marker_size, y2 => $y, style => $marker_style);
        }
    }
    my ($did_x_axis, $did_y_axis) = (0, 0);
    if ($self->{'param'}{'axis'} eq 1 or $self->{'param'}{'axis'} eq 'yes') {
        my $axis_style = { 'stroke-width' => 3.5,};
        if ($coor->x_axis_visible){
            $self->{'svgroup'}->line( id =>'xachse', x1 => $coor->min_x_px, y1 => $coor->y0_px, x2 => $coor->max_x_px, y2 => $coor->y0_px,  style => $axis_style, );
            if ($self->{'param'}{'ticks'} eq 1 or $self->{'param'}{'ticks'} eq 'yes'){
                for my $x ($coor->x_marker_pos) {
                    $self->{'svgroup'}->line( id => 'amx'.$x, x1 => $x, y1 => $coor->y0_px - $axis_marker_size, x2 => $x, y2 => $coor->y0_px + $axis_marker_size, style => $marker_style);
                }
            }
            my $points = $self->{'svg'}->get_path(
                x => [$coor->max_x_px, $coor->max_x_px-10, $coor->max_x_px-10],
                y => [$coor->y0_px, $coor->y0_px - $arrow_width, $coor->y0_px + $arrow_width],
                -type => 'polyline',
                -closed => 'true' #specify that the polyline is closed.
            );
            $self->{'svgroup'}->polyline (  %$points,  id =>'arrow'.$idnr++,
                style => { fill => $self->{'param'}{'coor_color'}, stroke => $self->{'param'}{'coor_color'}, 'stroke-width' => 0.1},); # pfeil
            $self->{'svgroup'}->text( id => 'xaxislabel', x => -$coor->y0_px + 20 , y => $self->{'param'}{'xsize'} - 13, style => {%label_font}, transform => 'rotate(-90)'
                                    )->cdata( $self->{'param'}{'xlabel'} );
            for my $x ($coor->x_label_pos) {
                my $lbl = shrink_label_value($x->[0]);
                $self->{'svgroup'}->text( id => 'xnumlabel'.$x->[0], x => $x->[1] + 4 - (6 * length($lbl)), y => $coor->y0_px + 20, style => {%label_font})->cdata($lbl);
            }
            $did_x_axis = 1;
        }
        if ($coor->y_axis_visible){
            $self->{'svgroup'}->line( id =>'yachse', x1 => $coor->x0_px, y1 => $coor->min_y_px, x2 => $coor->x0_px, y2 => $coor->max_y_px, style => { 'stroke-width' => 2.4,},);
            if ($self->{'param'}{'ticks'} eq 1 or $self->{'param'}{'ticks'} eq 'yes'){
                for my $y ($coor->y_marker_pos) {
                    $self->{'svgroup'}->line( id => 'amy'.$y, x1 => $coor->x0_px - $axis_marker_size, y1 => $y, x2 => $coor->x0_px + $axis_marker_size, y2 => $y, style => $marker_style);
                }
            }
            my $points = $self->{'svg'}->get_path(
                x => [$coor->x0_px, $coor->x0_px - $arrow_width, $coor->x0_px + $arrow_width],
                y => [ $coor->min_y_px,  $coor->min_y_px+10,  $coor->min_y_px+10],
                -type => 'polyline',
                -closed => 'true' #specify that the polyline is closed.
            );
            $self->{'svgroup'}->polyline ( %$points, id    =>'arrow'.$idnr++,
                style => { fill => $self->{'param'}{'coor_color'}, stroke => $self->{'param'}{'coor_color'}}, 'stroke-width' => 0.1); # pfeil        }
            $self->{'svgroup'}->text( id => 'yaxislabel', x => $coor->x0_px + 20, y => 16, style => {%label_font})->cdata($self->{'param'}{'ylabel'});
            for my $y ($coor->y_label_pos) {
                my $lbl = shrink_label_value($y->[0]);
                $self->{'svgroup'}->text( id => 'ynumlabel'.$y->[0], x => (-$y->[1] + 4 -(6 * length($lbl))), y => $coor->x0_px - 8, style => {%label_font}, transform => 'rotate(-90)')->cdata( $lbl );
            }
            $did_y_axis = 1;
        }
    }
    unless ($did_x_axis) {
        $self->{'svgroup'}->text( id => 'xaxislabel', x => -$coor->min_y_px + 20 , y => $self->{'param'}{'xsize'} - 13, style => {%label_font}, transform => 'rotate(-90)'
                                )->cdata( $self->{'param'}{'xlabel'} );
        for my $x ($coor->x_label_pos) {
            my $lbl = shrink_label_value($x->[0]);
            $self->{'svgroup'}->text( id => 'xnumlabel'.$x->[0], x => $x->[1] + 4 - (6 * length($lbl)), y => $coor->min_y_px + 20, style => {%label_font})->cdata( $lbl );
        }
    }
    unless ($did_y_axis) {
        $self->{'svgroup'}->text( id => 'yaxislabel', x => $coor->min_x_px + 20, y => 16, style => {%label_font})->cdata($self->{'param'}{'ylabel'});
        for my $y ($coor->y_label_pos) {
            my $lbl = shrink_label_value($y->[0]);
            $self->{'svgroup'}->text( id => 'ynumlabel'.$y->[0], x => (-$y->[1] + 4 -(6 * length($lbl))), y => $coor->x_min_px - 8, style => {%label_font}, transform => 'rotate(-90)')->cdata( $lbl );
        }
    }

    $self;
}

sub shrink_label_value {
    my $val = shift;
    return substr($val, 0, -9).'B' if $val > 5_000_000_000;
    return substr($val, 0, -6).'M' if $val > 5_000_000;
    return substr($val, 0, -3).'k' if $val > 5_000;
    $val;
}

sub dot {
    my ($self, $x, $y, $color, $radius, $form) = @_;
    return unless defined $y or (ref$x eq 'HASH' and exists $x->{'x'} and exists $x->{'y'});
    ($x, $y, $color, $radius, $form) = ($x->{'x'}, $x->{'y'}, $x->{'color'}, $x->{'radius'}, $x->{'form'}) if ref $x eq 'HASH';
    my $pxkoor = $self->{'coords'}->pair_to_px($x, $y);
    return unless ref $pxkoor;
    state $idnr = 0;
    my $id = 'dot'.$idnr++;
    $color = Plot::Color::check($color);
    $radius = $radius || $self->{'param'}{'dot_radius'};
    $form = $form // 'circle';
    $form = int rand 9 if $form eq 'random';
    my $style = { stroke => $color, fill => $color, 'fill-opacity' => 1, 'stroke-width' => $radius, 'stroke-opacity' => 1};
    if ($form eq 'circle' or $form eq 0 ){
        $self->{'svgroup'}->circle( cx => $pxkoor->[0], cy => $pxkoor->[1], r => $radius, id => $id, style => $style);
    } elsif ($form eq 'ellipse_x' or $form eq 1){
        $self->{'svgroup'}->ellipse( cx => $pxkoor->[0], cy => $pxkoor->[1], rx => $radius*1.5, ry => $radius/1.5, id => $id, style => $style);
    } elsif ($form eq 'ellipse_y' or $form eq 2){
        $self->{'svgroup'}->ellipse( cx => $pxkoor->[0], cy => $pxkoor->[1], rx => $radius/1.5, ry => $radius*1.5, id => $id, style => $style);
    } elsif ($form eq 'square' or $form eq 3){ $self->square($x, $y, $color, $radius)
    } elsif ($form eq 'cross'  or $form eq 4){ $self->cross($x, $y, $color, $radius)
    } elsif ($form eq 'x'      or $form eq 5){ $self->xdot($x, $y, $color, $radius)
    } elsif ($form eq 'tri_up'  or $form eq 6){ $self->xdot($x, $y, $color, $radius, 'up')
    } elsif ($form eq 'tri_down' or $form eq 7){ $self->xdot($x, $y, $color, $radius, 'down')
    }
    $self;
}



sub square {
    my ($self, $x, $y, $color, $radius) = @_;
    return unless defined $y or (ref $x eq 'HASH' and exists $x->{'x'} and exists $x->{'y'});
    my $pxkoor = $self->{'coords'}->pair_to_px($x, $y);
    return unless ref $pxkoor;
    state $idnr = 0;
    my $id = 'square'.$idnr++;
    $color = Plot::Color::check($color);
    $radius ||= $self->{'param'}{'dot_radius'};
    my $points = $self->{'svgroup'}->get_path( x =>  [$pxkoor->[0]-$radius,$pxkoor->[0]+$radius,$pxkoor->[0]+$radius,$pxkoor->[0]-$radius],
                                               y =>  [$pxkoor->[1]-$radius,$pxkoor->[1]-$radius,$pxkoor->[1]+$radius,$pxkoor->[1]+$radius], -type =>'polygon');
    $self->{'svgroup'}->polygon( %$points, id => $id, style => { stroke => $color, fill => $color, 'fill-opacity' => '1', 'stroke-width' => $radius, 'stroke-opacity' => '1'});
#    $self->{'svgroup'}->rectangle( x => $pxkoor->[0] + ($r/2), y => $pxkoor->[1] + ($r/2),  width  => $radius, height => $radius,  id => 'sqr'.$idnr++, style => { stroke => $color, fill => $color },);
    $self;
}

sub cross {
    my ($self, $x, $y, $color, $radius) = @_;
    return unless defined $y or (ref $x eq 'HASH' and exists $x->{'x'} and exists $x->{'y'});
    my $p = $self->{'coords'}->pair_to_px($x, $y);
    return unless ref $p;
    state $idnr = 0;
    my $id = 'cross'.$idnr++;
    $color = Plot::Color::check($color);
    $radius ||= $self->{'param'}{'dot_radius'};
    my $style = {'stroke-width' => $radius/3, stroke => $color };
    $self->{'svgroup'}->line( id => 'v'.$id, style => $style, x1 => $p->[0]-$radius, y1 => $p->[1], x2 => $p->[0]+$radius, y2 => $p->[1] );
    $self->{'svgroup'}->line( id => 'h'.$id, style => $style, x1 => $p->[0], y1 => $p->[1]-$radius, x2 => $p->[0], y2 => $p->[1]+$radius );
    $self;
}

sub xdot {
    my ($self, $x, $y, $color, $radius) = @_;
    return unless defined $y or (ref $x eq 'HASH' and exists $x->{'x'} and exists $x->{'y'});
    my $p = $self->{'coords'}->pair_to_px($x, $y);
    return unless ref $p;
    state $idnr = 0;
    my $id = 'xdot'.$idnr++;
    $color = Plot::Color::check($color);
    $radius ||= $self->{'param'}{'dot_radius'};
    my $style = {'stroke-width' => $radius/3, stroke => $color };
    $self->{'svgroup'}->line( id => 'loru'.$id, style => $style, x1 => $p->[0]-$radius, y1 => $p->[1]+$radius, x2 => $p->[0]+$radius, y2 => $p->[1]-$radius );
    $self->{'svgroup'}->line( id => 'luro'.$id, style => $style, x1 => $p->[0]-$radius, y1 => $p->[1]-$radius, x2 => $p->[0]+$radius, y2 => $p->[1]+$radius );
    $self;
}

my $sqrt3 = 1.732050808;
sub triangle {
    my ($self, $x, $y, $color, $radius, $dir) = @_; # left right up down
    return unless defined $y or (ref $x eq 'HASH' and exists $x->{'x'} and exists $x->{'y'});
    my $pxkoor = $self->{'coords'}->pair_to_px($x, $y);
    return unless ref $pxkoor;
    state $idnr = 0;
    my $id = 'triangle'.$idnr++;
    $color = Plot::Color::check($color);
    $radius ||= $self->{'param'}{'dot_radius'}; # outer
    $dir //= 'up'; # outer
    my $lr = $radius * $sqrt3 / 2; # inner
    my $r2 = $radius / 2; # inner
    my (@x, @y);
    if ($dir eq 'up'){ 
        @x = ($pxkoor->[0],         $pxkoor->[0]+$lr, $pxkoor->[0]-$lr );
        @y = ($pxkoor->[1]-$radius, $pxkoor->[1]+$r2, $pxkoor->[1]+$r2 );
    } elsif ($dir eq 'down'){ 
        @x = ($pxkoor->[0],         $pxkoor->[0]+$lr, $pxkoor->[0]-$lr );
        @y = ($pxkoor->[1]+$radius, $pxkoor->[1]-$r2, $pxkoor->[1]-$r2 );
    } elsif ($dir eq 'left'){ 
        @x = ($pxkoor->[1]-$radius, $pxkoor->[1]+$r2, $pxkoor->[1]+$r2 );
        @y = ($pxkoor->[0],         $pxkoor->[0]+$lr, $pxkoor->[0]-$lr );
    } elsif ($dir eq 'right'){ 
        @x = ($pxkoor->[1]+$radius, $pxkoor->[1]-$r2, $pxkoor->[1]-$r2 );
        @y = ($pxkoor->[0],         $pxkoor->[0]+$lr, $pxkoor->[0]-$lr );
    }
    my $points = $self->{'svgroup'}->get_path( x =>  \@x, y =>  \@y, -type =>'polygon', -closed => 1 );
    $self->{'svgroup'}->polygon( %$points, id => $id, style => { stroke => $color, fill => $color, 'fill-opacity' => '1', 'stroke-width'   => $radius, 'stroke-opacity' => '1'});
    $self;
}

sub line {
    my ($self, $x1, $y1, $x2, $y2, $color, $radius) = @_;
    return unless defined $y2 or (ref $x1 eq 'HASH' and exists $x1->{'x1'} and exists $x1->{'y1'} and exists $x1->{'x2'} and exists $x1->{'y2'});
    ($x1, $y1, $x2, $y2, $color, $radius) = ($x1->{'x1'}, $x1->{'y1'}, $x1->{'x2'}, $x1->{'y2'}, $x1->{'color'}, $x1->{'radius'}) if ref $x1 eq 'HASH';
    my $p1 = $self->{'coords'}->pair_to_px($x1, $y1);
    my $p2 = $self->{'coords'}->pair_to_px($x2, $y2);
    return unless ref $p1 and ref $p2;
    $color = Plot::Color::check( $color );
    state $idnr = 0;
    my $id = 'line'.$idnr++;
    $radius ||= $self->{'param'}{'dot_radius'};
    $self->{'svgroup'}->line( id => $id, style => {'stroke-width' => $radius, stroke => $color }, x1 => $p1->[0], y1 => $p1->[1], x2 => $p2->[0], y2 => $p2->[1]);
    $self;
}

sub curve {
    my ($self, $xo, $yo, $color, $radius) = @_;
    return unless ref $xo eq 'ARRAY';
    return unless ref $yo eq 'ARRAY';
    my @x = map { $self->{'coords'}->x_to_px($_) } @$xo;
    my @y = map { $self->{'coords'}->y_to_px($_) } @$yo;
    $color = Plot::Color::check( $color );
    $radius ||= $self->{'param'}{'dot_radius'};
    state $idnr = 0;
    my $points = $self->{'svg'}->get_path(  x => \@x, y => \@y, -type => 'polyline', id => 'pl'.$idnr, -closed => 'true' );
    $self->{'svgroup'}->polyline(
        %$points, id => 'snake'.$idnr++,
        style => { 'stroke' => $color, 'stroke-width' => $radius, 'fill-opacity' => 0,}, #'fill' => $c,
    );
    $self;
}

sub label {
    my ($self, $text, $x, $y, $color ) = @_;
    return unless exists $y;
    my $pxkoor = $self->{'coords'}->pair_to_px($x, $y);
    return unless ref $pxkoor;
    state $idnr = 0;
    my $id = 'label'.$idnr++;
    $color //=  $self->{'param'}{'grid_color'};
    $color = Plot::Color::check($color);
    $self->{'svgroup'}->text( id => $id, x => $pxkoor->[0], y => $pxkoor->[1], 
                               style => $self->{'param'}{'label_font'}       )->cdata($text);
    $self;
}

sub function {
    my $self = shift;
    my ($func, $c, $r, $deltax, $dots) = @_;
    return unless ref $func eq 'CODE';
    state $idnr = 0;
    my (@x, @y);
    for (my $x = $self->{'coords'}->min_x; $x <= $self->{'coords'}->max_x; $x += $deltax){
        my $y = $func->($x);
        next if $y < $self->{'coords'}->min_y or $y > $self->{'coords'}->max_y;
        push @x, $x;
        push @y, $y;
    }
    if (defined $dots and $dots){
        $self->paint_dot( $x[$_], $y[$_], $c, $r // 1) for 0 .. $#x;
    } 
    else { $self->paint_curve(\@x, \@y, $c, $r) }
}
################################################################################
sub print {
    my $self = shift;
    print $self->{'svg'}->xmlify;
}

sub save {
    my ($self, $file) = @_;
    open my $FH, '>', $file or die "can not write file: $file";
    print $FH $self->{'svg'}->xmlify;
    close $FH;
}

1;

__END__

sub tile { #! FIXME
    my $self = shift;
    state $idnr = 0;
    my ($xl, $xr, $yu, $yo, $color, $radius) = @_;
    my $lukoor = $self->koor($xl, $yu);
    my $rokoor = $self->koor($xr, $yo);
    return unless ref $lukoor and ref $rokoor;
    $color = Plot::Color::check($color);
    $radius ||= $self->{'param'}{'dot_radius'}; # outer
    my $points = $self->{'svg'}->get_path(
#             x => [200, 300, 300, 200,200],
             x => [$lukoor->[0], $rokoor->[0], $rokoor->[0], $lukoor->[0], $lukoor->[0],],
#             y => [100, 100, 200, 200,100],
             y => [$lukoor->[1], $lukoor->[1], $rokoor->[1], $rokoor->[1], $lukoor->[1],],
         -type => 'polyline',
       -closed => 'true' #specify that the polyline is closed.
   );
    $self->{'svgroup'}->polyline (
        %$points, id    =>'tile'.$idnr++,
        style => { stroke => $color, 'fill-opacity' => 0, 'stroke-width' => $radius, , -closed => 'true' }, );
    $self;
}

sub conic_section { #! FIXME
    my $self = shift;
    state $idnr = 0;
    my ($a, $b, $c, $d, $e, $f, $col, $tol) = @_;
    my $inc = min($self->{'xdelta'}, $self->{'ydelta'}) / $self->{'xsize'}/2 ; # buggy translation ysize?
    my $ba = abs $b;
    $col = Plot::Color::check( $col );
    $tol ||= 0.03;
    for (my $x = $self->{'xmin'}; $x <= $self->{'xmax'}; $x += $inc){
        for (my $y = $self->{'ymin'}; $y <= $self->{'ymax'}; $y += $inc){
            my $s = ($a*$x*$x) + ($b*$x*$y) + ($c*$y*$y) + ($d*$x) + ($e*$y) + $f;
            if (-$tol < $s and $s < $tol) {
                my $pxkoor = $self->{'coords'}->pair_to_px($x, $y);
                next unless ref $pxkoor;
                $self->{'svgroup'}->circle( cx => $pxkoor->[0], cy => $pxkoor->[1], r => 0.2,
                                            id => 'dot'.$idnr++, style => { stroke => $col, fill => $col },);
            }
        }
    }
    $self;
}
my $tag = $svg->title(id=>'document-title')->cdata('This is the title');
my $tag = $svg->desc(id=>'document-desc')->cdata('This is a description');
my $tag = $svg->comment('comment 1','comment 2','comment 3');
