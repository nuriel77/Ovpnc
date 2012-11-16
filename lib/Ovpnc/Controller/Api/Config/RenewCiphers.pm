package Ovpnc::Controller::Api::Config::RenewCiphers;

use File::Copy;
use vars qw/$list $lines/;

sub action 
{
	my ($self, $schema_file, $openvpn) = @_;

	# Get cipher list from openvpn
	my $data = &getCiphers($openvpn);

	# If returns an array process...
	# Else, return the error string
	if (ref $data eq 'ARRAY'){
    	$list = &makeXsdList(\@data);
	}
	else {
		return $data;
	}

	# Read current XSD File
	$lines = &readXsdFile($schema_file);
	
	# Remove old cipher list
	$lines = &removeOldCiphers($lines);
	$lines .= $list . "</xsd:schema>";

	# Backup older file
	copy($schema_file, $schema_file . '.old') or return "Copy of backup failed: $!";

	# Create new file
	open (my $XSD, ">", $schema_file) or return "Cannot open $schema_file for writing: $!";
	print $XSD $lines;
	close $XSD;

	return "ok";
}

sub removeOldCiphers{
    my $lines = shift;
    $lines =~ s/(<!\-\- Type: Cipher List \-\->.*[\n]?<\/xsd:schema>)//sg;
    return $lines;
}

sub getCiphers{
    my $cmd = (shift) . ' --show-ciphers | egrep \'^[A-Z]{2}\' | awk {\'print $1\'}';
    my @data = `$cmd`;
	return "Error" if ( $? >> 8 != 0 );
    map { chomp } @data;
    return \@data;
}

sub readXsdFile{
	my $schema_file = shift;
    open (my $XSD, "<", $schema_file) or return "Cannot open $schema_file: $!";
    $lines .= $_ while (<$XSD>);
    close $XSD;
    return $lines;
}

sub makeXsdList{
    my @data = @{(shift)};

    my $list = <<_OO_;
<!-- Type: Cipher List -->
<xsd:simpleType name="CipherType">
 <xsd:restriction base="xsd:string">
_OO_

for (@data){
        $list .= '  <xsd:enumeration value="' . $_ . '" />' . "\n";
    }

    $list .= <<_OO_;
 </xsd:restriction>
</xsd:simpleType>
_OO_

    return $list;
}

1;
