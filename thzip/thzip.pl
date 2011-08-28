#!usr/local/bin/perl
# -*- Mode: Perl; Encoding: CP932 -*-

use strict;
use warnings;
use YAML::XS;
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use POSIX 'strftime';
use Encode;

my $zip = Archive::Zip->new();
my $yaml = "thzip.yaml";

my $conf = YAML::XS::LoadFile($yaml) or die "$yaml:$!";

foreach my $key (sort (keys %{$conf->{th}})){
  my $dirname = encode('CP932', $conf->{th}->{$key}) || "";
  if (-d $dirname){
    $zip->addTree($dirname . "/replay", "$key/replay");
    opendir my $dh, $dirname or next;
    my @scoredat = grep /^score.*?\.dat$/, readdir($dh);
    closedir $dh;
    if (-f $dirname . "/" . $scoredat[0]) {
      print "$key ... Ok\n";
      $zip->addFile($dirname . "/" . $scoredat[0], $key . "/" . $scoredat[0])->desiredCompressionLevel(COMPRESSION_LEVEL_DEFAULT);
    } else {
      print encode('CP932', "$key ... Not Found score*.dat\n");
    }
  } else {
      print encode('CP932', "$key ... Error\n");
  }
}

foreach my $key (sort (keys %{$conf->{th_append}})){
  my $dirname = encode('CP932', $conf->{th_append}->{$key}) || "";
  if (-d $dirname){
    print "$key ... Ok\n";
    $zip->addTree($dirname , "$key");
  } else {
    print encode('CP932', "$key ... Error\n");
  }
}

my $zip_filename = strftime("th_%Y-%m-%dT%H%M%S.zip", localtime);
if ($zip->writeToFileNamed($zip_filename) == AZ_OK) {
  print "Saved : $zip_filename\n";
} else {
  print "Failed : $zip_filename\n";
}

1;

__END__

=head1 NAME

thzip.pl - for Toho STG gamers, create a zip file and place Toho score*.dat and Toho *.rpy into it.

=head1 SYNOPSIS

  $ thzip.pl

=head1 DESCRIPTION

This program is to create a zip file and place Toho score files (score*.dat)
and replay files (*.rpy) into it.
All you have to do is write in config YAML file C<thzip.yaml> and
execute this program.

=head1 CONFIG

C<thzip.yaml> have to be according to YAML specification.
It have to contain the two lines, one is a line starting with C<th:>,
another is a line starting with C<th_append:>.
you can do rewrite C<thzip.yaml>.

=over 4

=item th:

=item th_append:

=back

=head1 EXAMPLES

If you have Toho Shinreibyo E<lt>Ten DesiresE<gt>,
you write the following configure in C<thzip.yaml>.

  th:
    th13:   C:\Users\I<username>\AppData\Roaming\ShanghaiAlice\th13

If you get a special replay file,
you write the following configure in C<thzip.yaml>.

  th_append:
    th_special:    C:\Users\I<username>\上海アリス幻樂団\MySpecial

This program allows you to append new configure in C<thzip.yaml>.

=head1 AUTHOR

Jagua

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
