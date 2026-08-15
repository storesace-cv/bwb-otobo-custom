/*M!999999\- enable the sandbox mode */

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
DROP TABLE IF EXISTS `bwb_agent_hierarchy`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `bwb_agent_hierarchy` (
  `user_id` int(11) NOT NULL,
  `responsible_user_id` int(11) NOT NULL,
  `create_time` datetime NOT NULL,
  `create_by` int(11) NOT NULL,
  `change_time` datetime NOT NULL,
  `change_by` int(11) NOT NULL,
  PRIMARY KEY (`user_id`),
  KEY `bwb_agent_hierarchy_responsible` (`responsible_user_id`),
  KEY `fk_bwb_agent_hierarchy_create_by` (`create_by`),
  KEY `fk_bwb_agent_hierarchy_change_by` (`change_by`),
  CONSTRAINT `fk_bwb_agent_hierarchy_change_by` FOREIGN KEY (`change_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_bwb_agent_hierarchy_create_by` FOREIGN KEY (`create_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_bwb_agent_hierarchy_responsible` FOREIGN KEY (`responsible_user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_bwb_agent_hierarchy_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bwb_collaborator_customer`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `bwb_collaborator_customer` (
  `user_id` int(11) NOT NULL,
  `customer_id` varchar(150) NOT NULL,
  `create_time` datetime NOT NULL,
  `create_by` int(11) NOT NULL,
  PRIMARY KEY (`user_id`,`customer_id`),
  KEY `fk_bwb_cc_customer` (`customer_id`),
  KEY `fk_bwb_cc_create_by` (`create_by`),
  CONSTRAINT `fk_bwb_cc_create_by` FOREIGN KEY (`create_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_bwb_cc_customer` FOREIGN KEY (`customer_id`) REFERENCES `customer_company` (`customer_id`),
  CONSTRAINT `fk_bwb_cc_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bwb_collaborator_store`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `bwb_collaborator_store` (
  `user_id` int(11) NOT NULL,
  `store_id` int(11) NOT NULL,
  `create_time` datetime NOT NULL,
  `create_by` int(11) NOT NULL,
  PRIMARY KEY (`user_id`,`store_id`),
  KEY `fk_bwb_cs_store` (`store_id`),
  KEY `fk_bwb_cs_create_by` (`create_by`),
  CONSTRAINT `fk_bwb_cs_create_by` FOREIGN KEY (`create_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_bwb_cs_store` FOREIGN KEY (`store_id`) REFERENCES `bwb_store` (`id`),
  CONSTRAINT `fk_bwb_cs_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bwb_customer_owner`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `bwb_customer_owner` (
  `customer_id` varchar(150) NOT NULL,
  `owner_user_id` int(11) NOT NULL,
  `create_time` datetime NOT NULL,
  `create_by` int(11) NOT NULL,
  `change_time` datetime NOT NULL,
  `change_by` int(11) NOT NULL,
  PRIMARY KEY (`customer_id`),
  KEY `bwb_customer_owner_user` (`owner_user_id`),
  KEY `fk_bwb_customer_owner_create_by` (`create_by`),
  KEY `fk_bwb_customer_owner_change_by` (`change_by`),
  CONSTRAINT `fk_bwb_customer_owner_change_by` FOREIGN KEY (`change_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_bwb_customer_owner_create_by` FOREIGN KEY (`create_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_bwb_customer_owner_customer` FOREIGN KEY (`customer_id`) REFERENCES `customer_company` (`customer_id`),
  CONSTRAINT `fk_bwb_customer_owner_user` FOREIGN KEY (`owner_user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bwb_invite`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `bwb_invite` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `token_hash` char(64) NOT NULL,
  `account_type` varchar(20) NOT NULL,
  `login` varchar(191) NOT NULL,
  `email` varchar(150) NOT NULL,
  `expires_time` datetime NOT NULL,
  `used_time` datetime DEFAULT NULL,
  `create_time` datetime NOT NULL,
  `create_by` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `token_hash` (`token_hash`),
  KEY `account_login` (`account_type`,`login`)
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bwb_operation_type`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `bwb_operation_type` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(200) NOT NULL,
  `is_global` tinyint(4) NOT NULL DEFAULT 0,
  `owner_user_id` int(11) DEFAULT NULL,
  `sort_order` int(11) NOT NULL DEFAULT 999,
  `valid_id` smallint(6) NOT NULL DEFAULT 1,
  `create_time` datetime NOT NULL,
  `create_by` int(11) NOT NULL,
  `change_time` datetime NOT NULL,
  `change_by` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_scope_name` (`is_global`,`owner_user_id`,`name`),
  KEY `idx_owner` (`owner_user_id`),
  KEY `idx_valid` (`valid_id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bwb_operation_type_hidden`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `bwb_operation_type_hidden` (
  `owner_user_id` int(11) NOT NULL,
  `operation_type_id` int(11) NOT NULL,
  `create_time` datetime NOT NULL,
  `create_by` int(11) NOT NULL,
  PRIMARY KEY (`owner_user_id`,`operation_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bwb_result_type`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `bwb_result_type` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(200) NOT NULL,
  `is_global` tinyint(4) NOT NULL DEFAULT 0,
  `owner_user_id` int(11) DEFAULT NULL,
  `sort_order` int(11) NOT NULL DEFAULT 999,
  `valid_id` smallint(6) NOT NULL DEFAULT 1,
  `create_time` datetime NOT NULL,
  `create_by` int(11) NOT NULL,
  `change_time` datetime NOT NULL,
  `change_by` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_scope_name` (`is_global`,`owner_user_id`,`name`),
  KEY `idx_owner` (`owner_user_id`),
  KEY `idx_valid` (`valid_id`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bwb_result_type_hidden`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `bwb_result_type_hidden` (
  `owner_user_id` int(11) NOT NULL,
  `result_type_id` int(11) NOT NULL,
  `create_time` datetime NOT NULL,
  `create_by` int(11) NOT NULL,
  PRIMARY KEY (`owner_user_id`,`result_type_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bwb_store`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `bwb_store` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `customer_id` varchar(150) NOT NULL,
  `store_number` varchar(30) NOT NULL,
  `name` varchar(191) NOT NULL,
  `street` varchar(500) DEFAULT NULL,
  `valid_id` smallint(6) NOT NULL,
  `create_time` datetime NOT NULL,
  `create_by` int(11) NOT NULL,
  `change_time` datetime NOT NULL,
  `change_by` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `bwb_store_customer_number` (`customer_id`,`store_number`),
  KEY `bwb_store_customer_id` (`customer_id`),
  KEY `bwb_store_valid_id` (`valid_id`),
  KEY `fk_bwb_store_create_by` (`create_by`),
  KEY `fk_bwb_store_change_by` (`change_by`),
  CONSTRAINT `fk_bwb_store_change_by` FOREIGN KEY (`change_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_bwb_store_create_by` FOREIGN KEY (`create_by`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_bwb_store_customer` FOREIGN KEY (`customer_id`) REFERENCES `customer_company` (`customer_id`),
  CONSTRAINT `fk_bwb_store_valid` FOREIGN KEY (`valid_id`) REFERENCES `valid` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=107 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bwb_work_session`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `bwb_work_session` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `ticket_id` bigint(20) NOT NULL,
  `user_id` int(11) NOT NULL,
  `work_type` varchar(80) NOT NULL,
  `start_time` datetime NOT NULL,
  `end_time` datetime DEFAULT NULL,
  `duration_minutes` int(11) DEFAULT NULL,
  `result` varchar(80) DEFAULT NULL,
  `observation` text DEFAULT NULL,
  `article_id` bigint(20) DEFAULT NULL,
  `create_time` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `active_user` (`user_id`,`end_time`),
  KEY `ticket` (`ticket_id`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bwb_work_sheet`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `bwb_work_sheet` (
  `session_id` bigint(20) NOT NULL,
  `body` longtext NOT NULL,
  `form_id` varchar(100) NOT NULL,
  `paused_at` datetime DEFAULT NULL,
  `paused_seconds` int(11) NOT NULL DEFAULT 0,
  `create_time` datetime NOT NULL,
  `create_by` int(11) NOT NULL,
  `change_time` datetime NOT NULL,
  `change_by` int(11) NOT NULL,
  PRIMARY KEY (`session_id`),
  KEY `bwb_work_sheet_form_id` (`form_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
