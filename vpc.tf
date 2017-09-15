resource "aws_vpc" "vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = "${var.enable_dns_hostnames}"
  enable_dns_support   = "${var.enable_dns_support}"

  tags {
    Name = "${var.env}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "${var.env}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "${var.env}-public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "${var.env}-private"
  }

  count = "${length(var.private_subnets)}"
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.igw.id}"
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = "${aws_route_table.private.*.id[count.index]}"
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = "${aws_instance.nat.id}"
  count                  = "${length(var.private_subnets)}"
}

resource "aws_subnet" "public" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = "${var.map_public_ip_on_launch}"
  count                   = "${length(var.public_subnets)}"
  availability_zone       = "${var.region}${element(var.availability_zones, count.index)}"
  cidr_block              = "${var.public_subnets[count.index]}"

  tags {
    Name = "${var.env}-${var.stack}-${var.region}${element(var.availability_zones, count.index)}-public"
  }
}

resource "aws_subnet" "private" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = "false"
  count                   = "${length(var.private_subnets)}"
  availability_zone       = "${var.region}${element(var.availability_zones, count.index)}"
  cidr_block              = "${var.private_subnets[count.index]}"

  tags {
    Name = "${var.env}-${var.stack}-${var.region}${element(var.availability_zones, count.index)}-private"
  }
}

resource "aws_route_table_association" "private" {
  count          = "${length(var.private_subnets)}"
  subnet_id      = "${aws_subnet.private.*.id[count.index]}"
  route_table_id = "${aws_route_table.private.*.id[count.index]}"
}

resource "aws_route_table_association" "public" {
  count          = "${length(var.public_subnets)}"
  subnet_id      = "${aws_subnet.public.*.id[count.index]}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_security_group" "bastion" {
  vpc_id      = "${aws_vpc.vpc.id}"
  name        = "${var.env}-bastion-host"
  description = "Allow SSH to bastion host"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["73.166.0.0/16"]
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
    Name = "${var.env}-bastion-sg"
  }
}

resource "aws_instance" "bastion" {
  ami                         = "${lookup(var.bastion_ami, var.region)}"
  instance_type               = "${var.bastion_instance_type}"
  key_name                    = "${var.key_name}"
  monitoring                  = true
  vpc_security_group_ids      = ["${aws_security_group.bastion.id}"]
  subnet_id                   = "${aws_subnet.public.*.id[0]}"
  associate_public_ip_address = true

  tags {
    Name = "${var.env}-bastion"
  }
}

resource "aws_security_group" "nat" {
  vpc_id      = "${aws_vpc.vpc.id}"
  name        = "${var.env}-nat-host"
  description = "Allow SSH to nat host"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_vpc.vpc.cidr_block}"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
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
    Name = "${var.env}-nat-sg"
  }
}

resource "aws_instance" "nat" {
  ami                         = "${lookup(var.nat_ami, var.region)}"
  instance_type               = "${var.nat_instance_type}"
  key_name                    = "${var.key_name}"
  monitoring                  = true
  vpc_security_group_ids      = ["${aws_security_group.nat.id}"]
  subnet_id                   = "${aws_subnet.public.*.id[0]}"
  source_dest_check           = false
  associate_public_ip_address = true

  tags {
    Name = "${var.env}-nat"
  }
}
