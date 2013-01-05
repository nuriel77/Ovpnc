Ovpnc
=====

OpenVPN Controller Application

* Note: Under Development


Introduction
------------

This application will provide an administrator and user interface to the OpenVPN Community Edition.
 
[OpenVPN](http://openvpn.net/index.php/download/community-downloads.html) -- Download page.

Update: To give a better impression a screenshot has been added:
http://x-vps.com/ovpnc_1.jpg


Motivation
----------

I have been using OpenVPN extensively, both for private and commercial use.
While I find it rather comfortable to administer applications from the commandline,
I always wanted to create an application which could control most features of OpenVPN
and provide them under one easy-to-use interface. It would become rather difficult for
an administrator to control a large number of users, certificates and authorizations.
I am hoping to combine the feature-rich OpenVPN and a graphical (web) interface, both for
server administrator and the users.




### Module 1

- Will provide some basic functionality such as:

* Basic OpenVPN control for administrators
* Live interaction and control
* No database required
* Users/Clients certifications and control

### Module 2

- Will add some extended features:

* Database (DBIx::Class)
* User/Clients management and login
* ACL roles
* Clustering
* Traffic shaping


Features Overview
-----------------

### Application
* Standalone Application (Using Catalyst MVC)
* Optionally run behind a proxy
* Various deployment methods
* HTTPS support

### Users
* Certificate management
* Connection parameters
* Web login interface

### Admin
* User management
* Configuration management
* Live controls
* Live overview
* Traffic shaping
* Clustering OpenVPN


Note
====

I am carrying the idea of this project for quite a while now. It is a matter of finding the time to do it.

The application is currently under its initial development stages. You are welcome to view the code, download it, test and review it.
Certain functionalities are still being explored, for example what is the best way to implement new features while taking into account performace, sercurity, scalability and simplicity.

Anybody wanting to participate or help on this project is most welcome to do so. I do not do this for profit but for the love of programming.

I will be glad to hear any comments and / or ideas.

Nuriel Shem-Tov
Perl Developer
