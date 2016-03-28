output "rancher_main_ip" {
    value = "${aws_instance.rancher_main.private_ip}"
}
output "rancher_elb" {
    value = "${aws_elb.rancher_elb.dns_name}"
}
