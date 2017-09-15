provider "aws" {
  region = "${var.region}"
}

resource "aws_key_pair" "root" {
  key_name   = "${var.key_name}"
  public_key = "${var.public_key}"
}
