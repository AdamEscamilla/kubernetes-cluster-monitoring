resource "aws_security_group" "node_host_sg" {
  name        = "${var.env}-node-host"
  description = "Allow all inbound traffic between workers"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
  }

  ingress {
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
  }

  ingress {
    from_port   = 2380
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
  }

  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
  }

  ingress {
    from_port   = 8285
    to_port     = 8285
    protocol    = "udp"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
  }

  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
  }

  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.env}-node-host-sg"
  }
}

resource "aws_instance" "node" {
  ami           = "${lookup(var.ami, var.region)}"
  instance_type = "${var.node_instance_type}"
  key_name      = "${var.key_name}"
  subnet_id     = "${aws_subnet.private.1.id}"
  private_ip    = "${var.instance_ips[1]}"
  user_data     = "${file("userdata/node-kube.config")}"

  vpc_security_group_ids = [
    "${aws_security_group.node_host_sg.id}",
  ]

  connection {
    type         = "ssh"
    user         = "core"
    bastion_user = "ubuntu"
    bastion_host = "${aws_instance.bastion.public_ip}"
    private_key  = "${file(var.private_key_path)}"
  }

  provisioner "file" {
    source      = "static/node/"
    destination = "/home/core"
  }

  provisioner "file" {
    source      = "scripts/node-install.sh"
    destination = "install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x install.sh",
      "sh install.sh",
    ]
  }

  tags {
    Name = "${var.env}-node-${count.index + 1}"
  }

  count = "${var.node_instance_count}"
}
