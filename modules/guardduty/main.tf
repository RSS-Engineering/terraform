resource "aws_guardduty_detector" "detector" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = false
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = false
        }
      }
    }
    # rds and lambda protections are not yet manageable by terraform
    # but they are enabled by default when the detector is first created
  }
}

data "aws_region" "current" {}

resource "aws_guardduty_invite_accepter" "invitee" {
  count             = var.instance == null ? 0 : 1
  depends_on        = [aws_guardduty_detector.detector]
  detector_id       = aws_guardduty_detector.detector.id
  master_account_id = var.admin_account[var.instance]
}
