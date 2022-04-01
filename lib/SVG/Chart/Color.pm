use v5.18;
use warnings;

package Plot::Color;
our $VERSION = 0.1;


sub rainbow {
    my $nr = shift; # 0 .. 10
    my $r = 200 - ($nr*24);
    my $g = 200 - abs ($nr - 5) * 48 ;
    my $b =   0 + ($nr*24);
    fmt($r, $g, $b);
}

sub check {
    my $c = shift;
    $c = random() if not defined $c or not $c or $c eq 'random';
    $c = fmt(@$c) if ref $c eq 'ARRAY';
    $c;
}

sub random { fmt((int rand 255),(int rand 255),(int rand 255)) }

sub fmt { 'rgb('.(shift).','.(shift).','.(shift).')' }

sub is  { $_[0] =~ /^rgb\(\s*(\d+)\s*, \s*(\d+)\s*, \s*(\d+)\s* \)$/ and $1 < 256 and $2 < 256 and $3 < 256 }

1;
