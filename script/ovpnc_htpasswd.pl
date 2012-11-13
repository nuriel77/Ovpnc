#!/usr/bin/env perl
use warnings;
use strict;
use vars qw($htpwd %opt);
use Getopt::Std;
use Apache::Htpasswd;

use constant HTPASSWD => 'config/.htpasswd';

&init();
print STDERR "Verbose mode ON.\n" if $opt{v};
	
# Object
#	my $htpwd = Apache::Htpasswd->new( { passwdFile => ( $opt{f} ? $opt{f} : HTPASSWD ), ReadOnly => 1 });
my $htpwd = Apache::Htpasswd->new({
	passwdFile => ( $opt{f} ? $opt{f} : HTPASSWD ),
}) or die "Could not instantiate Apache::Htpasswd!\n";
die unless $htpwd;

if ( $opt{u} && $opt{p} ){
	my $check = &add_entry($opt{u}, $opt{p});
	die "Did not add entry: $check\n" if $check;
}

exit(0);



# Add an entry
# ============
sub add_entry 
{
	$htpwd->htpasswd( @_ );
	return $htpwd->error if $htpwd->error;
}

# Command line options processing
# ===============================
sub init()
{
	# Options
    my $opt_string = 'hvcdp:u:n:f:';
    getopts( "$opt_string", \%opt );

	# Usage
    usage() if ( $opt{h} );
}

# Program help
# ============
sub usage()
{
	print STDERR << "EOF";
= Ovpnc htpasswd script =
usage: $0 [-hvd] [-f file] [-u username] [-p password] [-n oldpasswd] 
 -h        : this (help) message
 -c 	   : always create a new file (Warning: overwrites if file already exists!)
 -p passwd : password
 -n passwd : old password entry for user when updating the password
 -u user   : username when creating or updating entries
 -d 	   : delete a password entry for user
 -f file   : htpasswd file
 -v        : verbose output


examples:
 - Create a new htpasswd file: 		$0 -v -c -f file -u testuser -p 'somepass'
 - Add an entry to a htpasswd file: 	$0 -f file -u testuser -p 'somepass'
 - Delete an entry from a file: 	$0 -d testuser -f file
 - Replace passwd entry in file:	$0 -f file -u testuser -n 'newpasswd' -p 'oldpasswd'

EOF
	exit;
}

Change a password
$htpwd->htpasswd("ovpnc", "Test1234x", "test1234");

# Change a password without checking against old password
#$htpwd->htpasswd("zog", "new-password", {'overwrite' => 1});

# Check that a password is correct
#$htpwd->htCheckPassword("nuriel", $ARGV[0]);

# Fetch an encrypted password
#$htpwd->fetchPass("nuriel");

# Delete entry
#$htpwd->htDelete("foo");

# If something fails, check error
#$htpwd->error;

# Write in the extra info field
#$htpwd->writeInfo("login", "info");

# Get extra info field for a user
#$htpwd->fetchInfo("login");
