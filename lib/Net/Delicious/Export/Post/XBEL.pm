use strict;

package Net::Delicious::Export::Post::XBEL;
use base qw (Net::Delicious::Export);

# $Id: XBEL.pm,v 1.6 2004/02/10 18:59:18 asc Exp $

=head1 NAME

Net::Delicious::Export::Post::XBEL - export your del.icio.us posts as XBEL

=head1 SYNOPSIS

 use Net::Delicious;
 use Net::Delicious::Export::Post::XBEL;

 use IO::AtomicFile;
 use XML::SAX::Writer;

 my $fh     = IO::AtomicFile->open("/my/posts.xbel","w");
 my $writer = XML::SAX::Writer->new(Output=>$fh);

 my $del = Net::Delicious->new({...});
 my $exp = Net::Delicious::Export::Post::XBEL->new(Handler=>$writer);

 my $it = $del->posts();
 $exp->by_date($it);

=head1 DESCRIPTION
 
Export your del.icio.us posts as XBEL.

This package subclasses I<Net::Delicious::Export>.

=cut

use vars qw ($VERSION);
$VERSION = '1.1';

use MD5;
use Memoize;

&memoize("mk_bookmarkid");

=head1 PACKAGE METHODS

=cut

=head2 __PACKAGE__->new(\%args)

Valid arguments are :

=over 4

=item * 

B<Handler>

A valid handler for I<Net::Delicious::Export>, which is really just
a thin wrapper around I<XML::SAX::Base>

=back

Returns a I<Net::Delicious::Export::Post::XBEL> object. Woot!

=cut

# Inherited from Net::Delicious::Export

=head1 OBJECT METHODS

=cut

=head2 $obj->by_date(\%args)

Valid args are

=over 4

=item *

B<posts> I<required>

A I<Net::Delicios::Iterator> object containing the posts you
want to export.

=item *

B<title>

String.

=back

Returns whatever the handler passed to the object
contructor sends back.

=cut

sub by_date {
    my $self  = shift;
    my $args  = shift;

    $self->start_document($args->{title});

    #

    my $last_date = undef;

    while (my $bm = $args->{posts}->next()) {

	$bm->time() =~ /(\d{4}-\d{2}-\d{2})T/;
	my $this_date = $1;

	#

	if ($this_date ne $last_date) {
	    $self->start_folder($this_date);
	    $last_date = $this_date
	}

	#

	$self->bookmark($bm);
    }

    #

    $self->end_document();
    return 1;
}

=head2 $obj->by_tag(\%args)

Valid args are

=over 4

=item *

B<posts> I<required>

A I<Net::Delicios::Iterator> object containing the posts you
want to export.

=item *

B<title>

String.

=item *

B<sort>

Code reference, used as an argument for passing to 
Perl's I<sort> function.

The default behaviour is to sort tags alphabetically.

=back

Bookmarks with multiple tags will be added once; subsequent
instances of the same bookmark will use XBEL's <alias> element
to refer back to the first URL.

Multiple tags for a bookmark will be ordered alphabetically or
using the same I<sort> argument passed to the method.

Returns whatever the handler passed to the object
contructor sends back.

=cut

sub by_tag {
    my $self  = shift;
    my $args  = shift;

    my $sort = sub {$a cmp $b};

    if (ref($args->{sort}) eq "CODE") {
	$sort = $args->{sort};
    }

    #

    $self->start_document($args->{title});

    #

    my %ordered = ();

    while (my $bm = $args->{posts}->next()) {

	# Create a list of tags

	my $tag = $bm->tag() || "unsorted";
	$tag =~ s/\s+//;

	my @tags = sort $sort split(/[\s,]/,$tag);

	# Pull the first tag off the list
	# and use it as the actual bookmark

	$ordered{ shift @tags }->{ $bm->time() } = $bm;

	# Everything else is just an alias

	map { 
	    $ordered{ $_ }->{ $bm->time() } = &mk_bookmarkid($bm);
	} @tags;
    }

    #

    my $last_tag = undef;

    foreach my $tag (sort $sort keys %ordered) {

	if ($last_tag ne $tag) {

	    $self->start_folder($tag);
	    $last_tag = $tag;
	}

	foreach my $dt (sort {$a cmp $b} keys %{$ordered{$tag}}) {

	    my $bm = $ordered{ $tag }->{ $dt };

	    if (ref($bm)) {
		$self->bookmark($bm);
	    }

	    else {
		$self->alias($bm);
	    }
	}
    }

    #

    $self->end_document();
    return 1;
}

sub start_folder {
    my $self  = shift;
    my $title = shift;

    $self->end_folder();

    #

    $self->start_element({Name => "folder",
			  Attributes => {"{}id" => {Name         => "id",
						    LocalName    => "id",
						    Prefix       => "",
						    NamespaceURI => "",
						    Value        => $title},}});

    $self->start_element({Name => "title"});
    $self->characters({Data=>$title});
    $self->end_element({Name => "title"});
    
    #
    
    $self->{'__folder'} = 1;
    
    return 1;
}

sub end_folder {
    my $self = shift;

    if ($self->{'__folder'}) {
	$self->end_element({Name => "folder"});
	$self->{'__folder'} = 0;
    }

    return 1;
}

sub bookmark {
    my $self = shift;
    my $bm   = shift;

    $self->start_element({Name => "bookmark",
			  Attributes => { "{}id" => {Name         => "id",
						     LocalName    => "id",
						     Prefix       => "",
						     NamespaceURI => "",
						     Value        => &mk_bookmarkid($bm)},
					  "{}url" => {Name         => "url",
						      LocalName    => "url",
						      Prefix       => "",
						      NamespaceURI => "",
						      Value        => $bm->href() } }});
    
    if (my $txt = $bm->description()) {
	$self->start_element({Name => "title"});
	$self->characters({Data=> $txt});
	$self->end_element({Name => "title"});
    }
    
    if (my $txt = $bm->extended()) {
	$self->start_element({Name => "desc"});
	$self->characters({Data=> $txt});
	$self->end_element({Name => "desc"});
    }
    
    $self->end_element({Name => "bookmark"});
    return 1;
}

sub alias {
    my $self = shift;
    my $ref  = shift;

    $self->start_element({Name => "alias",
			  Attributes => { "{}ref" => {Name         => "ref",
						      LocalName    => "ref",
						      Prefix       => "",
						      NamespaceURI => "",
						      Value        => $ref}}});

    $self->end_element({Name => "alias"});
    return 1;
}


sub start_document {
    my $self  = shift;
    my $title = shift;

    $title ||= "del.icio.us posts";

    $self->SUPER::start_document();
    $self->SUPER::xml_decl({Version=>"1.0",Encoding=>"UTF-8"});

    $self->start_element({Name => "xbel"});
    $self->start_element({Name => "title"});
    $self->characters({Data=>$title});
    $self->end_element({Name => "title"});

    $self->start_element({Name => "description"});
    $self->characters({Data=>"Created by ".__PACKAGE__.", $VERSION"});
    $self->end_element({Name => "description"});

    return 1;
}

sub end_document {
    my $self = shift;

    $self->end_folder();

    #

    $self->end_element({Name => "xbel"});
    $self->SUPER::end_document();

    return 1;
}

# Memoized

sub mk_bookmarkid {
    my $bm = shift;
    return MD5->hexhash($bm->href());
}

=head1 VERSION

1.1

=head1 DATE

$Date: 2004/02/10 18:59:18 $

=head1 AUTHOR

Aaron Straup Cope <ascope@cpan.org>

=head1 SEE AlSO

L<Net::Delicious>

L<Net::Delicious::Export>

http://pyxml.sourceforge.net/topics/xbel/

=head1 LICENSE

Copyright (c) 2004 Aaron Straup Cope. All Rights Reserved.

This is free software, you may use it and distribute it under the
same terms as Perl itself.

=cut

return 1;
