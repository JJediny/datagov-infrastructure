provider "aws" {
    region = "${var.region}"
    profile = "${var.aws_profile}"
}

# CREATE RANCHER ELB
resource "aws_elb" "rancher_elb" {
    name = "rancher-elb"
    subnets = ["${aws_subnet.datagov-publica.id}", "${aws_subnet.datagov-publicb.id}"]
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


# CREATE JUMP HOST
resource "aws_instance" "datagov_jump" {
    ami = "${lookup(var.ubuntu_amis, var.region)}"
    instance_type = "m3.xlarge"
    key_name = "${var.key_name}"
    vpc_security_group_ids = ["${aws_security_group.datagov_jumphost.id}"]
    subnet_id = "${aws_subnet.datagov-publica.id}"
    root_block_device = {
        volume_type = "gp2"
        volume_size = 100
    }
    ephemeral_block_device = {
        device_name = "/dev/sdb"
        virtual_name = "ephemeral0"
    }
    tags = {
        Name = "datagov_jumphost"
        client = "datagov"
    }
}

# ASSOCIATE ELASTIC IP WITH JUMP HOST
resource "aws_eip" "jump" {
	instance = "${aws_instance.datagov_jump.id}"
	vpc = true
}

# CREATE RANCHER INSTANCE
resource "aws_instance" "rancher_main" {
    ami = "${lookup(var.rancher_amis, var.region)}"
    instance_type = "m3.xlarge"
    key_name = "${var.key_name}"
    vpc_security_group_ids = ["${aws_security_group.rancher.id}"]
    subnet_id = "${aws_subnet.datagov-privatea.id}"
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
        private_key = "${file("~/datagov-rancher.pem")}"
        bastion_host = "${aws_instance.datagov_jump.public_dns}"
        bastion_user = "ubuntu"
        bastion_private_key = "${file("~/datagov-rancher.pem")}"
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

