CREATE TABLE IF NOT EXISTS bwb_customer_user_email (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_user_login VARCHAR(191) NOT NULL,
    email VARCHAR(150) NOT NULL,
    create_time DATETIME NOT NULL,
    create_by INT NOT NULL,
    change_time DATETIME NOT NULL,
    change_by INT NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY bwb_customer_user_email_unique_email (email),
    KEY bwb_customer_user_email_login (customer_user_login)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
