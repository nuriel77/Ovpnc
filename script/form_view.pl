#!/usr/bin/perl
use strict;
use warnings;
use HTML::FormFu;
use YAML::XS qw( Load );
    
my $form = HTML::FormFu->new;
my $yaml = do { local $/; <DATA> };
my $data = Load($yaml);
    
$form->populate($data);
    
print $form;
    
__DATA__
---
auto_fieldset: 1
elements:
      # Username
      - type: Text
        name: username
        label: Username
        constraints:
          - Required
      # Password
      - type: Text
        name: password
        label: Password
        constraints:
          - Required
      # Email
      - type: Text
        name: email
        label: Email
        constraints:
          - Required
      # Phone
      - type: Text
        name: phone
        label: Phone
        constraints:
          - Required
      # Address
      - type: Text
        name: address
        label: Address
        constraints:
          - Required
      # Submit
      - type: Submit
        name: submit
        value: Submit
