provider "aws" {
  profile    = "default"
  region     = "us-east-1"
}

# vpc
resource "aws_vpc" "gazetteer-vpc" {
  cidr_block = "10.0.0.0/16"
}

# subnet
resource "aws_subnet" "gazetteer-subnet" {
  vpc_id     = "${aws_vpc.gazetteer-vpc.id}"
  cidr_block = "10.0.0.0/16"
}

# s3 bucket for vector tiles
resource "aws_s3_bucket" "gazetteer-bucket" {
  bucket = "gazetteer-bucket"
  acl    = "private"
}

# postgis serverless database for spatial data
resource "aws_rds_cluster" "gazetteer-database" {
  cluster_identifier      = "gazetteer-database"
  engine                  = "aurora-postgresql"
  engine_mode             = "serverless"
  database_name           = "gazetteer"
  master_username         = "gazetteer"
  master_password         = "gazetteer"
}

# iam role and policy
resource "aws_iam_role" "gazetteer-role" {
  name = "gazetteer-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "gazetteer-cluster-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.gazetteer-role.name}"
}

resource "aws_iam_role_policy_attachment" "gazetteer-service-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.gazetteer-role.name}"
}

# kubernetes cluster for running tasks and services
resource "aws_eks_cluster" "gazetteer-cluster" {
  name     = "gazetteer-cluster"
  role_arn = "${aws_iam_role.gazetteer-role.arn}"

  vpc_config {
    subnet_ids = ["${aws_vpc.gazetteer-vpc.id}"]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    "aws_iam_role.gazetteer-role",
    "aws_iam_role_policy_attachment.gazetteer-cluster-policy",
    "aws_iam_role_policy_attachment.gazetteer-service-policy",
  ]
}

output "endpoint" {
  value = "${aws_eks_cluster.gazetteer-cluster.endpoint}"
}

output "kubeconfig-certificate-authority-data" {
  value = "${aws_eks_cluster.gazetteer-cluster.certificate_authority.0.data}"
}

