package main

import (
	"crypto/tls"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

// Item 用于匹配上传的JSON对象
type Item struct {
	VM_Location    string `json:"Location"`
	VM_UUID        string `json:"ID"`
	VM_Name        string `json:"Name"`
	VM_Status      string `json:"Status"`
	VM_Power_State string `json:"Power State"`
	VM_Networks    string `json:"Networks"`
	VM_Flavor_Name string `json:"Flavor Name"`
	VM_Flavor_ID   string `json:"Flavor ID"`
	VM_Avail_Zone  string `json:"Availability Zone"`
	VM_Host        string `json:"Host"`
}

const db_con = "user:pwd@tcp(127.0.0.1:3306)/vmdb"
const http_url = "127.0.0.1:3001"

var db *sql.DB // 全局数据库连接池

func main() {
	var err error
	db, err = sql.Open("mysql", db_con)
	if err != nil {
		log.Fatalf("Error connecting to database: %v", err)
	}
	defer db.Close()

	// 设置连接池参数
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(time.Minute * 5)

	http.HandleFunc("/vms_upload", vms_uploadHandler) // 设置路由和处理函数

	server := &http.Server{
		Addr:    http_url,
		Handler: nil, // 使用默认的处理器，即 DefaultServeMux
		TLSConfig: &tls.Config{
			MinVersion: tls.VersionTLS12, // 设置最小支持的 TLS 版本
		},
	}

	fmt.Println("Server started at " + http_url)
	// http.ListenAndServe(":8080", nil) // 启动服务器
	if err := server.ListenAndServeTLS("server.crt", "server.key"); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

// vms_uploadHandler 处理上传的POST请求
func vms_uploadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Only POST method is allowed", http.StatusMethodNotAllowed)
		return
	}

	// 限制上传数据的大小，这里限制为20MB
	maxSize := int64(20 * 1024 * 1024)
	r.Body = http.MaxBytesReader(w, r.Body, maxSize)

	// 解析请求体中的JSON数据
	var items []Item // 使用Item切片接收数据
	decoder := json.NewDecoder(r.Body)
	err := decoder.Decode(&items)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer r.Body.Close()

	// 发送响应
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("complete"))

	// 使用goroutine异步处理数据
	go func(items []Item) {
		// 遍历并打印JSON数据中的每个对象的键值对
		for _, item := range items {
			err := updateDatabase(item)
			if err != nil {
				log.Printf("Error updating database: %v", err)
				return
			}
		}

		// 数据一致性检查
		if err := checkConsistency(items); err != nil {
			log.Printf("Error in consistency check: %v", err)
			return
		}
	}(items)
}

// updateDatabase 更新数据库中的数据
func updateDatabase(item Item) error {
	// 判断字段不能为空
	if item.VM_Location == "" || item.VM_UUID == "" || item.VM_Name == "" {
		return fmt.Errorf("VM_Location, VM_UUID, and VM_Name cannot be empty")
	}

	// 查询数据库中是否已存在该记录
	var count int
	err := db.QueryRow("SELECT COUNT(*) FROM vms WHERE location = ? and vm_uuid = ?", item.VM_Location, item.VM_UUID).Scan(&count)
	if err != nil {
		return fmt.Errorf("Error checking existing record: %v", err)
	}

	if count > 0 {
		// 执行更新操作
		query := `UPDATE vms SET vm_name=?, vm_state=?, power_state=?, vm_nets=?, flavor_name=?, flavor_id=?, availability_zone=?, vm_host=?, updated_at=NOW(), is_deleted = false WHERE location=? and vm_uuid=?`
		_, err = db.Exec(query, item.VM_Name, item.VM_Status, item.VM_Power_State, item.VM_Networks, item.VM_Flavor_Name, item.VM_Flavor_ID, item.VM_Avail_Zone, item.VM_Host, item.VM_Location, item.VM_UUID)
	} else {
		// 执行插入操作
		query := `INSERT INTO vms(location, vm_uuid, vm_name, vm_state, power_state, vm_nets, flavor_name, flavor_id, availability_zone, vm_host) VALUES(?,?,?,?,?,?,?,?,?,?)`
		_, err = db.Exec(query, item.VM_Location, item.VM_UUID, item.VM_Name, item.VM_Status, item.VM_Power_State, item.VM_Networks, item.VM_Flavor_Name, item.VM_Flavor_ID, item.VM_Avail_Zone, item.VM_Host)
	}
	if err != nil {
		return fmt.Errorf("Error executing insert query: %v", err)
	}

	return nil
}

func checkConsistency(items []Item) error {
	// 提取上传数据中所有唯一的location值
	locations := make(map[string]bool)
	for _, item := range items {
		locations[item.VM_Location] = true
	}

	// 构建一个map来快速检查上传的数据中是否存在特定的location和vm_uuid组合
	uploaded := make(map[string]bool)
	for _, item := range items {
		key := item.VM_Location + ":" + item.VM_UUID
		uploaded[key] = true
	}

	// 对每个location，查询数据库中匹配的记录
	for location := range locations {
		rows, err := db.Query("SELECT location, vm_uuid FROM vms WHERE is_deleted = false AND location = ?", location)
		if err != nil {
			return fmt.Errorf("Error querying database: %v", err)
		}

		for rows.Next() {
			var loc, uuid string
			if err := rows.Scan(&loc, &uuid); err != nil {
				rows.Close()
				return fmt.Errorf("Error scanning row: %v", err)
			}
			key := loc + ":" + uuid
			if !uploaded[key] {
				// 如果数据库中的记录在上传的数据中不存在，标记为已删除
				if _, err := db.Exec("UPDATE vms SET is_deleted = true, deleted_at = NOW() WHERE location = ? AND vm_uuid = ?", loc, uuid); err != nil {
					rows.Close()
					return fmt.Errorf("Error updating record as deleted: %v", err)
				}
			}
		}
		rows.Close()
	}

	return nil
}

// 其他测试实例
/*
CREATE DATABASE vmdb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

CREATE TABLE vms (
    id INT NOT NULL AUTO_INCREMENT,
    location VARCHAR(255) NOT NULL,
    vm_uuid VARCHAR(36) NOT NULL,
    vm_name VARCHAR(255) NOT NULL,
    vm_state VARCHAR(255) DEFAULT NULL,
    power_state VARCHAR(36) DEFAULT NULL,
    vm_nets VARCHAR(255) DEFAULT NULL,
    flavor_name VARCHAR(255) DEFAULT NULL,
    flavor_id VARCHAR(36) DEFAULT NULL,
    availability_zone VARCHAR(255) DEFAULT NULL,
    vm_host VARCHAR(255) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP DEFAULT NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE USER 'user'@'%' IDENTIFIED BY 'pwd';
GRANT ALL PRIVILEGES ON *.* TO 'user'@'%';
FLUSH PRIVILEGES;

TRUNCATE TABLE table_name;

curl -k -X POST https://127.0.0.1:3001/vms_upload -d @vm_json.txt
*/
