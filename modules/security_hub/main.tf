# Rackspace has moved towards centralized/org managed security hub accounts instead
# This module now exists as a way to transition off of the old model for accounts that
# migrate

removed {
  from = aws_securityhub_account.security_hub

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_securityhub_standards_subscription.cis

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_securityhub_standards_subscription.pci

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_securityhub_product_subscription.guardduty

  lifecycle {
    destroy = false
  }
}

# instances with resource keys cannot be "removed"
# but you can move (to remove the resource key) and then remove them
moved {
  from = aws_securityhub_invite_accepter.invitee[0]
  to = aws_securityhub_invite_accepter.removed
}

removed {
  from = aws_securityhub_invite_accepter.removed

  lifecycle {
    destroy = false
  }
}
