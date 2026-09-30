output "crypto_key_id" {
  description = "The key these grants were applied to."
  value       = var.crypto_key_id
}

output "granted_members" {
  description = <<-EOT
    Every principal this module granted access to, and the role each one
    received. Suitable for handing to your security reviewers, or back to
    Jump to confirm onboarding is complete — it is the full extent of the
    access Jump holds to this key.
  EOT
  value       = module.cmek_grants.granted_members
}
