use strict;
use warnings;
package Lingua::EN::Tokenizer::Offsets;
use utf8::all;
use Data::Dump qw/dump/;
use feature qw/say/;

use base 'Exporter';
our @EXPORT_OK = qw/
					initial_offsets
					token_offsets
					adjust_offsets
					get_tokens
				/;


# ABSTRACT: Doesn't matter what it does, it is awesome anyway! (TODO: change this -- ups!)




=method get_offsets

Takes text input and returns reference to array containin pairs of character
offsets, corresponding to the tokens start and end positions.

=cut

sub token_offsets {
    my ($text) = @_;
    return [] unless defined $text;
    my $offsets = initial_offsets($text);
       $offsets = adjust_offsets($text,$offsets);
    return $offsets;
}


=method get_tokens 

Takes text input and splits it into tokens.

=cut

sub get_tokens {
    my ($text)  = @_;
    my $offsets = token_offsets($text);
    my $tokens  = offsets2tokens($text,$offsets);
    return $tokens;
}



=method adjust_offsets 

Minor adjusts to offsets (leading/trailing whitespace, etc)

=cut

sub adjust_offsets {
    my ($text,$offsets) = @_;
    my $size = @$offsets;
    for(my $i=0; $i<$size; $i++){
        my $start  = $offsets->[$i][0];
        my $end    = $offsets->[$i][1];
        my $length = $end - $start;
		if ($length <= 0){
			delete $offsets->[$i];
			next;
		}
        my $s = substr($text,$start,$length);
        if ($s =~ /^\s*$/){
            delete $offsets->[$i];
            next;
        }
        $s =~ /^(\s*).*?(\s*)$/s;
        if(defined($1)){ $start += length($1); }
        if(defined($2)){ $end   -= length($2); }
        $offsets->[$i] = [$start, $end];
    }
    my $new_offsets = [ grep { defined } @$offsets ];
    return $new_offsets;
}

sub initial_offsets {
	my ($text) = @_;
	my $end;
	my $text_end = length($text);
	my $offsets = [[0,$text_end]];

	# token patterns
	my @patterns = (
		qr{([^\p{IsAlnum}\s\.\'\`\,\-])},
		qr{(?<!\p{IsN})(,)(?!\d)},
		qr{(?<=\p{IsN})(,)(?!\d)},
		qr{(?<!\p{IsN})(,)(?=\d)},
		qr{(?<!\p{isAlpha})(['`])(?!\p{isAlpha})},
		qr{(?<!\p{isAlpha})(['`])(?=\p{isAlpha})},
		qr{(?<=\p{isAlpha})(['`])(?!\p{isAlpha})},
		qr{(?:^|\s)(\S+)(?:$|\s)},
		qr{(?:^|[^\.])(\.\.\.)(?:$|[^\.])},

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

				if($s =~ /^$pat(?!$)/g){
   					my $first = $-[1];
                    push @$split_points,[$start+$first,$start+$first];
					my $second = $+[1];
                    push @$split_points,[$start+$second,$start+$second] if $first != $second;
                	$split = 1;
				}
				while($s =~ /(?<!^)$pat(?!$)/g){
   					my $first = $-[1];
                    push @$split_points,[$start+$first,$start+$first];
					my $second = $+[1];
                    push @$split_points,[$start+$second,$start+$second] if $first != $second;
                	$split = 1;
				}
				if($s =~ /(?<!^)$pat$/g){
					my $first = $-[1];
                    push @$split_points,[$start+$first,$start+$first];
					my $second = $+[1];
                    push @$split_points,[$start+$second,$start+$second] if $first != $second;
                	$split = 1;
				}

				_split_tokens($offsets,$i,[ sort { $a->[0] <=> $b->[0] } @$split_points ]) if @$split_points;
			}
		}
	}
	return _nonbp($text,$offsets);
#return $offsets;
}

sub _split_tokens {
    my ($offsets,$i,$split_points) = @_;
    my ($end,$start) = @{shift @$split_points};
    my $last = $offsets->[$i][1];
    $offsets->[$i][1] = $end;
    while(my $p = shift @$split_points){
        push @$offsets, [$start,$p->[0]] unless $start == $p->[0];
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


sub _load_prefixes {
	my ($prefixref) = @_;
	$INC{'Lingua/EN/Tokenizer/Offsets.pm'} =~ m{\.pm$};
	my $prefixfile = "$`/nonbreaking_prefix.en";
	
	open my $prefix, '<', $prefixfile or die "Could not open file '$prefixfile'!";
	while (<$prefix>) {
		next if /^#/ or /^\s*$/;
		my $item = $_;
		chomp($item);
		if ($item =~ /(.*)[\s]+(\#NUMERIC_ONLY\#)/) { $prefixref->{$1} = 2; } 
		else { $prefixref->{$item} = 1; }
	}
	close($prefix);
}



=method _nonbp

=cut

sub _nonbp {
    my ($text,$offsets) = @_;
	my $nonbpref = {};
	_load_prefixes($nonbpref);
    my $size = @$offsets;
    my $new_offsets = [ sort { $a->[0] <=> $b->[0] } @$offsets ];
	my $extra = [];
    for(my $i=0; $i<$size-1; $i++){
        my $start  = $new_offsets->[$i][0];
        my $end    = $new_offsets->[$i][1];
        my $length = $end-$start;
        my $s = substr($text,$start,$length);
        my $j=$i+1;
		my $t = substr($text,$new_offsets->[$j][0], $new_offsets->[$j][1]-$new_offsets->[$j][0]);

		if($s =~ /^(.*[^\s\.])\.\s*?$/){
			my $pre = $1;
			unless (
					($nonbpref->{$pre} and $nonbpref->{$pre}==1)
				or	($t =~ /^[\p{IsLower}]/)
				or	(
						$nonbpref->{$pre}
					and	$nonbpref->{$pre}==2
					and $t =~ /^\d+/)
			){
				$s =~ /^(.*[^\s\.])\.\s*?$/;
				push @$extra, [$start+$+[1],$end];
				$new_offsets->[$i][1] = $start+$+[1];
			}
		}
	}
	return [ sort { $a->[0] <=> $b->[0] } (@$new_offsets,@$extra) ];
}
			


1;
