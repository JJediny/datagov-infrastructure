output "datagov_jumphost_ip" {
	value = "${aws_eip.jump.public_ip}"
}

output "rancher_main_ip" {
    value = "${aws_instance.rancher_main.private_ip}"
}

output "rancher_rds_endpoint" {
	value = "${aws_db_instance.rancher_db.endpoint}"
}

output "rancher_elb" {
    value = "${aws_elb.rancher_elb.dns_name}"
}
