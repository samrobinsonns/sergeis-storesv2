-- ===========================================
-- DROP ALL TABLES - SERGEI'S STORES V2
-- ===========================================
-- Simple script to drop all tables created by schema.sql
-- Run this before schema.sql for fresh installs
-- ===========================================

-- Drop tables in reverse order (constraints will be dropped automatically)
DROP TABLE IF EXISTS `sergeis_store_employee_stats`;
DROP TABLE IF EXISTS `sergeis_store_upgrades`;
DROP TABLE IF EXISTS `sergeis_store_vehicles`;
DROP TABLE IF EXISTS `sergeis_store_transactions`;
DROP TABLE IF EXISTS `sergeis_store_items`;
DROP TABLE IF EXISTS `sergeis_store_employees`;
DROP TABLE IF EXISTS `sergeis_stores`;

SELECT 'All Sergei\'s Stores V2 tables dropped successfully!' as status;
