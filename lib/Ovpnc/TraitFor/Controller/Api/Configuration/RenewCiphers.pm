package Ovpnc::TraitFor::Controller::Api::Configuration::RenewCiphers;
use warnings;
use strict;
use Module::Locate qw(locate);
scalar locate('File::Copy') ? 0 : do { use File::Copy; };
use Moose::Role;
use vars qw/$list $lines/;

has 'schema_file' => (
	is => 'ro',
	isa => 'Str',
	required => 1
);

has 'openvpn' => (
	is => 'ro',
	isa => 'Str',
	required => 1
);

sub update_cipher_list {
    my $self = shift;

    # Get cipher list from openvpn
    my $data = $self->getCiphers;

    return { error => "Could no produce cipher list from openvpn!" }
      unless ($data);

    # If returns an array process...
    # Else, return the error string
    if ( ref $data eq 'ARRAY' ) {
        $list = $self->makeXsdList($data);
    }
    else {
        return { error => $data };
    }

    return { error => "XSD list was not produced from openvpn list" }
      unless $list;

    # Read current XSD File
    $lines = $self->readXsdFile($self->schema_file);
    if ( !$lines ) {
        return { error => "No return from readXsdFile!" };
    }
    elsif ( ref $lines and $lines->{error} ) {
        return { error => "Error reading " . $self->schema_file . ": "
              . ( $lines->{error} ? $lines->{error} : '' ) };
    }

    # Remove old cipher list
    $lines = $self->removeOldCiphers($lines);
    $lines .= $list . "</xsd:schema>";

    # Backup older file
    copy( $self->schema_file, $self->schema_file . '.old' )
      or return { error => "Copy of backup failed: $!" };

    # Create new file
    open( my $XSD, ">", $self->schema_file )
      or return { error => "Cannot open ". $self->schema_file . " for writing: $!" };
    print $XSD $lines;
    close $XSD;

    return {status => 'Cipher list generated ok, backup created: '
          . $self->schema_file
          . '.old' };
}

sub removeOldCiphers {
    my ( $self, $lines ) = @_;
    $lines =~ s/(<!\-\- Type: Cipher List \-\->.*[\n]?<\/xsd:schema>)//sg;
    return $lines;
}

sub getCiphers {
    my $self = shift;
    my $cmd =
    	$self->openvpn . ' --show-ciphers | egrep \'^[A-Z]{2}\' | awk {\'print $1\'}';
    my @data = `$cmd`;
    return "Error" if ( $? >> 8 != 0 );
    map { chomp } @data;
    return \@data;
}

sub readXsdFile {
	my $self = shift;
    open( my $XSD, "<", $self->schema_file )
		or return "Cannot open " . $self->schema_file . ": " . $!;
    $lines .= $_ while (<$XSD>);
    close $XSD;
    return $lines;
}

sub makeXsdList {
    my $self = shift;
    my @data = @{ (shift) };

	my $list = <<_OO_;
<!-- Type: Cipher List -->
<xsd:simpleType name="CipherType">
 <xsd:restriction base="xsd:string">
_OO_

    for (@data) {
        $list .= "  <xsd:enumeration value=\"" . $_ . "\" />\n";
    }

    $list .= <<_OO_;
 </xsd:restriction>
</xsd:simpleType>
_OO_

    return $list;
}

1;
