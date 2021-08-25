resource "aws_route_table_association" "public" {
  subnet_id = "${aws_subnet.subnet_public1_Lab1.id}"  # How to put pub_subnet_azc.id into here?
  route_table_id = "${aws_route_table.r.id}"
}
resource "aws_instance" "testInstance1" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id = "${aws_subnet.subnet_public1_Lab1.id}"
  vpc_security_group_ids = ["${aws_security_group.TerraformSG.id}"]
  key_name = "${var.namespace}-key"
 tags ={
    Environment = "${var.environment_tag}"
    Name= "myos_terraform_aws"
  }


provisioner "file" {
    source      = "C://Users/Administrator/Desktop/index.html"
    destination = "/home/ec2-user/index.html"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${var.namespace}-key.pem")
      host        = aws_instance.testInstance1.public_ip
    }
  }

provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${var.namespace}-key.pem")
      host        = aws_instance.testInstance1.public_ip
    }

    inline = [
      "sudo sudo yum install httpd -y",
      "sudo mv /home/ec2-user/index.html    /var/www/html/index.html",
      "sudo systemctl  start  httpd",
      "sudo systemctl  enable  httpd",
    ]

    }

}
