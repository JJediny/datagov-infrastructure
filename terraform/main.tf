provider "aws" {
    region = "${var.region}"
    profile = "${lookup(var.aws, "profile")}"
}

resource "aws_security_group" "rancher_elb_sg" {
    name = "rancher-elb-sg"
    description = "Security Group for Rancher Management ELB"
    vpc_id = "${lookup(var.vpc_id, var.region)}"

    # HTTP Access for Aquilent
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["12.153.61.2/32", "184.72.100.147/32"]
    }
    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["12.153.61.2/32", "184.72.100.147/32"]
    }
    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "rancher" {
    name = "rancher"
    description = "Main SG for Rancher"
    vpc_id = "${lookup(var.vpc_id, var.region)}"
    ingress {
        from_port = 22
        to_port= 22
        protocol = "tcp"
        security_groups = ["sg-fbf2fd82"]
    }
    ingress {
        from_port = 0
        to_port = 65535
        protocol = "tcp"
        self = true
    }
    ingress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        self = true
    }
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = ["${aws_security_group.rancher_elb_sg.id}"]
    }
    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        security_groups = ["${aws_security_group.rancher_elb_sg.id}"]
    }
    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
}
}

resource "aws_elb" "rancher_elb" {
    name = "rancher-elb"
    subnets = ["${lookup(var.subnet_id, "us-east-1_publicA")}", "${lookup(var.subnet_id, "us-east-1_publicB")}" ]
    security_groups = ["${aws_security_group.rancher_elb_sg.id}"]
    instances = ["${aws_instance.rancher_main.id}"]
    listener = {
        instance_port = "8080"
        instance_protocol = "http"
        lb_port = "80"
        lb_protocol = "http"
    }
    listener = {
        instance_port = "80"
        instance_protocol = "http"
        lb_port = "8000"
        lb_protocol = "http"
    }
    health_check = {
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 3
        target = "HTTP:80/"
        interval = 10
    }
    cross_zone_load_balancing = true
    tags = {
        Name = "rancher-elb"
        client = "datagov"
    }
}

resource "aws_db_subnet_group" "rancher" {
    name = "rancher"
    description = "Datagov Rancher DB Subnet"
    subnet_ids = [""${lookup(var.subnet_id, "us-east-1_privateA")}"", ""${lookup(var.subnet_id, "us-east-1_privateB")}""]
    tags {
        Name = "Rancher DB subnet group"
    }
}

resource "aws_db_security_group" "rancher" {
    name = "datagov_rancher_db"
    description = "Rancher RDS SG"

    ingress {
        security_group_id = "${aws_security_group.rancher.id}"
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
	db_subnet_group_name = "${aws_db_subnet_group.rancher.id}"
	vpc_security_group_ids = "${aws_db_subnet_group.rancher.id}"
	tags {
		Name = "Rancher Database"
	}
}

resource "aws_instance" "rancher_main" {
    ami = "${lookup(var.rancher_amis, var.region)}"
    instance_type = "m3.xlarge"
    key_name = "datagov_bosh"
    vpc_security_group_ids = ["${aws_security_group.rancher.id}"]
    subnet_id = "${lookup(var.subnet_id, "us-east-1_privateA")}"
    root_block_device = {
        volume_type = "gp2"
        volume_size = 100
    }
    ephemeral_block_device = {
        device_name = "/dev/sdb"
        virtual_name = "ephemeral0"
    }
    tags = {
        Name = "rancher_main"
        client = "datagov"
    }
connection {
        user = "rancher"
        host = "${aws_instance.rancher_main.private_ip}"
        private_key = "${file("/PATH/TO/PEM_FILE")}"
        bastion_host = "${lookup(var.jump_host, "hostname")}"
        bastion_user = "${lookup(var.jump_host, "user")}"
        bastion_private_key = "${file("/PATH/TO/PEM_FILE")}"
    }
    provisioner "remote-exec" {

        inline = [
        "sudo mkdir -p /opt/rancher/bin",
        "echo ${var.start_rancher} | sudo tee -a /opt/rancher/bin/start.sh",
        "sudo chmod 755 /opt/rancher/bin/start.sh",
        "sudo /opt/rancher/bin/start.sh"
        ]
    }
}

