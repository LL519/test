#04-索引的设计原则
#为了使索引的使用效率更高，在创建索引时，必须考虑在哪些字段上创建索引和创建
#什么类型的索引。索引设计不合理或者缺少索引都会对数据库和应用程序的性能造成
#障碍。高效的索引对于获得良好的性能非常重要。设计索引时，应该考虑相应准则。

#1.数据准备
CREATE DATABASE ll;
USER 11;

CREATE TABLE `student_info`(
`id` INT(11) AUTO_INCREMENT,
`student_id` INT NOT NULL,
`name` VARCHAR(20) DEFAULT NULL,
`course_id` INT NOT NULL,
`class_id` INT(11) DEFAULT NULL,
`create_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
PRIMARY KEY(`id`)
)ENGINE=INNODB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

CREATE TABLE `course`(
`id` INT(11) AUTO_INCREMENT,
`course_id` INT NOT NULL,
`course_name` VARCHAR(40) DEFAULT NULL,
PRIMARY KEY(`id`)
)ENGINE=INNODB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

#函数1:创建随机产生字符串函数

DELIMITER //
CREATE FUNCTION rand_string(n INT)
	RETURNS VARCHAR(255)#该函数会返回一个字符串
BEGIN
	DECLARE chars_str VARCHAR(100) DEFAULT 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
	DECLARE return_str VARCHAR(255) DEFAULT '';
	DECLARE i INT DEFAULT 0;
	WHILE i < n DO
	SET return_str = CONCAT(return_str,SUBSTRING(chars_str,FLOOR(1+RAND()*52),1));
	SET i = i + 1;
     END WHILE;
     RETURN return_str;
END//
DECLARE ;

SELECT @@log_bin_trust_function_creators;
SET GLOBAL log_bin_trust_function_creators=1;

#函数2：创建随机数函数
DELIMITER //
CREATE FUNCTION rand_num (from_num INT,to_num INT) RETURNS INT(11)
BEGIN
DECLARE i INT DEFAULT 0;
SET i = FLOOR(from_num +RAND()*(to_num - from_num+1))   ;
RETURN i;
END //
DELIMITER ;
	
#存储过程1:创建插入课程表存储过程
DELIMITER //
CREATE PROCEDURE insert_course(max_num INT)
BEGIN
DECLARE i INT DEFAULT 0;
   SET autocommit = 0; #设置手动提交事务
   REPEAT #循环
   SET i = i + 1; #赋值
   INSERT INTO course(course_id,course_name) VALUES (rand_num(10000,10100),rand_string(6));
   UNTIL i = max_num
   END REPEAT;
   COMMIT; #提交事务
END //
DELIMITER ;

#存储过程2:创建插入学生信息表存储过程
DELIMITER //
CREATE PROCEDURE insert_stu(max_num INT)
BEGIN
DECLARE i INT DEFAULT 0;
   SET autocommit = 0; #设置手动提交事务
   REPEAT #循环
   SET i = i + 1; #赋值
   INSERT INTO student_info(course_id,class_id,student_id,NAME) VALUES (rand_num(10000,10100),rand_num(10000,10200),rand_num(1,200000),rand_string(6));
   UNTIL i = max_num
   END REPEAT;
   COMMIT; #提交事务
END //
DELIMITER ;

#调用存储过程
CALL insert_course(100);
SELECT * FROM course;
CALL insert_stu(1000000);
SELECT COUNT(*) FROM student_info;

#2.哪些情况适合加索引
#① 字段的数值有唯一性限制
#索引本身可以起到约束的作用，比如唯一索引、主键索引都是可以起到唯一性约束的，因此在我们的数据表中如果
#某个字段是唯一性的，就可以直接 创建唯一性索引，或者 主键索引。这样可以更快速地通过该索引来确定某条记录。

#② 频繁作为WHERE查询条件的字段
#某个字段在SELECT语句的 WHERE 条件中经常被使用到，那么就需要给这个字段创建索引了。尤其是在数据量大的情况
#下，创建普通索引就可以大幅提升数据查询的效率。
#查看当前student_info表中的索引
SHOW INDEX FROM student_info;
#student_id字段上是没有索引的
SELECT course_id,class_id,NAME,create_time,student_id
FROM student_info
WHERE student_id = 123110;#2051ms

#给student_id字段添加索引
ALTER TABLE student_info 
ADD INDEX idx_sid(student_id);

#student_id字段上是有索引的
SELECT course_id,class_id,NAME,create_time,student_id
FROM student_info
WHERE student_id = 123110;#1ms

#③ 经常 GROUP BY和ORDER BY的列
#索引就是让数据按照某种顺序进行存储或检索，因此当我们使用GROUP BY对数
#据进行分组查询，或者使用ORDER BY 对数据进行排序的时候，就需要 对分组
#或者排序的字段进行索引。如果待排序的列有多个，那么可以在这些列上建立组合索引。

#student_id字段上是没有索引的
SELECT student_id,COUNT(*) AS num
FROM student_info
GROUP BY student_id
LIMIT 100;#4088ms

#删除idx_sid索引
ALTER TABLE student_info DROP INDEX idx_sid;

#student_id字段上是有索引的
SELECT student_id,COUNT(*) AS num
FROM student_info
GROUP BY student_id
LIMIT 100;#1ms

#再测试
#查看当前student_info表中的索引
SHOW INDEX FROM student_info;

#添加单列索引
ALTER TABLE student_info ADD INDEX idx_sid(student_id);

ALTER TABLE student_info ADD INDEX idx_cre_time(create_time);

SELECT student_id,COUNT(*) AS num
FROM student_info
GROUP BY student_id
ORDER BY create_time DESC
LIMIT 100;#5864ms

#修改sql_mode
SELECT @@sql_mode;
SET @@sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

#添加联合索引
ALTER TABLE student_info ADD INDEX idx_sid_cre_time(student_id,create_time DESC);

SELECT student_id,COUNT(*) AS num
FROM student_info
GROUP BY student_id
ORDER BY create_time DESC
LIMIT 100;#315ms

#进一步测试
ALTER TABLE student_info ADD INDEX idx_cre_time_sid(create_time DESC,student_id);

DROP INDEX idx_sid_cre_time ON student_info;

SELECT student_id,COUNT(*) AS num
FROM student_info
GROUP BY student_id
ORDER BY create_time DESC
LIMIT 100;#4831ms

#④ UPDATE、DELETE 的 WHERE 条件列
#对数据按照某个条件进行查询后再进行UPDATE或DELETE的操作，如果对WHERE字
#段创建了索引，就能大幅提升效率。原理是因为我们需要先根据WHERE条件列检
#索出来这条记录，然后再对它进行更新或删除。如果进行更新的时候，更新的
#字段是非索引字段，提升的效率会更明显，这是因为非索引字段更新不需要对索引进行维护

#查看当前student_info表中的索引
SHOW INDEX FROM student_info;
#没有索引
UPDATE student_info 
SET student_id = 10002
WHERE NAME = '462eed7ac6e791292a79';#898ms

#添加索引
ALTER TABLE student_info 
ADD INDEX idx_name(NAME);
#有索引
UPDATE student_info 
SET student_id = 10001
WHERE NAME = '462eed7ac6e791292a79';#1ms

#⑤ DISTINCT 字段需要创建索引
#有时候我们需要对某个字段进行去重，使用DISTINCT，那么对这个字段创建
#索引，也会提升查询效率.

#⑥ 多表JOIN 连接操作时，创建索引注意事项
#首先，连接表的数量尽量不要超过3张，因为每增加一张表就相当于增加了一次
#嵌套的循环，数量级增长会非常快，严重影响查询的效率。
#其次，对WHERE条件创建索引，因为WHERE才是对数据条件的过滤。如果在数据量
#非常大的情况下，没有WHERE 条件过滤是非常可怕的。
#最后，对用于连接的字段创建索引，并且该字段在多张表中的类型必须一致。
#比如course_id在student_info表和course表中都为int(11) 类型，而
#不能一个为int另一个为varchar 类型

#⑦ 使用列的类型小的创建索引
#我们这里所说的 类型大小 指的就是该类型表示的数据范围的大小。

#我们在定义表结构的时候要显式的指定列的类型，以整数类型为例，有TINYINT、
#MEDIUMINT 、INT.BIGINT 等，它们占用的存储空间依次递增，能表示的整数范
#围当然也是依次递增。如果我们想要对某个整数列建立索引的话，在表示的整数
#范围允许的情况下，尽量让索引列使用较小的类型，比如我们能使用INT就不要
#使用 BIGINT，能使用 MEDIUMINT 就不要使用 INT 。这是因为:

#	数据类型越小，在查询时进行的比较操作越快

#	数据类型越小，索引占用的存储空间就越少，在一个数据页内就可以放
#	下更多的记录，从而减少磁盘 工/0 带来的性能损耗，也就意味着可以
#	把更多的数据页缓存在内存中，从而加快读写效率。

#这个建议对于表的主键来说更加适用，因为不仅是聚族索引中会存储主键值，其
#他所有的二级索引的节点处都会存储一份记录的主键值，如果主键使用更小的数
#据类型，也就意味着节省更多的存储空间和更高效的I/O。

#⑧ 使用字符串前缀创建索引
#假设我们的字符串很长，那存储一个字符串就需要占用很大的存储空间。在我们
#需要为这个字符串列建立索引时，那就意味着在对应的B+树中有这么两个问题:

#	B+树索引中的记录需要把该列的完整字符串存储起来，更费时。而且字符串
#	越长，在索引中占用的存储空间越大

#	如果B+树索引中索引列存储的字符串很长，那在做字符串比较时会占用更多的时间
#	
#我们可以通过截取字段的前面一部分内容建立索引，这个就叫前缀索引。
#这样在查找记录时虽然不能精确的定位到记录的位置，但是能定位到相应前缀
#所在的位置，然后根据前缀相同的记录的主键值回表查询完整的字符串值。
#既节约空间 ，又减少了字符串 的比较时间 ，还大体能解决排序的问题。

#拓展: Alibaba《Java开发手册》
#[强制]在 varchar 字段上建立索引时，必须指定索引长度，没必要对全字段
#建立索引，根据实际文本区分度决定索引长度。
#说明:索引的长度与区分度是一对矛盾体，一般对字符串类型数据，长度为20的
#索引，区分度会高达90%以上，可以使用count(distinct left(列名,索引长度))/count()的区分度来确定

#⑨ 区分度高(散列性高)的列适合作为索引
#列的基数指的是某一列中不重复数据的个数，比方说某个列包含值2,5,8,2,5,8,2,5,8，
#虽然有9条记录，但该列的基数却是3。也就是说，在记录行数一定的情况下，列的基数
#越大，该列中的值越分散;列的基数越小，该列中的值越集中。这个列的基数指标非常重
#要，直接影响我们是否能有效的利用索引。最好为列的基数大的列建立索引，为基数太小
#列的建立索引效果可能不好。
#可以使用公式select count (distinct a)/count(*) from t1计算区分度，越接近越好，
#一般超过33%就算是比较高效的索引了
#拓展: 联合索引把区分度高(散列性高)的列放在前面。

#⑩ 使用最频繁的列放到联合索引的左侧
#这样也可以较少的建立一些索引。同时，由于"最左前缀原则"，可以增加联合
#索引的使用率。

#补充 在多个字段都要创建索引的情况下，联合索引优于单值索引

#3 限制索引的数目
#在实际工作中，我们也需要注意平衡，索引的数目不是越多越好。我们需要限制
#每张表上的索引数量，建议单张表索引数量不超过6个。原因:

#	每个索引都需要占用 磁盘空间，索引越多，需要的磁盘空间就越大。

#	索引会影响 INSERT、DELETE、UPDATE等语句的性能，因为表中的数据更改的
#	同时，索引也会进行调整和更新，会造成负担。

#	优化器在选择如何优化查询时，会根据统一信息，对每一个可以用到的索引来
#	进行评估，以生成出一个最好的执行计划，如果同时有很多个索引都可以用于
#	查询，会增加MySQL优化器生成执行计划时间，降低查询性能。


#4 哪些情况下不适合创建索引
#① 在where中使用不到的字段，不要设置索引
#WHERE条件(包括 GROUP BY、ORDER BY)里用不到的字段不需要创建索引，索引
#的价值是快速定位，如果起不到定位的字段通常是不需要创建索引的。

#② 数据量小的表最好不要使用索引
#如果表记录太少，比如少于1000个，那么是不需要创建索引的。表记录太少，
#是否创建索引 对查询效率的影响并不大。甚至说，查询花费的时间可能比遍
#历索引的时间还要短，索引可能不会产生优化效果。

#结论:在数据表中的数据行数比较少的情况下，比如不到1000行，是不需要创建索引的。

#③ 有大量重复数据的列上不要建立索引
#在条件表达式中经常用到的不同值较多的列上建立索引，但字段中如果有大量
#重复数据，也不用创建索引。比如在学生表的“性别”字段上只有“男”与“女”两
#个不同值，因此无须建立索引。如果建立索引，不但不会提高查询效率，反而
#会严重降低数据更新速度

#结论:当数据重复度大，比如 高于 10% 的时候，也不需要对这个字段使用索引。

#④ 避免对经常更新的表创建过多的索引
#第一层含义:频繁更新的字段不一定要创建索引。因为更新数据的时候，也需要
#更新索引，如果索引大多，在更新索引的时候也会造成负担，从而影响效率。
#第二层含义:避免对经常更新的表创建过多的索引，并且索引中的列尽可能少。
#此时，虽然提高了查询速度，同时却会降低更新表的速度。

#⑤ 不建议用无序的值作为索引
#例如身份证、UUID(在索引比较时需要转为ASCIL，并且插入时可能造成页分裂)
#、MD5、HASH、无序长字符串等.

#⑥删除不再使用或者很少使用的索引
#表中的数据被大量更新，或者数据的使用方式被改变后，原有的一些索引可能
#不再需要。数据库管理员应当定期找出这些索引，将它们删除，从而减少索引
#对更新操作的影响。

#⑦ 不要定义元余或重复的索引

#5  小结
#索引是一把双刃剑，可提高查询效率，但也会降低插入和更新的速度并占用磁
#盘空间。选择索引的最终目的是为了使查询的速度变快，上面给出的原则是最
#基本的准则，但不能拘泥于上面的准则，大家要在以后的学习和工作中进行不
#断的实践，根据应用的实际情况进行分析和判断，选择最合适的索引方式