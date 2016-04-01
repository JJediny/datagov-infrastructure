
resource "aws_db_subnet_group" "rancher" {
    name = "rancher"
    description = "Datagov Rancher DB Subnet"
    subnet_ids = [""${lookup(var.subnet_id, "us-east-1_privateA")}"", ""${lookup(var.subnet_id, "us-east-1_privateB")}""]
    tags {
        Name = "Rancher DB subnet group"
    }
}

resource "aws_rds_instance" "rancher_db" {
	engine = "mysql"
	engine_version = "5.6.27"
	allocated_storate = ${var.rds_disk_size}
	storage_type = "gp2"
	instance_class = "${var.rds_size}"
	identifier = "rancher"
	final_snapshot_identifier = "datagov_rancher"
	copy_tags_to_snapshot = true
	name = "cattle"
	username = "${var.rds_user}"
	password = "${var.rds_pass}"
	publicly_accessible = false
	vpc_security_group_ids = ["${aws_security_group.rancher.id}"]
	tags {
		Name = "Rancher Database"
	}
}
