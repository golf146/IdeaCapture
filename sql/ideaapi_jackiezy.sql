-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- 主机： localhost
-- 生成日期： 2025-09-09 11:49:37
-- 服务器版本： 5.7.40-log
-- PHP 版本： 8.0.26

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- 数据库： `ideaapi_jackiezy`
--

-- --------------------------------------------------------

--
-- 表的结构 `projects`
--

CREATE TABLE `projects` (
  `id` char(36) NOT NULL,
  `user_id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `summary` varchar(500) DEFAULT NULL,
  `tags` json DEFAULT NULL,
  `goals` text,
  `audience` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_device_udid` varchar(64) DEFAULT NULL,
  `updated_device_udid` varchar(64) DEFAULT NULL,
  `current_opinion_id` char(36) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- --------------------------------------------------------

--
-- 表的结构 `project_opinions`
--

CREATE TABLE `project_opinions` (
  `id` char(36) NOT NULL,
  `project_id` char(36) NOT NULL,
  `version` int(11) NOT NULL,
  `opinion` text NOT NULL,
  `prev_opinion_id` char(36) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `device_udid` varchar(64) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- 触发器 `project_opinions`
--
DELIMITER $$
CREATE TRIGGER `trg_set_current_opinion` AFTER INSERT ON `project_opinions` FOR EACH ROW BEGIN
  UPDATE projects
     SET current_opinion_id = NEW.id,
         updated_device_udid = NEW.device_udid
   WHERE id = NEW.project_id;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- 表的结构 `snapshots`
--

CREATE TABLE `snapshots` (
  `user_id` int(10) UNSIGNED NOT NULL,
  `json` longtext NOT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- --------------------------------------------------------

--
-- 表的结构 `users`
--

CREATE TABLE `users` (
  `id` int(10) UNSIGNED NOT NULL,
  `email` varchar(255) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `DEV_MODE` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- 转储表的索引
--

--
-- 表的索引 `projects`
--
ALTER TABLE `projects`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_user_name` (`user_id`,`name`),
  ADD KEY `idx_user` (`user_id`);

--
-- 表的索引 `project_opinions`
--
ALTER TABLE `project_opinions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_project_version` (`project_id`,`version`),
  ADD KEY `idx_project` (`project_id`);

--
-- 表的索引 `snapshots`
--
ALTER TABLE `snapshots`
  ADD PRIMARY KEY (`user_id`);

--
-- 表的索引 `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`);

--
-- 在导出的表使用AUTO_INCREMENT
--

--
-- 使用表AUTO_INCREMENT `users`
--
ALTER TABLE `users`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- 限制导出的表
--

--
-- 限制表 `project_opinions`
--
ALTER TABLE `project_opinions`
  ADD CONSTRAINT `fk_opinion_project` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- 限制表 `snapshots`
--
ALTER TABLE `snapshots`
  ADD CONSTRAINT `fk_snapshots_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
