use strict;

package Net::Delicious::Export::Post::XBEL;
use base qw (Net::Delicious::Export);

# $Id: XBEL.pm,v 1.4 2004/02/09 20:03:09 asc Exp $

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
$VERSION = '1.0';

use MD5;

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

	    if ($self->{'__folder'}) {
		$self->end_element({Name => "folder"});
		$self->{'__folder'} = 0;
	    }

	    #

	    $self->start_element({Name => "folder",
				  Attributes => {"{}id" => {Name         => "id",
							    LocalName    => "id",
							    Prefix       => "",
							    NamespaceURI => "",
							    Value        => $this_date},}});

	    $self->start_element({Name => "title"});
	    $self->characters({Data=>$this_date});
	    $self->end_element({Name => "title"});

	    #

	    $self->{'__folder'} = 1;
	    $last_date = $this_date
	}

	#

	$self->start_element({Name => "bookmark",
			      Attributes => { "{}id" => {Name         => "id",
							 LocalName    => "id",
							 Prefix       => "",
							 NamespaceURI => "",
							 Value        => MD5->hexhash($bm->href())},
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
    }

    #

    if ($self->{'__folder'}) {
	$self->end_element({Name => "folder"});
	$self->{'__folder'} = 0;
    }

    #

    $self->end_document();
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

    $self->end_element({Name => "xbel"});
    $self->SUPER::end_document();

    return 1;
}

=head1 VERSION

1.0

=head1 DATE

$Date: 2004/02/09 20:03:09 $

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
