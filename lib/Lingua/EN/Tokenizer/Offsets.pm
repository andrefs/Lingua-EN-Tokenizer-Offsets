use strict;
use warnings;
package Lingua::EN::Tokenizer::Offsets;
use utf8::all;
use Data::Dump qw/dump/;

use base 'Exporter';
our @EXPORT_OK = qw/
					tokenize
				/;


# ABSTRACT: Doesn't matter what it does, it is awesome anyway! (TODO: change this -- ups!)



sub tokenize {
	my ($text) = @_;
	my $end;
	my $text_end = length($text);
	my $offsets = [[0,$text_end]];

	# token patterns
	my @patterns = (
		qr{([^\p{IsAlnum}\s\.\'\`\,\-])},
		qr{(?<!\p{IsN})(),()(?!\d)},
		qr{(?<=\p{IsN})(),()(?!\d)},
		qr{(?<!\p{IsN})(),()(?=\d)},
		qr{(?<!\p{isAlpha})()['`]()(?!\p{isAlpha})},
		qr{(?<!\p{isAlpha})()['`]()(?=\p{isAlpha})},
		qr{(?<=\p{isAlpha})()['`]()(?!\p{isAlpha})},

		qr{(?<=\p{isAlpha})['`]()(?=\p{isAlpha})},
	);

	my $split = 1;
	while ($split){
		$split = 0;
		for my $pat (@patterns){
			my $size = @$offsets;
        	for(my $i=0; $i<$size; $i++){
				my $start  = $offsets->[$i][0];
				my $length = $offsets->[$i][1]-$start;
				my $s = substr($text,$start,$length);

				my $split_points = [];
				while($s =~ /(?<!^)$pat(?!$)/g){
say STDERR "got one!";
                    my $end   = $-[1];
                    my $begin = $+[1];
                    push @$split_points,[$start+$end,$start+$begin];
					if ($-[2]){
						my $end   = $-[2];
                    	my $begin = $+[2];
                    	push @$split_points,[$start+$end,$start+$begin];
					}
                	$split = 1;
				}
				_split_tokens($offsets,$i,[ sort { $a->[0] <=> $b->[0] } @$split_points ]) if @$split_points;
			}
		}
	}
	return $offsets;
}

sub _split_tokens {
    my ($offsets,$i,$split_points) = @_;
    my ($end,$start) = @{shift @$split_points};
    my $last = $offsets->[$i][1];
    $offsets->[$i][1] = $end;
    while(my $p = shift @$split_points){
        push @$offsets, [$start,$p->[0]];
        $start = $p->[1];
    }
    push @$offsets, [$start, $last];
}


=method offsets2tokens

Given a list of token boundaries offsets and a text, returns an array with the text split into tokens.

=cut

sub offsets2tokens {
    my ($text, $offsets) = @_;
    my $tokens = [];
    foreach my $o ( sort {$a->[0] <=> $b->[0]} @$offsets) {
        my $start = $o->[0];
        my $length = $o->[1]-$o->[0];
        push @$tokens, substr($text,$start,$length);
    }
    return $tokens;
}


1;
