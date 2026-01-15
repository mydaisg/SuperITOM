-- ITOM数据库创建脚本
-- 创建日期: 2026-01-14
-- 数据库: SQLite3
-- 位置: D:/GitHub/SuperITOM/db/GH_ITOM.db

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    email TEXT,
    role TEXT DEFAULT 'user',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    is_active INTEGER DEFAULT 1
);

-- 主机表
CREATE TABLE IF NOT EXISTS hosts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostname TEXT UNIQUE NOT NULL,
    ip_address TEXT NOT NULL,
    os_type TEXT NOT NULL,
    location TEXT,
    department TEXT,
    status TEXT DEFAULT 'Unknown',
    domain TEXT,
    last_seen TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 主机状态表
CREATE TABLE IF NOT EXISTS host_status (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    host_id INTEGER NOT NULL,
    ps7_installed INTEGER DEFAULT 0,
    winrm_enabled INTEGER DEFAULT 0,
    domain_joined INTEGER DEFAULT 0,
    local_admin_configured INTEGER DEFAULT 0,
    tools_deployed INTEGER DEFAULT 0,
    health_check_passed INTEGER DEFAULT 0,
    last_check TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (host_id) REFERENCES hosts(id)
);

-- 操作记录表
CREATE TABLE IF NOT EXISTS operations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    host_id INTEGER NOT NULL,
    operation_type TEXT NOT NULL,
    script_name TEXT,
    status TEXT DEFAULT 'Pending',
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    duration_seconds INTEGER,
    error_message TEXT,
    output TEXT,
    created_by INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (host_id) REFERENCES hosts(id),
    FOREIGN KEY (created_by) REFERENCES users(id)
);

-- 操作日志表
CREATE TABLE IF NOT EXISTS operation_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id INTEGER NOT NULL,
    log_level TEXT NOT NULL,
    log_message TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (operation_id) REFERENCES operations(id)
);

-- 系统信息表
CREATE TABLE IF NOT EXISTS system_info (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    host_id INTEGER NOT NULL,
    os_name TEXT,
    os_version TEXT,
    os_build TEXT,
    computer_name TEXT,
    manufacturer TEXT,
    model TEXT,
    processor TEXT,
    total_memory INTEGER,
    available_memory INTEGER,
    disk_info TEXT,
    bios_version TEXT,
    serial_number TEXT,
    collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (host_id) REFERENCES hosts(id)
);

-- 软件列表表
CREATE TABLE IF NOT EXISTS software (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    host_id INTEGER NOT NULL,
    display_name TEXT,
    display_version TEXT,
    publisher TEXT,
    install_date TEXT,
    install_location TEXT,
    collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (host_id) REFERENCES hosts(id)
);

-- 应用列表表
CREATE TABLE IF NOT EXISTS applications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    host_id INTEGER NOT NULL,
    name TEXT,
    version TEXT,
    publisher TEXT,
    install_location TEXT,
    collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (host_id) REFERENCES hosts(id)
);

-- 网络信息表
CREATE TABLE IF NOT EXISTS network_info (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    host_id INTEGER NOT NULL,
    adapter_name TEXT,
    interface_description TEXT,
    status TEXT,
    link_speed TEXT,
    ip_address TEXT,
    subnet_mask TEXT,
    gateway TEXT,
    dns_servers TEXT,
    mac_address TEXT,
    collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (host_id) REFERENCES hosts(id)
);

-- 进程列表表
CREATE TABLE IF NOT EXISTS processes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    host_id INTEGER NOT NULL,
    process_name TEXT,
    process_id INTEGER,
    cpu_usage REAL,
    memory_usage INTEGER,
    start_time TEXT,
    collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (host_id) REFERENCES hosts(id)
);

-- 服务列表表
CREATE TABLE IF NOT EXISTS services (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    host_id INTEGER NOT NULL,
    service_name TEXT,
    display_name TEXT,
    status TEXT,
    start_type TEXT,
    collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (host_id) REFERENCES hosts(id)
);

-- 计划任务表
CREATE TABLE IF NOT EXISTS scheduled_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    host_id INTEGER NOT NULL,
    task_name TEXT,
    task_path TEXT,
    state TEXT,
    last_run_time TEXT,
    next_run_time TEXT,
    collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (host_id) REFERENCES hosts(id)
);

-- 计划任务日志表
CREATE TABLE IF NOT EXISTS task_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    host_id INTEGER NOT NULL,
    task_name TEXT,
    log_level TEXT,
    log_message TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (host_id) REFERENCES hosts(id)
);

-- 批量操作表
CREATE TABLE IF NOT EXISTS batch_operations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_type TEXT NOT NULL,
    script_name TEXT,
    target_hosts TEXT,
    status TEXT DEFAULT 'Pending',
    total_hosts INTEGER DEFAULT 0,
    success_hosts INTEGER DEFAULT 0,
    failed_hosts INTEGER DEFAULT 0,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    duration_seconds INTEGER,
    created_by INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id)
);

-- 批量操作详情表
CREATE TABLE IF NOT EXISTS batch_operation_details (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_operation_id INTEGER NOT NULL,
    host_id INTEGER NOT NULL,
    status TEXT DEFAULT 'Pending',
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    error_message TEXT,
    output TEXT,
    FOREIGN KEY (batch_operation_id) REFERENCES batch_operations(id),
    FOREIGN KEY (host_id) REFERENCES hosts(id)
);

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_hosts_hostname ON hosts(hostname);
CREATE INDEX IF NOT EXISTS idx_hosts_ip_address ON hosts(ip_address);
CREATE INDEX IF NOT EXISTS idx_hosts_status ON hosts(status);
CREATE INDEX IF NOT EXISTS idx_host_status_host_id ON host_status(host_id);
CREATE INDEX IF NOT EXISTS idx_operations_host_id ON operations(host_id);
CREATE INDEX IF NOT EXISTS idx_operations_status ON operations(status);
CREATE INDEX IF NOT EXISTS idx_operations_type ON operations(operation_type);
CREATE INDEX IF NOT EXISTS idx_operation_logs_operation_id ON operation_logs(operation_id);
CREATE INDEX IF NOT EXISTS idx_system_info_host_id ON system_info(host_id);
CREATE INDEX IF NOT EXISTS idx_software_host_id ON software(host_id);
CREATE INDEX IF NOT EXISTS idx_applications_host_id ON applications(host_id);
CREATE INDEX IF NOT EXISTS idx_network_info_host_id ON network_info(host_id);
CREATE INDEX IF NOT EXISTS idx_processes_host_id ON processes(host_id);
CREATE INDEX IF NOT EXISTS idx_services_host_id ON services(host_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_host_id ON scheduled_tasks(host_id);
CREATE INDEX IF NOT EXISTS idx_task_logs_host_id ON task_logs(host_id);
CREATE INDEX IF NOT EXISTS idx_batch_operations_status ON batch_operations(status);
CREATE INDEX IF NOT EXISTS idx_batch_operation_details_batch_id ON batch_operation_details(batch_operation_id);

-- 插入默认管理员用户（密码: admin123，实际使用时应该加密）
INSERT OR IGNORE INTO users (username, password, email, role, is_active) 
VALUES ('admin', 'admin123', 'admin@itom.local', 'admin', 1);

-- 插入测试用户（密码: user123）
INSERT OR IGNORE INTO users (username, password, email, role, is_active) 
VALUES ('user', 'user123', 'user@itom.local', 'user', 1);