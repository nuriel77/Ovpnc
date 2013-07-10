-- phpMyAdmin SQL Dump
-- version 3.5.4
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Jan 02, 2013 at 12:32 PM
-- Server version: 5.1.63-0+squeeze1-log
-- PHP Version: 5.3.19-1~dotdeb.0

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `ovpnc`
--

-- --------------------------------------------------------

--
-- Table structure for table `certificates`
--

CREATE TABLE IF NOT EXISTS `certificates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `user` varchar(72) NOT NULL,
  `name` varchar(72) NOT NULL,
  `created_by` varchar(72) NOT NULL,
  `key_cn` varchar(42) NOT NULL,
  `key_org` text NOT NULL,
  `key_ou` text NOT NULL,
  `key_country` varchar(2) NOT NULL,
  `key_province` varchar(128) NOT NULL,
  `key_city` varchar(128) NOT NULL,
  `key_size` smallint(8) NOT NULL,
  `key_expire` int(4) NOT NULL,
  `key_email` varchar(40) NOT NULL,
  `key_serial` char(2) NOT NULL,
  `revoked` datetime NOT NULL,
  `locked` tinyint(1) NOT NULL,
  `cert_type` varchar(12) NOT NULL,
  `cert_file` text NOT NULL,
  `key_file` text NOT NULL,
  `cert_digest` varchar(40) NOT NULL,
  `key_digest` varchar(40) NOT NULL,
  `created` date NOT NULL,
  `modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=224 ;

-- --------------------------------------------------------

--
-- Table structure for table `log`
--

CREATE TABLE IF NOT EXISTS `log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `message` text NOT NULL,
  `username` varchar(72) NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`username`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=88 ;

-- --------------------------------------------------------

--
-- Table structure for table `roles`
--

CREATE TABLE IF NOT EXISTS `roles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 AUTO_INCREMENT=4 ;

--
-- Dumping data for table `roles`
--

INSERT INTO `roles` (`id`, `name`) VALUES
(1, 'admin'),
(2, 'can_edit'),
(3, 'client');

-- --------------------------------------------------------

--
-- Table structure for table `sessions`
--

CREATE TABLE IF NOT EXISTS `sessions` (
  `id` char(72) NOT NULL,
  `session_data` text,
  `expires` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE IF NOT EXISTS `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `enabled` tinyint(1) NOT NULL,
  `username` varchar(64) NOT NULL,
  `password` varbinary(60) NOT NULL,
  `salt` varchar(128) NOT NULL,
  `password_expires` datetime NOT NULL,
  `fullname` varchar(72) NOT NULL,
  `email` varchar(72) NOT NULL,
  `phone` varchar(16) NOT NULL,
  `address` mediumtext NOT NULL,
  `revoked` tinyint(1) NOT NULL,
  `created` datetime NOT NULL,
  `modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8 COMMENT='Ovpnc Users for OpenVPN' AUTO_INCREMENT=134 ;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `enabled`, `username`, `password`, `salt`, `password_expires`, `fullname`, `email`, `phone`, `address`, `revoked`, `created`, `modified`) VALUES
(1, 1, 'ovpncadmin', '$2$14$XBz98gwkk1vI/YeUyQmma.6nZJZdu0Y94/joNXWxdi.74s/KKrpXK', '', '2019-01-01 00:00:00', 'Ovpnc Administrator', 'ovpnc@localhost', '0000', '0000', 0, '2012-11-28 05:20:00', '2012-12-31 16:45:08');

-- --------------------------------------------------------

--
-- Table structure for table `user_roles`
--

CREATE TABLE IF NOT EXISTS `user_roles` (
  `user_id` int(11) NOT NULL,
  `role_id` int(11) NOT NULL,
  PRIMARY KEY (`user_id`,`role_id`),
  KEY `role_id` (`role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `user_roles`
--

INSERT INTO `user_roles` (`user_id`, `role_id`) VALUES
(1, 1);

--
-- Constraints for dumped tables
--

--
-- Constraints for table `certificates`
--
ALTER TABLE `certificates`
  ADD CONSTRAINT `certificates_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`);

--
-- Constraints for table `user_roles`
--
ALTER TABLE `user_roles`
  ADD CONSTRAINT `user_roles_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `user_roles_ibfk_2` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
