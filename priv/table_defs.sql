DROP DATABASE IF EXISTS `test_db`;
CREATE DATABASE `test_db`;
USE test_db;

DROP TABLE IF EXISTS `test_tab`;
CREATE TABLE `test_tab` (
	`id` bigint unsigned NOT NULL AUTO_INCREMENT,
	`comment` varchar(255),
	`ballance` bigint NOT NULL,
	`stamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (id),
	KEY `comment` (`comment`),
	KEY `ballance` (`ballance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
