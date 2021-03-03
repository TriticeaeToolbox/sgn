use strict;
use warnings;

package CXGN::Marker::SearchJson;

use CXGN::Marker;
use CXGN::Marker::LocMarker;
use CXGN::Marker::Tools qw(clean_marker_name);


=head1 NAME

CXGN::Marker::SearchJson - object to return lists of markers based on your criteria

=head1 SYNOPSIS

  use CXGN::Marker::SearchJson;
  my $search = CXGN::Marker::SearchJson->new();


=head1 DESCRIPTION

Running a search consists of two steps:

0. Create marker search object

1. Call search_marker_json() to execute the SQL

=cut
  
=head2 Constructor

=over 12

=item new($dbh)

  my $msearch = CXGN::Marker::SearchJson->new($dbh);

Returns a search object, ready for searching. Required before any of the other methods are called.

=back

=cut

sub new {

  my ($class, $dbh) = @_;

  die "must provide a dbh as first argument: CXGN::Marker->new($dbh)\n"
      unless $dbh && ref($dbh) && $dbh->can('selectall_arrayref');

  my $self = bless {dbh => $dbh},$class;

  return $self;

}

sub name_like {

  my ($self, $name) = @_;

  return unless $name;

  # convert * to % (but leave underscores alone)
  $name =~ s/\*/\%/g;

  # strip un-normal characters?
  $name =~ s|[^-_\w./%]||g;

  # clean the name to see what WE would call it. 
  # We'll search for both the input name and the cleaned name.
  my $clean_name = clean_marker_name($name);

  my $subquery = " s.value->>'name' = '$name'";
  push(@{$self->{query_parts}}, $subquery);

}

sub search_marker_json {
    my ($self, $marker) = @_;
    my @row;
    my $protocol_name;
    my $species_name;
    my @protocol_set;
    my %protocol_list;
    my %species_list;
    my $protocol_str;
    my @marker_set;
    my $results;

    my $query = "select cvterm_id from cvterm where name = 'vcf_map_details'";
    $self->{sth} = $self->{dbh}->prepare($query);
    $self->{sth}->execute();
    my ($protocol_map_cvterm) = $self->{sth}->fetchrow_array();

    $query = "select cvterm_id from cvterm where name = 'vcf_map_details_markers'";
    $self->{sth} = $self->{dbh}->prepare($query);
    $self->{sth}->execute();
    my ($protocol_markers_cvterm) = $self->{sth}->fetchrow_array(); 

    $query = "select nd_protocol_id from nd_protocolprop WHERE '$marker' IN (SELECT jsonb_array_elements_text(nd_protocolprop.value->'marker_names') where type_id = $protocol_map_cvterm)";
    $self->{sth} = $self->{dbh}->prepare($query);
    $self->{sth}->execute();
    while (@row = $self->{sth}->fetchrow_array()) {
	push @protocol_set, $row[0];
    }
    my $count = scalar @protocol_set;
    if ($count > 0) {
        $protocol_str = join(',', @protocol_set);

        $query = "select nd_protocol_id , s.value->>'name' as alias ,s.value->>'chrom' as lg_name ,s.value->>'pos' as position, s.value->>'ref' as ref, s.value->>'alt' as alt";
        $query .= " FROM nd_protocolprop, jsonb_each(nd_protocolprop.value) as s";
        $query .= " WHERE nd_protocol_id IN ($protocol_str) AND type_id = $protocol_map_cvterm AND s.value->>'name' = '$marker'";
        $self->{sth} = $self->{dbh}->prepare($query);
        $self->{sth}->execute();
	$results = $self->{sth}->fetchall_arrayref({});
    }
    return $results;
}

sub perform_search {

  my ($self, $start, $end) = @_;

}


# all good modules return true
1;
