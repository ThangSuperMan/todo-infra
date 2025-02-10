resource "aws_instance" "bastion" {
  ami                         = var.bastion_ami
  instance_type               = var.bastion_instance_type
  key_name                    = var.key_name
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.bastion_sg_id]
  associate_public_ip_address = true

  provisioner "remote-exec" {
    inline = [
      "sudo dnf update",
      "sudo dnf install -y mariadb105"
    ]
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = var.bastion_private_key
    host        = self.public_ip
  }

  tags = {
    Name        = "${var.environment}-bastion"
    Environment = "${var.environment}"
  }
}

resource "aws_iam_role" "eks" {
  name = "${var.environment}-eksClusterAdmin"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "eks.amazonaws.com"
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

resource "aws_eks_cluster" "eks" {
  name     = "${var.environment}-cluster"
  version  = var.eks_config.kubernetes_version
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    endpoint_public_access  = true
    endpoint_private_access = false

    subnet_ids = var.private_subnet_ids
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.amazon_eks_cluster_policy]
}

resource "aws_iam_role" "nodes" {
  name = "${var.environment}-eksEC2NodeGroup"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.eks.name
  version         = var.eks_config.kubernetes_version
  node_group_name = var.eks_config.node_group.name
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids
  capacity_type   = var.eks_config.node_group.capacity_type
  instance_types  = [var.eks_config.node_group.instance_type]

  scaling_config {
    desired_size = var.eks_config.node_group.scaling_config.desired_size
    max_size     = var.eks_config.node_group.scaling_config.max_size
    min_size     = var.eks_config.node_group.scaling_config.min_size
  }

  update_config {
    max_unavailable = var.eks_config.node_group.max_unavailable_node
  }

  labels = {
    role = var.eks_config.node_group.name
  }

  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

resource "aws_eks_addon" "eks_addon_pod_identity" {
  cluster_name             = aws_eks_cluster.eks.name
  addon_name               = "eks-pod-identity-agent"
  addon_version            = "v1.3.4-eksbuild.1"
  service_account_role_arn = aws_iam_role.pod_identity.arn
}

resource "aws_iam_role" "pod_identity" {
  name = "${var.environment}-eksPodIdentity"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
          "Service": [
              "pods.eks.amazonaws.com"
          ]
      },
      "Action": [
          "sts:AssumeRole",
          "sts:TagSession"
      ]
    }
  ]
}
POLICY
}

// TODO: remove this one
resource "aws_iam_role_policy_attachment" "s3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role       = aws_iam_role.pod_identity.name
}

resource "aws_eks_pod_identity_association" "pod_identity" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "test"
  service_account = "nginx-sa"
  role_arn        = aws_iam_role.pod_identity.arn
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"

  values = [file("${path.module}/values/metrics-server.yaml")]

  depends_on = [aws_eks_node_group.general]
}

resource "helm_release" "application" {
  name       = "todo-cozy"
  repository = "https://thangsuperman.github.io/todo-manifests"
  chart      = "todo-cozy"
  namespace  = "default"
  version    = "0.1.0"

  depends_on = [aws_eks_node_group.general]
}


resource "aws_iam_role" "lbc" {
  name = "${var.environment}-eksPodIdentityLoadBalancerController"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
          "Service": [
              "pods.eks.amazonaws.com"
          ]
      },
      "Action": [
          "sts:AssumeRole",
          "sts:TagSession"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "lbc" {
  # TODO: should improve this one to add the specific Resource not for all resources
  policy = file("${path.module}/iam/AWSLoadBalancerController.json")
  name   = "AWSLoadBalancerController"
}

resource "aws_iam_role_policy_attachment" "lbc" {
  policy_arn = aws_iam_policy.lbc.arn
  role       = aws_iam_role.lbc.name
}

resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc.arn
}

resource "helm_release" "lbc" {
  name       = "eks"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.11.0"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks.name
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }
}

resource "helm_release" "external_nginx" {
  name = "external"

  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress"
  create_namespace = true
  version          = "4.10.1"

  values = [file("${path.module}/values/nginx-ingress.yaml")]

  depends_on = [helm_release.lbc]
}
