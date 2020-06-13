provider "aws" {
	region="ap-south-1"
}

//Key-pair creation.
resource "aws_key_pair" "ec2_terraform_key" {
  key_name   = "ec2_terraform_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFQE7vUCtIICsc1tZ20r2BNtlTMcJbM1e9jqAuaI2oIWwZgks2rJFoWKSDJpYwIYZwxoZo2xOK0xlmEuz7wrP6pWOayc3lUPne/SHcyK2vUKXFTWgOPf0S10eitVskj0ObT1pE4S7k73LcqKaj+KTIV5PtKWvuCTWvnokaCLUEPhbTAK8JIqc7/OiWUj7lSPKddnEVxNg4ez6udbd2gCBz6S74R5u7RiYnI1yFbfldDJAMqXrcIiIJJUFS6DViBSuzhLt42zCx5wttMZ5Q/JDxtenvIuwDoH6x0UBj6t9SYA6kNx1HLomzaMvfIq6wbLstNNJPJWarRX7IwmMNLgJF suhail@LAPTOP-PB5ODHL4"
}

//Security Group
resource "aws_security_group" "allow_http" {
  name        = "allow_http_ssh"
  description = "Allow Http inbound traffic"
  //vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http_and_ssh"
  }
}


//creating ec2 instance
resource "aws_instance" "my_ec2_terraform" {
	ami="ami-0447a12f28fddb066"
	instance_type="t2.micro"
	key_name="ec2_terraform_key"
	security_groups=["allow_http_ssh"]
	tags={
		name="myos2"
	}
	connection{
		type="ssh"
		user="ec2-user"
		private_key=file("C:/Users/Suhail/Desktop/terraform/task1/my1234")
		host=aws_instance.my_ec2_terraform.public_ip
	}
	provisioner "remote-exec"{
		inline=["sudo yum install httpd php git -y",
			"sudo systemctl restart httpd",
			"sudo systemctl enable httpd"]
	}
  depends_on=[
	aws_security_group.allow_http,aws_key_pair.ec2_terraform_key,
  ]
}



//output of instance's IP
output "my_IP"{
	value=aws_instance.my_ec2_terraform.public_ip
}



//ebs creation
resource "aws_ebs_volume" "ebs1" {
	availability_zone = aws_instance.my_ec2_terraform.availability_zone
	size              = 1

  tags = {
    Name = "ebs1"
  }
} 

//attach ebc to instance 
resource "aws_volume_attachment" "ebs1_att" {
	device_name = "/dev/sdh"
	volume_id   = "${aws_ebs_volume.ebs1.id}"
	instance_id = "${aws_instance.my_ec2_terraform.id}"
	force_detach= true
  depends_on=[
	aws_ebs_volume.ebs1,
  ]
}

//ebs format and mount
resource "null_resource" "null1"{
connection{
		type= "ssh"
		user= "ec2-user"
		private_key= file("C:/Users/Suhail/Desktop/terraform/task1/my1234")
		host= aws_instance.my_ec2_terraform.public_ip
	}
provisioner "remote-exec"{
		inline=["sudo mkfs.ext4 /dev/xvdh",
			"sudo mount /dev/xvdh /var/www/html/",
			"sudo rm -rf /var/www/html/",
			"sudo git clone https://github.com/suhail48/aws_terraform_task1.git /var/www/html/"]
	}
	depends_on=[
	aws_volume_attachment.ebs1_att,
  ]
}



//bucket creation
resource "aws_s3_bucket" "suhail48terra" {
  bucket = "suhail48terra"
  acl    = "public-read"
  force_destroy = true
  region = "ap-south-1"

  tags = {
    Name        = "bucket1"
  }
  versioning {
  enabled=true
  }
}


resource "null_resource" "null3"{
  provisioner "local-exec"{
		command= "echo Y | rmdir /s C:\\Users\\Suhail\\Documents\\git_images"
  }
  provisioner "local-exec"{
    command= "mkdir C:\\Users\\Suhail\\Documents\\git_images"
	}
  provisioner "local-exec"{
    command= "git clone https://github.com/suhail48/aws_terraform_task1.git C:\\Users\\Suhail\\Documents\\git_images"
	}
}


//bucket object upload
resource "aws_s3_bucket_object" "bucket_obj" {
  key    = "unityy1.jpg"
  bucket = "${aws_s3_bucket.suhail48terra.id}"
  source = "C:/Users/Suhail/Downloads/unityy1.jpg"
  etag = "C:/Users/Suhail/Downloads/unityy1.jpg"

  force_destroy = true
  acl = "public-read"
  depends_on=[
	aws_s3_bucket.suhail48terra,null_resource.null3,
  ]
}

//bucket object permissions
resource "aws_s3_bucket_public_access_block" "s3_public" {
  bucket = "${aws_s3_bucket.suhail48terra.id}"
  block_public_acls   = false
  block_public_policy = false
  depends_on=[
	aws_s3_bucket_object.bucket_obj,
  ]
}


/*variable "path" {
  default = "echo Y | rmdir /s C:/Users/Suhail/Documents/git_images"
}*/

//CloudFront

//output of instance's DNS
output "my_DNS"{
	value=aws_instance.my_ec2_terraform.public_dns
}
output "my_bucket_regional_domain_name"{
	value=aws_s3_bucket.suhail48terra.bucket_regional_domain_name
}









resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on=[
	aws_s3_bucket_object.bucket_obj,
  ]
  origin {
    domain_name = "${aws_s3_bucket.suhail48terra.bucket_regional_domain_name}"
    origin_id   = "suhail48_s3_distri"
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "unityy1.jpg"
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "suhail48_s3_distri"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  connection {
        type= "ssh"
		    user= "ec2-user"
		    private_key= file("C:/Users/Suhail/Desktop/terraform/task1/my1234")
		    host= aws_instance.my_ec2_terraform.public_ip
    }
  provisioner "remote-exec" {
        inline  = [
            // "sudo su << \"EOF\" \n echo \"<img src='${self.domain_name}'>\" >> /var/www/html/index.html \n \"EOF\""
           "sudo su << EOF",
            //"echo \"<center><img src='http://${self.domain_name}/${aws_s3_bucket_object.bucket_obj.key}' height='400px' width='400px'></center>\" /var/www/html/index.php",
            "echo \"<center><img src='http://${self.domain_name}/${aws_s3_bucket_object.bucket_obj.key}' height='400px' width='400px'></center>\" >> /var/www/html/index.php",
           // "echo \"<center>\"This webserver is running on Amazon EC2, all data is stored on EBS storage. This image comes from Amazon S3 bucket, using AWS CLoudFront distribution for s3 bucket.\"</center>",
           "EOF"
        ]
    }
}





//chrome
resource "null_resource" "null2"{
	provisioner "local-exec" {
	  command= "start chrome ${aws_instance.my_ec2_terraform.public_ip}"
  }
	depends_on= [
	aws_cloudfront_distribution.s3_distribution,
  ]
}


