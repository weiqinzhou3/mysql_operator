-- 清理历史动态数据
USE fota_base_data;
TRUNCATE TABLE fota_base_data.tb_as_product;
TRUNCATE TABLE fota_base_data.tb_as_product_logistics_info;
TRUNCATE TABLE fota_base_data.tb_as_product_remote_config;
TRUNCATE TABLE fota_base_data.tb_as_product_white_part;
TRUNCATE TABLE fota_base_data.tb_bp_sync_as_product_brand;
TRUNCATE TABLE fota_base_data.tb_bp_sync_ecu_module;
TRUNCATE TABLE fota_base_data.tb_bp_sync_ffl;
TRUNCATE TABLE fota_base_data.tb_bp_sync_model;
TRUNCATE TABLE fota_base_data.tb_bp_sync_model_ecu;
TRUNCATE TABLE fota_base_data.tb_bp_sync_vehicle;
TRUNCATE TABLE fota_base_data.tb_condition_group;
TRUNCATE TABLE fota_base_data.tb_ecu_module;
TRUNCATE TABLE fota_base_data.tb_ecu_part;
TRUNCATE TABLE fota_base_data.tb_family_code;
TRUNCATE TABLE fota_base_data.tb_instance;
TRUNCATE TABLE fota_base_data.tb_instance_strategy;
TRUNCATE TABLE fota_base_data.tb_instance_upgrade_group;
TRUNCATE TABLE fota_base_data.tb_model_all_ecu_ref;
TRUNCATE TABLE fota_base_data.tb_model_fc_ref;
TRUNCATE TABLE fota_base_data.tb_model_task_ecu_ref;
TRUNCATE TABLE fota_base_data.tb_vehicle;
TRUNCATE TABLE fota_base_data.tb_vehicle_group;
TRUNCATE TABLE fota_base_data.tb_vehicle_group_ref;
TRUNCATE TABLE fota_base_data.tb_vehicle_logistics_history;
TRUNCATE TABLE fota_base_data.tb_vehicle_logistics_original;
TRUNCATE TABLE fota_base_data.tb_vehicle_logistics_valid;
TRUNCATE TABLE fota_base_data.tb_vehicle_model;
TRUNCATE TABLE fota_base_data.tb_vehicle_module_info;
TRUNCATE TABLE fota_base_data.tb_vehicle_script;
TRUNCATE TABLE fota_base_data.tb_vehicle_script_log;
TRUNCATE TABLE fota_base_data.tb_vehicle_upgrade_log;
TRUNCATE TABLE fota_base_data.tb_vehicle_version_status;

-- 添加静态车辆组数据
INSERT INTO `fota_base_data.tb_vehicle_group`(`id`, `group_name`, `group_description`, `create_user`)
VALUES ('1', '测试车辆', '测试车辆组', 'admin');
INSERT INTO `fota_base_data.tb_vehicle_group`(`id`, `group_name`, `group_description`, `create_user`)
VALUES ('2', '黑名单车辆', '黑名单车辆组', 'admin');