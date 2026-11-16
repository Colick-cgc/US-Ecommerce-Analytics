## customers  为不同的表格添加主键alter,这里多了一步因为从python导入过来默认把字符串转换为text格式，但设置主键的时候不允许使用这个么长的text
alter table customers modify column customer_id varchar(50) not null;
alter table customers add primary key (customer_id);
## geo  在这个表格里面，由于邮编有重复值，所以需要手动建立一个主键id
alter table geolocation add column id int auto_increment primary key first;
## orders  
alter table orders modify column order_id varchar(50) not null;
alter table orders add primary key (order_id);
## products
alter table products modify column product_id varchar(50) not null;
alter table products add primary key (product_id);
## sellers
alter table sellers modify column seller_id varchar(50) not null;
alter table sellers add primary key (seller_id);