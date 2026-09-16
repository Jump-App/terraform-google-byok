variable "crypto_key_id" {
  description = "Full resource ID of the Cloud KMS key to grant access on."
  type        = string

  validation {
    condition     = can(regex("^projects/[^/]+/locations/[^/]+/keyRings/[^/]+/cryptoKeys/[^/]+$", var.crypto_key_id))
    error_message = "crypto_key_id must be a full key resource ID of the form projects/<project>/locations/<location>/keyRings/<ring>/cryptoKeys/<key>."
  }
}

variable "encrypter_decrypter_members" {
  description = <<-EOT
    Service accounts receiving roles/cloudkms.cryptoKeyEncrypterDecrypter,
    keyed by the system each belongs to. The key of each entry is the
    Terraform resource address, so it must stay stable across applies; the
    value may change.
  EOT
  type        = map(string)
}
